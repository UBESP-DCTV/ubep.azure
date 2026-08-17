#!/usr/bin/env Rscript
# Misura dei diritti sul progetto delle richieste
#
# Stampa, per il progetto che ospita il registro, chi ci ha diritti e quali:
# le righe utente, i ruoli definiti, e la mappatura fra le due. Serve a
# rispondere a una domanda sola, che il modulo non sa rispondere:
#
#   che cosa puo' fare oggi, su questo progetto, un referente?
#
# Uso:
#   Rscript dev/misura-diritti-registro.R           # la misura intera
#   Rscript dev/misura-diritti-registro.R --grezzo  # anche il JSON com'e'
#
# Sola lettura per costruzione: chiama solo i tre `content` di esportazione e
# non nomina mai `action = "import"`. Non tocca il registro, non emette
# telemetria, non scrive su nessuna istanza.
#
# --- Perche' non passa dal modulo -----------------------------------------
#
# `StateReader` riporta una colonna di permessi sola, `user_rights`, e lo fa
# apposta: la sua docstring dice che riporta il valore grezzo di REDCap e mai
# un verdetto. `record_delete` e `design` non passano di li'. E il registro
# vive su un'istanza che il modulo non ha: il canale la legge con un token,
# che e' il meccanismo su cui questa misura si appoggia.
#
# --- Perche' l'intero profilo e non le due caselle che interessano ---------
#
# La domanda nasce da due diritti — cancellare un record e disegnare il modulo
# — ma chiederli da soli darebbe una risposta che non si sa leggere. Un
# permesso si giudica accanto agli altri: `api_import` rende il form
# aggirabile, `data_import_tool` rende il lotto possibile senza costruire
# niente, e `user_rights` sul progetto delle richieste **e' il cancello umano**
# che concede il primo diritto a un referente nuovo. Chi ce l'ha puo' aprire
# la porta a chiunque, e quel cancello non ha altro custode.
#
# --- Perche' i ruoli, e non solo le righe utente --------------------------
#
# `StateReader::effectiveUserRights()` legge il ruolo per primo e la riga
# propria solo in sua assenza. Quindi due referenti possono portare lo stesso
# nome e permessi diversi a seconda di come sono stati aggiunti, e una misura
# che leggesse solo una delle due tabelle direbbe il falso per meta' delle
# persone — senza dichiararlo, che e' la famiglia di guasti di questo
# progetto.
#
# --- Dove gira ------------------------------------------------------------
#
# Sulla macchina di provisioning. Il segreto del registro sta nel Key Vault e
# lo si legge con l'identita' gestita, che esiste solo dentro la VM.
#
# Nessun nome che identifichi una risorsa sta in questo file: il repository e'
# pubblico. Arrivano dall'ambiente dell'unita' e dall'inventario sulla
# macchina, che sono fuori da git.

suppressMessages(library(ubep.azure))

grezzo <- "--grezzo" %in% commandArgs(trailingOnly = TRUE)

arresta <- function(...) {
  cat("\nARRESTO:", ..., "\n")
  quit(status = 1L, save = "no")
}


# --- Precondizioni ---------------------------------------------------------

keyvault <- Sys.getenv("UBEP_KEYVAULT")
if (!nzchar(keyvault)) {
  arresta(
    "UBEP_KEYVAULT non e' impostata: senza il nome del Key Vault non si legge",
    "il token del registro, e la misura direbbe che il registro non risponde",
    "— cioe' manderebbe a cercare il problema su edc05 invece che qui.",
    "\n  Sulla macchina:",
    "env $(cat /etc/ubep-provisioning/ambiente | xargs) Rscript ..."
  )
}

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

token_vault <- identita_gestita()
if (is.null(token_vault)) {
  arresta(
    "l'identita' gestita non risponde: questo script gira sulla macchina di",
    "provisioning, non dalla postazione."
  )
}

inventario <- jsonlite::fromJSON(
  Sys.getenv("UBEP_INVENTARIO", "/etc/ubep-provisioning/istanze.json"),
  simplifyVector = FALSE
)

