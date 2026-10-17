#!/usr/bin/env Rscript

# Rapporto mensile ai referenti.
#
# Legge il registro delle richieste, il log delle creazioni e quello di ogni
# riga attiva, e la directory del tenant; calcola le voci del mese e manda a
# ogni referente il suo rapporto, a IT quello delle righe senza referente.
# E' una lavorazione sua, separata dal giro e dall'osservatore: un rapporto
# non partito non deve sembrare un canale guasto, e il suo record ha una
# tabella sua.
#
# Legge e manda posta, e basta: non scrive nel registro e non tocca Entra.
# Una guardia in tests/testthat/test-runner-guardie.R lo tiene tale, su
# questo file e su tutto cio' che il pacchetto raggiunge da
# provisioning_report().
#
# Gira ogni giorno, non una volta al mese: un allarme sui log guarda indietro
# al piu' due giorni, e una lavorazione mensile non si sorveglia con
# l'assenza di un record. Ogni giorno lascia il record; dal primo del mese
# manda il rapporto del mese prima a chi non l'ha ancora ricevuto. Il
# registro degli invii, un file per mese nella StateDirectory dell'unita', e'
# cio' che dice chi l'ha gia' ricevuto.
#
# Come per il giro, la decisione la prende il pacchetto e non questo file:
# qui ci sono l'ambiente, il Key Vault, l'inventario e la stampa.
#
# Nessun nome che identifichi una risorsa sta in questo file: il repository e'
# pubblico. Arrivano tutti dall'ambiente dell'unita' o dall'inventario sulla
# macchina; i soli valori di riserva sono percorsi sul disco.
#
# Uso:
#
#   Rscript runner-rapporto.R                 # il mese che da' l'orologio
#   Rscript runner-rapporto.R --mese 2026-10  # un mese forzato, a mano
#
# Il mese forzato e' un argomento e non una variabile, apposta: l'unita' del
# timer non passa argomenti, quindi un mese forzato non puo' restare acceso
# per sbaglio nel file d'ambiente che le tre lavorazioni condividono, dove
# fermerebbe ogni invio vero in silenzio. Un'esecuzione col mese forzato non
# scrive nel registro degli invii, e con la posta accesa vuole il
# dirottamento: e' un collaudo, e il mese che mostra di norma non e' finito.
# Un'esecuzione dirottata sul mese dell'orologio tiene invece un registro
# degli invii suo, accanto a quello vero: anche il collaudo manda una volta.

suppressMessages(library(ubep.azure))

INVENTARIO <- Sys.getenv(
  "UBEP_INVENTARIO",
  "/etc/ubep-provisioning/istanze.json"
)
KEYVAULT <- Sys.getenv("UBEP_KEYVAULT")
GRAPH <- Sys.getenv("UBEP_GRAPH")

# La StateDirectory dell'unita' (StateDirectory=ubep-rapporto): systemd la
# crea e la passa in STATE_DIRECTORY. Il valore di riserva e' lo stesso
# percorso, per un'esecuzione lanciata fuori dall'unita'. Con piu' di una
# StateDirectory systemd le separa con i due punti: vale la prima.
STATO <- strsplit(Sys.getenv("STATE_DIRECTORY"), ":", fixed = TRUE)[[1L]]
STATO <- if (length(STATO) > 0L && nzchar(STATO[[1L]])) {
  STATO[[1L]]
} else {
  "/var/lib/ubep-rapporto"
}

if (!nzchar(KEYVAULT)) {
  stop(
    "UBEP_KEYVAULT non e' impostata: senza il nome del Key Vault non si ",
    "legge il token del registro.",
    call. = FALSE
  )
}

# --- argomenti --------------------------------------------------------------

argomenti <- commandArgs(trailingOnly = TRUE)
MESE <- NULL
if (length(argomenti) > 0L) {
  if (identical(argomenti[[1L]], "--mese") && length(argomenti) == 2L) {
    MESE <- argomenti[[2L]]
  } else if (length(argomenti) == 1L &&
               startsWith(argomenti[[1L]], "--mese=")) {
    MESE <- sub("^--mese=", "", argomenti[[1L]])
  } else {
    # Un argomento scritto male non diventa un'esecuzione vera: chi voleva
    # forzare il mese e ha sbagliato a scriverlo manderebbe i rapporti del
    # mese dell'orologio, a tutti.
    stop(
      "argomenti non riconosciuti: ", paste(argomenti, collapse = " "),
      ". L'unico ammesso e' --mese AAAA-MM.",
      call. = FALSE
    )
  }
}

# --- posta ------------------------------------------------------------------

# Variabili proprie e non quelle del giro: le lavorazioni condividono lo
# stesso file d'ambiente, e un dirottamento acceso per collaudare il rapporto
# dirotterebbe anche gli esiti del canale. Spenta di default, come la posta
# del giro: installare il pacchetto non fa partire nessuna mail.
POSTA <- identical(Sys.getenv("UBEP_RAPPORTO_POSTA"), "1")
POSTA_A <- Sys.getenv("UBEP_RAPPORTO_POSTA_A")

# Mittente, copia e risposte sono quelli del giro: la stessa identita'
# verificata, e IT in copia. UBEP_POSTA_COPIA e' anche il destinatario del
# rapporto a IT.
POSTA_DA <- Sys.getenv("UBEP_POSTA_DA")
POSTA_COPIA <- Sys.getenv("UBEP_POSTA_COPIA")
POSTA_RISPOSTE <- Sys.getenv("UBEP_POSTA_RISPOSTE")

