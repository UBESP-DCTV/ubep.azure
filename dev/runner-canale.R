#!/usr/bin/env Rscript

# Giro del canale di autorizzazione.
#
# Legge il registro delle richieste, chiede a ogni istanza servita lo stato
# delle coppie che le riguardano, e riporta nel registro il solo esito. E' un
# job suo, separato dall'osservatore: osservare e agire hanno cadenze diverse e
# conseguenze diverse, e un guasto nell'uno non deve fermare l'altro. Per la
# stessa ragione la guardia che vieta all'osservatore di scrivere resta dov'e'
# ed e' intatta -- quel runner continua a essere un lettore.
#
# La decisione la prende il pacchetto, non questo file: qui c'e' l'ambiente,
# il Key Vault, l'inventario e la stampa. Se una riga di questo script decide
# qualcosa, e' nel posto sbagliato.
#
# La scrittura si chiede e non si eredita: senza UBEP_SCRITTURA=1 il giro
# simula, e ogni riga del registro riporta `simulated` con `applied_as` che
# mostra che cosa succederebbe. E' il punto 1 del rollout, ed e' anche lo
# strumento con cui i referenti leggono il canale prima che scriva.
#
# Nessun nome che identifichi una risorsa sta in questo file: il repository e'
# pubblico. Arrivano tutti dall'ambiente dell'unita' o dall'inventario sulla
# macchina, fuori da git. Quindi nessun valore di riserva, salvo il percorso
# dell'inventario, che e' un percorso sul disco e non un nome dentro la
# sottoscrizione.

suppressMessages(library(ubep.azure))

INVENTARIO <- Sys.getenv(
  "UBEP_INVENTARIO",
  "/etc/ubep-provisioning/istanze.json"
)
KEYVAULT <- Sys.getenv("UBEP_KEYVAULT")

if (!nzchar(KEYVAULT)) {
  stop(
    "UBEP_KEYVAULT non e' impostata: senza il nome del Key Vault non si ",
    "legge nessun segreto, e il giro direbbe che la flotta e' irraggiungibile.",
    call. = FALSE
  )
}

SCRITTURA <- identical(Sys.getenv("UBEP_SCRITTURA"), "1")

# --- identita' gestita ------------------------------------------------------

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

if (!file.exists(INVENTARIO)) {
  stop("inventario non trovato: ", INVENTARIO, call. = FALSE)
}
inventario <- jsonlite::fromJSON(INVENTARIO, simplifyVector = FALSE)

registro <- inventario[["registro"]]
if (is.null(registro[["host"]]) || is.null(registro[["segreto"]])) {
  stop(
    "l'inventario non descrive il registro: servono `registro.host` e ",
    "`registro.segreto`, cioe' dove sta il progetto delle richieste e sotto ",
    "quale nome vive il suo token in Key Vault.",
    call. = FALSE
  )
}

con_modulo <- inventario[["con_modulo"]]
if (length(con_modulo) == 0L) {
  stop("l'inventario non elenca nessuna istanza con il modulo", call. = FALSE)
}

# L'elenco delle scelte del campo `server`, nell'ordine in cui il registro le
# porta: l'ordine e' parte del valore, perche' il confronto e' sulla stringa
# intera. Se manca, il confronto giudica le altre colonne e dichiara di non
# aver potuto guardare questa -- che e' meno di un cancello e piu' di un verde
# non guadagnato.
flotta <- inventario[["flotta"]]
flotta <- if (is.null(flotta)) {
  NULL
} else {
  vapply(flotta, as.character, character(1))
}

# --- il giro ----------------------------------------------------------------

token <- token_imds("https://vault.azure.net")

nomi <- vapply(con_modulo, function(i) as.character(i[["nome"]]), character(1))
host <- vapply(con_modulo, function(i) as.character(i[["host"]]), character(1))
names(host) <- nomi

# Un segreto che non si riesce a leggere e' un NA, non un'eccezione: le altre
# istanze vanno servite lo stesso, e il giro sa gia' dire che cosa significa un
# segreto illeggibile per le righe che lo riguardano.
segreti <- vapply(con_modulo, function(istanza) {
  tryCatch(
    segreto_da_keyvault(istanza[["segreto"]], token),
    error = function(e) NA_character_
  )
}, character(1))
names(segreti) <- nomi

registro_token <- segreto_da_keyvault(registro[["segreto"]], token)

esito <- ubep.azure:::provisioning_reconcile(
  register_url = as.character(registro[["host"]]),
  register_token = registro_token,
  hosts = host,
  secrets = segreti,
  instances = flotta,
  dry_run = !SCRITTURA,
  at = format(Sys.time(), "%Y-%m-%d %H:%M", tz = "UTC")
)

# Il riassunto sullo standard output, il dettaglio per riga sullo standard
# error: cosi' l'uno resta incollabile in una pipe e l'altro leggibile da chi
# guarda una run singola. L'emissione in telemetria e' del sotto-progetto 4 e
# non sta qui.
cat(as.character(jsonlite::toJSON(
  list(
    at = esito[["at"]],
    fermato = esito[["fermato"]],
    scrittura = SCRITTURA,
    schema_ferma = esito[["schema"]][["blocks"]] %||% FALSE,
    schema_differenze = I(c(
      esito[["schema"]][["blocking"]] %||% character(),
      esito[["schema"]][["tolerated"]] %||% character()
    )),
    istanze = nrow(esito[["istanze"]]),
    irraggiungibili = sum(!esito[["istanze"]][["raggiunta"]]),
    righe = nrow(esito[["esiti"]]),
    scritte = esito[["scritte"]],
    errori = I(esito[["errori"]] %||% character())
  ),
  auto_unbox = TRUE, null = "null"
)), "\n")

if (nrow(esito[["esiti"]]) > 0L) {
  utils::write.table(
    esito[["esiti"]],
    file = stderr(), sep = "\t", quote = FALSE, row.names = FALSE
  )
}

if (length(esito[["errori"]]) > 0L || isTRUE(esito[["fermato"]])) {
  quit(status = 1L)
}
