#!/usr/bin/env Rscript
# Misura del cancello d'istanza: chi ha accesso contro chi sta nel gruppo
#
# Sulla flotta modernizzata `appRoleAssignmentRequired` e' falso, quindi
# chiunque nel tenant puo' autenticarsi su qualunque istanza migrata: il
# gruppo `edcNN-redcap_group` esiste ma non governa niente. Ripristinarlo e'
# del sotto-progetto 6, e la decisione 13 del disegno dell'identita' fissa
# l'ordine: **prima si popolano i gruppi con chi oggi ha accesso**, poi si
# assegna, poi si accende. L'ordine inverso chiude fuori l'utenza di
# un'istanza intera, in silenzio, finche' qualcuno non prova a entrare.
#
# Questa misura dice quanto costerebbe il primo passo di quell'ordine, e
# nient'altro. Non accende niente.
#
# Uso:
#   Rscript dev/misura-cancello-istanza.R          # i numeri
#   Rscript dev/misura-cancello-istanza.R --nomi   # anche chi resterebbe fuori
#
# Sola lettura per costruzione: `state` sul modulo (che senza coppie legge
# l'istanza intera, ed e' il modo audit che `StateReader` dichiara) e GET su
# Graph. Nessuna PATCH, nessuna scrittura sul registro, nessuna telemetria.
#
# --- Perche' i nomi sono spenti di default --------------------------------
#
# La domanda che questa misura chiude e' «dieci minuti o campo minato», e a
# quella rispondono i conteggi. I nomi servono a **popolare** i gruppi, che e'
# l'atto successivo e di un altro sotto-progetto. Stamparli qui vorrebbe dire
# spargere un elenco di persone in un terminale per una decisione che non ne
# ha bisogno.
#
# --- Perche' i gruppi si filtrano in memoria ------------------------------
#
# Due gruppi hanno uno **spazio iniziale** nel nome — `" edc07-redcap_group"`
# e `" edc09-redcap_group"` — misurato il 2026-08-15. Un `startswith` lato
# servizio non li trova, e la risposta sarebbe «quell'istanza non ha un
# gruppo»: un elenco vuoto dato senza errore, che e' la famiglia di guasti che
# questo progetto ha gia' pagato due volte. Si legge tutto e si confronta
# normalizzando, come fa la risoluzione dell'identita' con i recapiti che
# portano spazi ai bordi.
#
# --- Perche' i membri transitivi e non i diretti --------------------------
#
# La domanda e' «chi puo' entrare», e un gruppo annidato porta i propri membri
# dentro l'assegnazione. I diretti si contano lo stesso: se i due numeri
# divergono c'e' annidamento, e chi popolera' i gruppi deve saperlo prima.
#
# --- Dove gira ------------------------------------------------------------
#
# Sulla macchina di provisioning: le liste di indirizzi delle istanze
# ammettono il solo indirizzo statico della VM, e il token di Graph viene
# dall'identita' gestita.
#
# Nessun nome che identifichi una risorsa sta in questo file: il repository e'
# pubblico.

suppressMessages(library(ubep.azure))

argomenti <- commandArgs(trailingOnly = TRUE)
mostra_nomi <- "--nomi" %in% argomenti

# L'elenco di chi ha accesso a un'istanza e' cio' con cui si popola il suo
# gruppo, che e' il primo passo dell'ordine della decisione 13. Esce in JSON
# sullo standard output, da solo, perche' il suo consumatore e' un altro
# programma e non una persona: mescolarlo alla tabella qui sotto vorrebbe
# dire farlo ritagliare a mano da chi lo usa.
solo_elenco <- "--elenco-json" %in% argomenti

arresta <- function(...) {
  cat("\nARRESTO:", ..., "\n")
  quit(status = 1L, save = "no")
}

`%||%` <- function(x, y) if (is.null(x)) y else x


# --- Precondizioni ---------------------------------------------------------

keyvault <- Sys.getenv("UBEP_KEYVAULT")
graph <- Sys.getenv("UBEP_GRAPH")