# L'utenza REDCap che possiede il token del registro, la stessa del giro
# (decisione del 2026-10-17). Solo le sue scritture di owned_by passano una
# riga a un altro referente. Sta sulla macchina e non qui, perche' il
# repository e' pubblico. Gli spazi ai bordi si tolgono: una variabile fatta
# di soli spazi e' una variabile che manca.
CANALE_UTENTE <- trimws(Sys.getenv("UBEP_CANALE_UTENTE"))

if (POSTA && !nzchar(POSTA_DA)) {
  stop(
    "UBEP_RAPPORTO_POSTA=1 senza UBEP_POSTA_DA: senza mittente ogni ",
    "messaggio verrebbe rifiutato.",
    call. = FALSE
  )
}

# Senza l'utenza del canale il pacchetto non crede a nessuna scrittura di
# owned_by: un rapporto che la dimenticasse manderebbe ogni riga al suo
# creatore, anche quella passata a un altro referente, senza dirlo.
if (!nzchar(CANALE_UTENTE)) {
  stop(
    "UBEP_CANALE_UTENTE non e' impostata: senza l'utenza del canale il ",
    "rapporto non sa a chi e' passata una riga.",
    call. = FALSE
  )
}

if (!is.null(MESE) && POSTA && !nzchar(POSTA_A)) {
  stop(
    "--mese con UBEP_RAPPORTO_POSTA=1 vuole UBEP_RAPPORTO_POSTA_A: un mese ",
    "forzato e' un collaudo, e senza dirottamento i rapporti di un mese ",
    "magari non finito andrebbero ai referenti veri.",
    call. = FALSE
  )
}

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

# --- il rapporto ------------------------------------------------------------

token <- token_imds("https://vault.azure.net")

# Il token di Graph si chiede solo se c'e' l'endpoint su cui spenderlo, come
# nel giro. Senza, il pacchetto riporta la directory come non letta e il
# record lo dice, invece di morire qui sull'IMDS. Basta `User.Read.All`, gia'
# concesso: i tre campi che il rapporto legge non chiedono altro.
token_graph <- if (nzchar(GRAPH)) {
  token_imds("https://graph.microsoft.com")
} else {
  ""
}

registro_token <- segreto_da_keyvault(registro[["segreto"]], token)

# La chiave del servizio di posta resta dentro la chiusura, come nel giro:
# il pacchetto sa che c'e' una funzione a cui chiedere di mandare, e non vede
# mai la chiave.
mailer <- if (POSTA) {
  chiave <- segreto_da_keyvault(registro[["segreto_posta"]], token)
  function(to, cc, subject, body) {
    ubep.azure:::mail_send(
      api_key = chiave, from = POSTA_DA, to = to, subject = subject,
      body = body, cc = cc,
      reply_to = if (nzchar(POSTA_RISPOSTE)) POSTA_RISPOSTE else NULL
    )
  }
} else {
  NULL
}

esito <- ubep.azure:::provisioning_report(
  register_url = as.character(registro[["host"]]),
  register_token = registro_token,
  graph_token = token_graph,
  graph_url = GRAPH,
  ledger_dir = STATO,
  now = Sys.time(),
  month = MESE,
  mailer = mailer,
  redirect_to = if (nzchar(POSTA_A)) POSTA_A else NULL,
  copy_to = if (nzchar(POSTA_COPIA)) POSTA_COPIA else NULL,
  channel_account = CANALE_UTENTE
)

# Il record e' anche il riassunto sullo standard output: cio' che si stampa e
# cio' che si emette sono lo stesso oggetto. Il dettaglio per rapporto va
# sullo standard error, con i destinatari, e non entra nel record: il record
# va in un workspace e ci resta, e porta solo conteggi e codici.
record <- ubep.azure:::report_record(esito, POSTA)
record[["TimeGenerated"]] <- format(
  Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
)

json <- ubep.azure:::run_record_json(record)
cat(json, "\n")

if (nrow(esito[["rapporti"]]) > 0L) {
  utils::write.table(
    esito[["rapporti"]],
    file = stderr(), sep = "\t", quote = FALSE, row.names = FALSE
  )
}

# --- emissione --------------------------------------------------------------

# Alla fine e non all'inizio, come nelle altre due lavorazioni: un record
# scritto all'inizio direbbe solo che il processo e' partito. L'allarme
# sull'assenza guarda `registro_letto` e `directory_letta`, non l'esistenza
# del record. Variabili proprie, perche' il rapporto scrive nella sua
# tabella: le regole del giro e dell'osservatore guardano l'ultimo record
# della loro senza chiedersi chi l'abbia scritto.
DCE <- Sys.getenv("UBEP_DCE")
DCR <- Sys.getenv("UBEP_DCR_RAPPORTO")
STREAM <- Sys.getenv("UBEP_STREAM_RAPPORTO")

emesso <- TRUE

if (nzchar(DCE) && nzchar(DCR) && nzchar(STREAM)) {
  emesso <- tryCatch(
    {
      token <- token_imds("https://monitor.azure.com")

      httr2::request(
        paste0(DCE, "/dataCollectionRules/", DCR, "/streams/", STREAM)
      ) |>
        httr2::req_url_query(`api-version` = "2023-01-01") |>
        httr2::req_headers(
          Authorization = paste("Bearer", token),
          `Content-Type` = "application/json"
        ) |>
        httr2::req_body_raw(paste0("[", json, "]")) |>
        httr2::req_perform()

      TRUE
    },
    error = function(e) {
      message("emissione fallita: ", conditionMessage(e))
      FALSE
    }
  )
}

# Un'emissione fallita, una lettura mancata o un rapporto non partito escono
# dal codice d'uscita, cosi' il timer li registra.
if (!emesso || length(esito[["errori"]]) > 0L) {
  quit(status = 1L)
}
