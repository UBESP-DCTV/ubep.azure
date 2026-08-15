#!/usr/bin/env Rscript
# Misura delle istanze che hanno il modulo
#
# Stampa le righe che il foglio dei parametri tiene sotto «La flotta
# osservata» — versione di REDCap, cancello di major, impronta di superficie,
# impronta delle liste di indirizzi, coppie, coppie con una scadenza, versione
# del modulo e del contratto — più il riassunto che dice se le tre istanze
# concordano.
#
# Uso:
#   Rscript dev/misura-canale.R            # la misura intera
#   Rscript dev/misura-canale.R --breve    # una riga per istanza
#
# Sola lettura: chiama `state` e nient'altro. Non scrive su nessuna istanza,
# non emette telemetria, non tocca il registro.
#
# --- Perché è uno script solo, con due modi -------------------------------
#
# Fino al 2026-08-15 erano due file fuori da git: `~/verifica-canale.R` sulla
# macchina e `misura-canale.R` in `/tmp`. Il secondo era un soprainsieme del
# primo, e il foglio dei parametri ha dovuto scrivere che «`verifica-canale.R`
# da solo non basta, e va detto perché il nome invita a crederlo»: stampava
# quattro delle nove righe misurate, e non quella — l'impronta di superficie —
# che un'attivazione del modulo chiede di sorvegliare.
#
# Due nomi di cui uno è un soprainsieme dell'altro sono la trappola stessa:
# chi ha fretta lancia quello corto. Un file, due modi, e il modo corto lo si
# chiede invece di sceglierlo per sbaglio.
#
# Il modo breve non è però solo un sottoinsieme, e per questo sopravvive: non
# passa da `observe_instance()`, quindi risponde anche quando un'istanza
# restituisce un payload che l'osservatore non sa leggere. È il modo da usare
# quando qualcosa è rotto; l'altro è quello da usare quando si riallinea il
# foglio.
#
# --- Perché non riestrae i campi da sé ------------------------------------
#
# Il modo intero chiama `ubep.azure:::observe_instance()`, cioè lo stesso
# codice dell'osservatore. Una misura che riestraesse i campi per conto proprio
# potrebbe divergere da ciò che la lavorazione riporta, ed è quella divergenza
# che il foglio dei parametri non saprebbe spiegare: due numeri veri presi in
# due modi diversi, e nessuno che sappia quale scrivere.
#
# --- Dove gira ------------------------------------------------------------
#
# Sulla macchina di provisioning, non dalla postazione: le liste di indirizzi
# delle istanze ammettono un indirizzo solo, ed è quello statico della VM. Da
# altrove ogni istanza risulterebbe non raggiunta, e il guasto somiglierebbe a
# una flotta rotta invece che a uno script lanciato dal posto sbagliato. Il
# controllo qui sotto lo dice prima che succeda.
#
# Nessun nome che identifichi una risorsa sta in questo file: il repository è
# pubblico. Arrivano dall'ambiente dell'unità e dall'inventario sulla macchina,
# che sono fuori da git. L'unico valore di riserva è un percorso sul disco.

suppressMessages(library(ubep.azure))

solo_breve <- "--breve" %in% commandArgs(trailingOnly = TRUE)

arresta <- function(...) {
  cat("\nARRESTO:", ..., "\n")
  quit(status = 1L, save = "no")
}


# --- Precondizioni ---------------------------------------------------------

keyvault <- Sys.getenv("UBEP_KEYVAULT")
if (!nzchar(keyvault)) {
  arresta(
    "UBEP_KEYVAULT non è impostata: senza il nome del Key Vault non si legge",
    "nessun segreto, e ogni istanza uscirebbe come non raggiunta — cioè la",
    "misura manderebbe a cercare il problema sulle istanze invece che qui.",
    "\n  Sulla macchina:",
    "env $(cat /etc/ubep-provisioning/ambiente | xargs) Rscript ..."
  )
}

# L'endpoint dell'identità gestita esiste solo dentro una VM di Azure. È il
# modo più economico di distinguere «sono sulla macchina» da «sono sulla
# postazione» senza chiedere il nome di niente.
identita_gestita <- function() {
  esito <- try(
    httr2::request(
      "http://169.254.169.254/metadata/identity/oauth2/token"
    ) |>
      httr2::req_url_query(
        `api-version` = "2018-02-01",
        resource = "https://vault.azure.net"
      ) |>
      httr2::req_headers(Metadata = "true") |>
      httr2::req_timeout(5) |>
      httr2::req_perform() |>
      httr2::resp_body_json(),
    silent = TRUE
  )
  if (inherits(esito, "try-error")) NULL else esito[["access_token"]]
}