if (!nzchar(keyvault)) {
  arresta("UBEP_KEYVAULT non e' impostata.")
}
if (!nzchar(graph)) {
  arresta(
    "UBEP_GRAPH non e' impostata: senza l'endpoint la meta' Entra della",
    "misura non si prende, e resterebbe la meta' REDCap — che da sola",
    "risponde a un'altra domanda."
  )
}

token_per <- function(risorsa) {
  esito <- try(
    httr2::request(
      "http://169.254.169.254/metadata/identity/oauth2/token"
    ) |>
      httr2::req_url_query(`api-version` = "2018-02-01", resource = risorsa) |>
      httr2::req_headers(Metadata = "true") |>
      httr2::req_timeout(5) |>
      httr2::req_perform() |>
      httr2::resp_body_json(),
    silent = TRUE
  )
  if (inherits(esito, "try-error")) NULL else esito[["access_token"]]
}

token_vault <- token_per("https://vault.azure.net")
if (is.null(token_vault)) {
  arresta(
    "l'identita' gestita non risponde: questo script gira sulla macchina di",
    "provisioning, non dalla postazione."
  )
}

# L'audience del token non si ricava da `UBEP_GRAPH`, che porta anche il path
# della versione: un token chiesto per `.../v1.0` non e' valido per Graph, e
# il rifiuto arriva come `401 InvalidAuthenticationToken` — cioe' con la forma
# di un permesso mancante, che e' la diagnosi sbagliata. Il runner tiene le
# due cose separate per questa ragione, e qui si fa lo stesso.
token_graph <- token_per("https://graph.microsoft.com")
if (is.null(token_graph)) {
  arresta(
    "l'identita' gestita non emette un token per Graph. Non e' un permesso",
    "che manca: e' il token che non nasce, e ogni chiamata direbbe 401."
  )
}

inventario <- jsonlite::fromJSON(
  Sys.getenv("UBEP_INVENTARIO", "/etc/ubep-provisioning/istanze.json"),
  simplifyVector = FALSE
)

segreto <- function(nome) {
  httr2::request(
    paste0("https://", keyvault, ".vault.azure.net/secrets/", nome)
  ) |>
    httr2::req_url_query(`api-version` = "7.4") |>
    httr2::req_headers(Authorization = paste("Bearer", token_vault)) |>
    httr2::req_perform() |>
    httr2::resp_body_json() |>
    (\(x) x[["value"]])()
}


# --- Meta' Entra -----------------------------------------------------------

# Una pagina alla volta, e il rifiuto si riporta invece di morire: se questa
# identita' non porta un permesso sui gruppi lo deve dire questa riga, non un
# errore di parsing tre funzioni piu' in la'.
graph_get <- function(percorso) {
  url <- paste0(sub("/+$", "", graph), percorso)
  raccolto <- list()
  repeat {
    risposta <- try(
      httr2::request(url) |>
        httr2::req_headers(
          Authorization = paste("Bearer", token_graph),
          ConsistencyLevel = "eventual"
        ) |>
        httr2::req_error(is_error = function(r) FALSE) |>
        httr2::req_perform(),
      silent = TRUE
    )
    if (inherits(risposta, "try-error")) {
      return(list(ok = FALSE, motivo = "non raggiunto", valore = list()))
    }
    stato <- httr2::resp_status(risposta)
    corpo <- try(httr2::resp_body_json(risposta), silent = TRUE)
    if (stato != 200L || inherits(corpo, "try-error")) {
      codice <- if (inherits(corpo, "try-error")) {
        ""
      } else {
        corpo[["error"]][["code"]] %||% ""
      }
      return(list(
        ok = FALSE,
        motivo = paste0("HTTP ", stato, " ", codice),
        valore = list()
      ))
    }
    raccolto <- c(raccolto, corpo[["value"]] %||% list())
    prossima <- corpo[["@odata.nextLink"]]
    if (is.null(prossima)) break
    url <- prossima
  }
  list(ok = TRUE, motivo = "", valore = raccolto)
}

campo <- function(x, nome) {
  v <- x[[nome]]
  if (is.null(v) || length(v) != 1L) NA_character_ else as.character(v)
}

normalizza <- function(x) tolower(trimws(x))

