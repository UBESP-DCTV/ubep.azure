#!/usr/bin/env Rscript

# Osservatore della flotta REDCap.
#
# Gira una volta al giorno sulla macchina dedicata, legge lo stato di ogni
# istanza che ha il modulo, e lascia un record della run. Non confronta niente:
# finche' il progetto-richieste non esiste, il desiderato e' vuoto e ogni coppia
# reale verrebbe classificata come non piu' voluta. Il pericolo non e' la
# chiamata che scrive, e' il confronto che la alimenterebbe -- quindi qui il
# confronto non si calcola affatto, e un controllo in
# `tests/testthat/test-runner-guardie.R` lo sorveglia.
#
# Che cosa si osserva senza alcun desiderato: versione, major, cancello,
# impronta di superficie, raggiungibilita', e le coppie la cui scadenza e' gia'
# passata -- che e' una delle tre derive, ed e' proprieta' del solo reale.
#
# I nomi delle istanze non stanno in questo file: il repository e' pubblico.
# Arrivano da un inventario sulla macchina, fuori da git.

suppressMessages(library(ubep.azure))

INVENTARIO <- Sys.getenv(
  "UBEP_INVENTARIO",
  "/etc/ubep-provisioning/istanze.json"
)
KEYVAULT <- Sys.getenv("UBEP_KEYVAULT", "kv-ubep-provisioning")

# --- identita' gestita ------------------------------------------------------

# Il token si chiede all'IMDS, che risponde solo a chi gira sulla macchina: e'
# cio' che permette di non tenere alcun segreto sul disco.
token_imds <- function(risorsa) {
  risposta <- httr2::request(
    "http://169.254.169.254/metadata/identity/oauth2/token"
  ) |>
    httr2::req_url_query(`api-version` = "2018-02-01", resource = risorsa) |>
    httr2::req_headers(Metadata = "true") |>
    httr2::req_perform()

  httr2::resp_body_json(risposta)[["access_token"]]
}

segreto_da_keyvault <- function(nome, token) {
  risposta <- httr2::request(
    paste0("https://", KEYVAULT, ".vault.azure.net/secrets/", nome)
  ) |>
    httr2::req_url_query(`api-version` = "7.4") |>
    httr2::req_headers(Authorization = paste("Bearer", token)) |>
    httr2::req_perform()

  httr2::resp_body_json(risposta)[["value"]]
}

# --- inventario -------------------------------------------------------------

# Due liste, non una. Le istanze senza modulo compaiono come assenza
# dichiarata invece che come errore ricorrente: un rapporto che nasce con
# tredici righe rosse insegna a non leggerlo. Quando il modulo atterra su
# un'istanza si sposta un nome da una lista all'altra.
if (!file.exists(INVENTARIO)) {
  stop("inventario non trovato: ", INVENTARIO, call. = FALSE)
}
inventario <- jsonlite::fromJSON(INVENTARIO, simplifyVector = FALSE)

con_modulo <- inventario[["con_modulo"]] %||% list()
senza_modulo <- inventario[["senza_modulo"]] %||% list()

if (length(con_modulo) == 0L) {
  stop("l'inventario non elenca nessuna istanza con il modulo", call. = FALSE)
}

# --- la passata larga -------------------------------------------------------

token <- token_imds("https://vault.azure.net")
oggi <- Sys.Date()

osservazioni <- do.call(rbind, lapply(con_modulo, function(istanza) {
  nome <- istanza[["nome"]]

  segreto <- tryCatch(
    segreto_da_keyvault(istanza[["segreto"]], token),
    error = function(e) NULL
  )

  # Un segreto che non si riesce a leggere e' una riga, non un'eccezione: se
  # Key Vault e' irraggiungibile, le altre istanze vanno lette lo stesso.
  if (is.null(segreto)) {
    return(ubep.azure:::observe_instance(
      nome,
      list(ok = FALSE, errors = "TRASPORTO_SEGRETO_NON_LEGGIBILE"),
      today = oggi
    ))
  }

  # `pairs` vuoto legge l'istanza per intero: la passata e' larga, ed e' la
  # sola che esista finche' non c'e' un registro da cui ricavarne una stretta.
  stato <- ubep.azure:::module_state(istanza[["host"]], segreto)
  ubep.azure:::observe_instance(nome, stato, today = oggi)
}))

# Le istanze senza modulo entrano nel record come ambito dichiarato, non come
# nota a margine: senza di loro un giro che ne legge tre su quattordici
# direbbe che la flotta ha una major sola, e quella frase autorizza a
# dismettere un ramo di compatibilita' che serve ancora.
record <- ubep.azure:::run_record(
  osservazioni,
  at = format(Sys.time(), "%Y-%m-%d %H:%M", tz = "UTC"),
  non_osservate = vapply(
    senza_modulo, function(x) as.character(x[["nome"]]), character(1)
  )
)

# Log Analytics vuole `TimeGenerated`: entra nel record prima della
# serializzazione invece di essere incollato nel JSON dopo, perche' incollare
# stringhe dentro JSON gia' formato e' il modo di rompersi su un valore che
# contiene una parentesi.
record[["TimeGenerated"]] <- format(
  Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
)

json <- ubep.azure:::run_record_json(record)
cat(json, "\n")

# --- emissione ---------------------------------------------------------------

# Il record si emette alla FINE della run e non all'inizio. Se dicesse solo
# "il processo e' partito", un giro che parte, fallisce su ogni istanza e
# termina soddisferebbe l'allarme sull'assenza: un rilevatore che il guasto
# puo' accontentare. Per questo l'allarme guarda `letture_riuscite` e non
# l'esistenza del record.
#
# La via e' la Logs Ingestion API con l'identita' gestita, non la vecchia Data
# Collector: quella vuole una shared key, cioe' un altro segreto da custodire
# per fare una cosa che l'identita' gia' fa senza.
DCE <- Sys.getenv("UBEP_DCE")
DCR <- Sys.getenv("UBEP_DCR")

if (nzchar(DCE) && nzchar(DCR)) {
  emesso <- tryCatch({
    token <- token_imds("https://monitor.azure.com")
    corpo <- paste0("[", json, "]")

    httr2::request(
      paste0(DCE, "/dataCollectionRules/", DCR, "/streams/Custom-UbepRun_CL")
    ) |>
      httr2::req_url_query(`api-version` = "2023-01-01") |>
      httr2::req_headers(
        Authorization = paste("Bearer", token),
        `Content-Type` = "application/json"
      ) |>
      httr2::req_body_raw(corpo) |>
      httr2::req_perform()

    TRUE
  }, error = function(e) {
    message("emissione fallita: ", conditionMessage(e))
    FALSE
  })

  # Un'emissione fallita non e' silenziosa: il codice d'uscita la porta fuori,
  # cosi' il timer la registra e la run non risulta riuscita per intero.
  if (!emesso) {
    quit(status = 1L)
  }
}

# Il dettaglio per istanza va sullo standard error, cosi' che lo standard
# output resti il solo record e sia incollabile in una pipe senza filtri.
utils::write.table(
  osservazioni,
  file = stderr(), sep = "\t", quote = FALSE, row.names = FALSE
)