token <- identita_gestita()
if (is.null(token)) {
  arresta(
    "l'identità gestita non risponde: questo script gira sulla macchina di",
    "provisioning, non dalla postazione.\n  Dalla postazione le liste di",
    "indirizzi delle istanze rifiutano l'endpoint del modulo, e ogni istanza",
    "risulterebbe non raggiunta senza che il motivo sia visibile."
  )
}

inventario <- jsonlite::fromJSON(
  Sys.getenv("UBEP_INVENTARIO", "/etc/ubep-provisioning/istanze.json"),
  simplifyVector = FALSE
)

servite <- inventario[["con_modulo"]]
if (length(servite) == 0L) {
  arresta(
    "l'inventario non elenca nessuna istanza con il modulo: la misura",
    "stamperebbe zero righe, che si legge come «tutto a posto» e non lo è."
  )
}


# --- Lettura ---------------------------------------------------------------

segreto <- function(nome) {
  httr2::request(
    paste0("https://", keyvault, ".vault.azure.net/secrets/", nome)
  ) |>
    httr2::req_url_query(`api-version` = "7.4") |>
    httr2::req_headers(Authorization = paste("Bearer", token)) |>
    httr2::req_perform() |>
    httr2::resp_body_json() |>
    (\(x) x[["value"]])()
}

risposte <- lapply(servite, function(istanza) {
  list(
    nome = istanza[["nome"]],
    risposta = ubep.azure:::module_call(
      istanza[["host"]], segreto(istanza[["segreto"]]), "state"
    )
  )
})


# --- Modo breve ------------------------------------------------------------

campo <- function(payload, nome, assente = "-") {
  valore <- payload[[nome]]
  if (is.null(valore)) assente else as.character(valore)
}

if (solo_breve) {
  for (voce in risposte) {
    payload <- voce[["risposta"]][["payload"]]
    cat(sprintf(
      paste0(
        "%-6s ok=%-5s modulo=%-8s contratto=%-3s allowlist_fp=%-14s ",
        "letti=%-4s errori=%s\n"
      ),
      voce[["nome"]],
      voce[["risposta"]][["ok"]],
      campo(payload, "module_version"),
      campo(payload, "contract_version"),
      campo(payload, "allowlist_fingerprint", assente = "NULL"),
      if (is.null(payload[["results"]])) "-" else length(payload[["results"]]),
      paste(voce[["risposta"]][["errors"]], collapse = ",")
    ))
  }
  quit(status = 0L, save = "no")
}


# --- Modo intero -----------------------------------------------------------

# Un'istanza il cui payload l'osservatore non sa leggere non deve portarsi via
# la misura delle altre: il senso di questo script è dire se le tre concordano,
# e morire sulla prima nasconde le due che avrebbero risposto.
righe <- lapply(risposte, function(voce) {
  payload <- voce[["risposta"]][["payload"]]
  osservata <- try(
    ubep.azure:::observe_instance(voce[["nome"]], voce[["risposta"]]),
    silent = TRUE
  )
  if (inherits(osservata, "try-error")) {
    cat(
      "NOTA:", voce[["nome"]], "non si è lasciata osservare;",
      "riprovare con --breve per vedere che cosa ha risposto.\n"
    )
    return(NULL)
  }
  cbind(
    osservata,
    modulo = campo(payload, "module_version", assente = NA_character_),
    contratto = campo(payload, "contract_version", assente = NA_character_)
  )
})

righe <- Filter(Negate(is.null), righe)
if (length(righe) == 0L) {
  arresta("nessuna istanza si è lasciata osservare.")
}

misura <- do.call(rbind, righe)
print(misura, row.names = FALSE)

distinte <- function(colonna) {
  paste(unique(misura[[colonna]]), collapse = ", ")
}

cat("\n--- riassunto ---\n")
cat("impronte di superficie distinte:", distinte("surface_fingerprint"), "\n")
cat("impronte di allowlist distinte :", distinte("allowlist_fingerprint"), "\n")
cat("versioni del modulo distinte   :", distinte("modulo"), "\n")
cat("versioni del contratto distinte:", distinte("contratto"), "\n")
cat("cancelli distinti              :", distinte("version_gate"), "\n")
cat("coppie totali                  :", sum(misura[["coppie"]], na.rm = TRUE),
    "\n")
cat(
  "coppie con una scadenza        :",
  sum(misura[["coppie"]] - misura[["senza_scadenza"]], na.rm = TRUE), "\n"
)
cat(
  "misurato il                    :",
  format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n"
)

# Un'impronta unica su tutte le istanze servite significa che concordano. Se ne
# comparissero due, la differenza va spiegata prima di essere accettata — ed è
# il momento in cui si guarda il foglio dei parametri, non questo output.
if (nrow(misura) < length(servite)) {
  cat(
    "\nATTENZIONE: misurate", nrow(misura), "istanze su", length(servite),
    "— il riassunto qui sopra parla solo di quelle.\n"
  )
}