membri_di <- function(voce) {
  sel <- "$select=id,userPrincipalName,userType&$top=999"
  base <- paste0("/groups/", voce[["id"]])
  tutti <- graph_get(paste0(base, "/transitiveMembers?", sel))
  diretti <- graph_get(paste0(base, "/members?", sel))
  if (!tutti[["ok"]]) {
    return(list(ok = FALSE, motivo = tutti[["motivo"]]))
  }
  upn <- normalizza(vapply(
    tutti[["valore"]], function(x) campo(x, "userPrincipalName"), character(1)
  ))
  tipo <- vapply(
    tutti[["valore"]], function(x) campo(x, "userType"), character(1)
  )
  list(
    ok = TRUE,
    upn = upn[!is.na(upn)],
    ospiti = sum(!is.na(tipo) & tipo == "Guest"),
    diretti = if (diretti[["ok"]]) length(diretti[["valore"]]) else NA_integer_
  )
}


# --- Meta' REDCap ----------------------------------------------------------

# Solo dove il modulo c'e'. Un'istanza senza modulo NON e' un'istanza senza
# utenti, e la differenza va stampata: un conteggio zero letto come «nessuno
# ha accesso» direbbe che accendere il cancello e' gratis proprio dove non si
# sa se lo sia.
accessi <- list()
for (istanza in inventario[["con_modulo"]]) {
  risposta <- ubep.azure:::module_call(
    istanza[["host"]], segreto(istanza[["segreto"]]), "state"
  )
  righe <- risposta[["payload"]][["results"]]
  if (!isTRUE(risposta[["ok"]]) || is.null(righe)) {
    accessi[[istanza[["nome"]]]] <- list(ok = FALSE, motivo = paste(
      risposta[["errors"]],
      collapse = ","
    ))
    next
  }
  utenti <- unique(normalizza(vapply(
    righe, function(x) as.character(x[["username"]]), character(1)
  )))
  accessi[[istanza[["nome"]]]] <- list(
    ok = TRUE, utenti = utenti[nzchar(utenti)], righe = length(righe)
  )
}

# Prima di Graph, cosi' con `--elenco-json` l'identita' gestita non viene
# nemmeno mandata a sbattere contro un permesso che non ha: il suo 403
# finirebbe sullo standard output in mezzo al JSON, e il consumatore non
# saprebbe leggerlo.
if (solo_elenco) {
  cat(jsonlite::toJSON(
    lapply(names(accessi), function(nome) {
      voce <- accessi[[nome]]
      list(
        istanza = nome,
        ok = isTRUE(voce[["ok"]]),
        utenti = if (isTRUE(voce[["ok"]])) as.list(voce[["utenti"]]) else list()
      )
    }),
    auto_unbox = TRUE
  ), "\n")
  quit(status = 0L, save = "no")
}


# --- Gruppi d'istanza ------------------------------------------------------

cat("--- gruppi Entra ---\n")
gruppi <- graph_get("/groups?$select=id,displayName&$top=999")
if (!gruppi[["ok"]]) {
  cat(
    "NON LETTI:", gruppi[["motivo"]],
    "\n  403 o Authorization_RequestDenied = il permesso manca, e la meta'",
    "Entra si prende\n  con credenziali delegate. Qualunque altro codice e'",
    "un guasto di questo script,\n  non una risposta del tenant.\n"
  )
}

interessanti <- list()
if (gruppi[["ok"]]) {
  for (g in gruppi[["valore"]]) {
    nome <- campo(g, "displayName")
    if (is.na(nome) || !grepl("redcap_group", nome, fixed = TRUE)) next
    interessanti[[normalizza(nome)]] <- list(
      id = campo(g, "id"), nome = nome, sporco = nome != trimws(nome)
    )
  }
  cat("gruppi *redcap_group* trovati:", length(interessanti), "\n")
  sporchi <- Filter(function(x) isTRUE(x[["sporco"]]), interessanti)
  if (length(sporchi) > 0L) {
    cat(
      "con spazi ai bordi nel nome:", length(sporchi),
      "->", paste(sprintf("[%s]", vapply(sporchi, function(x) x[["nome"]], "")),
        collapse = " "
      ), "\n"
    )
  }
}