registro <- inventario[["registro"]]
if (is.null(registro[["host"]]) || is.null(registro[["segreto"]])) {
  arresta(
    "l'inventario non descrive il registro: servono `registro.host` e",
    "`registro.segreto`."
  )
}

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

url <- as.character(registro[["host"]])
token <- segreto(registro[["segreto"]])


# --- Lettura ---------------------------------------------------------------

`%||%` <- function(x, y) if (is.null(x)) y else x

# Un rifiuto qui non e' un guasto della misura: e' una risposta. Se il token
# non porta il diritto d'esportare i diritti, lo dice, e la misura si prende
# dall'interfaccia. Cio' che non deve succedere e' che un elenco vuoto passi
# per «nessuno ha diritti», che e' la risposta sbagliata data senza errore.
chiedi <- function(contenuto) {
  esito <- ubep.azure:::register_call(url, token, list(content = contenuto))
  if (!isTRUE(esito[["ok"]])) {
    cat(sprintf(
      "\n[%s] NON LETTO: %s\n  %s\n",
      contenuto,
      paste(esito[["errors"]], collapse = ", "),
      esito[["payload"]][["message"]] %||% ""
    ))
    return(NULL)
  }
  if (length(esito[["payload"]]) == 0L) {
    cat(sprintf(
      "\n[%s] LETTO, MA VUOTO — da sospettare prima di crederci.\n", contenuto
    ))
    return(list())
  }
  esito[["payload"]]
}

utenti <- chiedi("user")
ruoli <- chiedi("userRole")
mappatura <- chiedi("userRoleMapping")


# --- Stampa ----------------------------------------------------------------

valore <- function(riga, nome) {
  v <- riga[[nome]]
  if (is.null(v) || length(v) != 1L) "-" else as.character(v)
}

# I permessi su cui questa misura e' stata chiesta, in ordine di conseguenza.
# L'elenco e' esplicito e non calcolato: un permesso che REDCap aggiungesse
# comparirebbe fra i «campi presenti» qui sotto, dove lo si vede, invece di
# entrare in silenzio in una colonna che nessuno ha deciso di guardare.
sorvegliati <- c(
  "user_rights", "design", "record_delete", "record_create", "record_rename",
  "api_export", "api_import", "data_import_tool", "data_quality_execute",
  "lock_record", "data_export", "reports", "logging"
)

stampa_profilo <- function(righe, chiave, titolo) {
  if (is.null(righe) || length(righe) == 0L) {
    return(invisible(NULL))
  }
  cat("\n---", titolo, "---\n")
  presenti <- unique(unlist(lapply(righe, names)))
  for (riga in righe) {
    cat("\n", valore(riga, chiave), "\n", sep = "")
    for (permesso in sorvegliati) {
      if (permesso %in% presenti) {
        cat(sprintf("  %-22s %s\n", permesso, valore(riga, permesso)))
      }
    }
    altri <- setdiff(names(riga), c(sorvegliati, chiave))
    non_nulli <- Filter(
      function(n) !valore(riga, n) %in% c("-", "", "0"), altri
    )
    if (length(non_nulli) > 0L) {
      cat("  altri non a zero: ", paste(non_nulli, collapse = ", "), "\n",
        sep = ""
      )
    }
  }
  cat("\ncampi presenti (", length(presenti), "): ",
    paste(sort(presenti), collapse = ", "), "\n",
    sep = ""
  )
}

stampa_profilo(utenti, "username", "righe utente")
stampa_profilo(ruoli, "role_label", "ruoli definiti")

if (!is.null(mappatura) && length(mappatura) > 0L) {
  cat("\n--- mappatura utente -> ruolo ---\n")
  for (riga in mappatura) {
    cat(sprintf(
      "  %-30s %s\n", valore(riga, "username"), valore(riga, "unique_role_name")
    ))
  }
}

if (grezzo) {
  cat("\n--- JSON com'e' ---\n")
  cat(jsonlite::toJSON(
    list(user = utenti, userRole = ruoli, userRoleMapping = mappatura),
    auto_unbox = TRUE, pretty = TRUE
  ), "\n")
}

cat(
  "\nmisurato il:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n"
)