# --- Confronto -------------------------------------------------------------

cat("\n--- per istanza ---\n")
cat(sprintf(
  "%-8s %-8s %-8s %-8s %-8s %-8s %-8s %s\n",
  "istanza", "modulo", "coppie", "accesso", "gruppo", "fuori", "in-piu", "note"
))

for (nome in inventario[["flotta"]]) {
  voce <- interessanti[[normalizza(paste0(nome, "-redcap_group"))]]
  gruppo <- if (is.null(voce)) NULL else membri_di(voce)

  ha_modulo <- !is.null(accessi[[nome]])
  lato_redcap <- if (ha_modulo && isTRUE(accessi[[nome]][["ok"]])) {
    accessi[[nome]][["utenti"]]
  } else {
    NULL
  }

  # «nessun gruppo» si puo' dire solo se l'elenco e' stato letto. Con l'elenco
  # non letto ogni istanza sembrerebbe senza gruppo, cioe' la misura
  # stamperebbe tredici volte la risposta piu' comoda — e la sua stessa
  # legenda dichiara che «?» non e' zero.
  note <- character()
  if (!gruppi[["ok"]]) {
    note <- c(note, "gruppi NON letti")
  } else if (is.null(voce)) {
    note <- c(note, "nessun gruppo")
  }
  if (!is.null(voce) && isTRUE(voce[["sporco"]])) {
    note <- c(note, "spazio nel nome")
  }
  if (!ha_modulo) note <- c(note, "senza modulo: accesso NON misurato")
  if (!is.null(gruppo) && !isTRUE(gruppo[["ok"]])) {
    note <- c(note, paste0("gruppo non letto: ", gruppo[["motivo"]]))
  }
  if (!is.null(gruppo) && isTRUE(gruppo[["ok"]]) &&
        !is.na(gruppo[["diretti"]]) &&
        gruppo[["diretti"]] != length(gruppo[["upn"]])) {
    note <- c(note, sprintf(
      "annidato: %d diretti, %d transitivi", gruppo[["diretti"]],
      length(gruppo[["upn"]])
    ))
  }
  if (!is.null(gruppo) && isTRUE(gruppo[["ok"]]) && gruppo[["ospiti"]] > 0L) {
    note <- c(note, sprintf("%d ospiti", gruppo[["ospiti"]]))
  }

  misurabile <- !is.null(lato_redcap) && !is.null(gruppo) &&
    isTRUE(gruppo[["ok"]])
  fuori <- if (misurabile) setdiff(lato_redcap, gruppo[["upn"]]) else NULL
  in_piu <- if (misurabile) setdiff(gruppo[["upn"]], lato_redcap) else NULL

  cat(sprintf(
    "%-8s %-8s %-8s %-8s %-8s %-8s %-8s %s\n",
    nome,
    if (ha_modulo) "si" else "no",
    if (!ha_modulo || !isTRUE(accessi[[nome]][["ok"]])) {
      "?"
    } else {
      accessi[[nome]][["righe"]]
    },
    if (is.null(lato_redcap)) "?" else length(lato_redcap),
    if (is.null(gruppo) || !isTRUE(gruppo[["ok"]])) {
      "?"
    } else {
      length(gruppo[["upn"]])
    },
    if (is.null(fuori)) "?" else length(fuori),
    if (is.null(in_piu)) "?" else length(in_piu),
    paste(note, collapse = "; ")
  ))

  if (mostra_nomi && !is.null(fuori) && length(fuori) > 0L) {
    cat("    resterebbero fuori:\n")
    for (u in fuori) cat("      ", u, "\n")
  }
}

cat(
  "\n«fuori» = ha accesso a REDCap e non e' nel gruppo: chi il cancello,",
  "acceso oggi,\n         chiuderebbe fuori. E' il numero che la decisione",
  "13 chiede.\n«in-piu» = sta nel gruppo e non ha diritti su nessun progetto",
  "dell'istanza.\n«?»      = non misurato. Non e' zero, e leggerlo come zero",
  "e' il guasto\n         che questa misura esiste per non produrre.\n"
)

cat("\nmisurato il:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
