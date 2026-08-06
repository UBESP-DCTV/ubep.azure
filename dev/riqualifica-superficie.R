# Riqualificazione di una superficie nuova
#
# Esegue i quattro passi del protocollo (§7 del design della fase 3) contro
# un'istanza la cui impronta di superficie è cambiata — tipicamente dopo un
# aggiornamento di REDCap dentro la stessa major:
#
#   1. `state` legge l'impronta corrente;
#   2. una riga nel registro, con `tested_on` di oggi e conformità vuota;
#   3. `run_conformance_check()`, che può scrivere perché dichiara le impronte
#      *misurate* e non quelle certificate;
#   4. la run scrive lei `conformance_passed_on` sulla riga della coppia.
#
# Fra il passo 1 e il passo 4 il chiamante ordinario continua a leggere e le
# sue scritture sono degradate a `dry_run`. È il comportamento voluto: un'
# impronta ignota non è un errore, è una versione da collaudare.
#
# Perché esiste come script invece che come procedura da rifare a mano: il
# momento in cui serve è subito dopo una finestra di manutenzione, che è il
# momento peggiore per improvvisare quattro passi in ordine. Qui l'ordine è
# fissato e i modi di sbagliarlo sono cancelli, non promemoria.
#
# Uso:
#   Rscript dev/riqualifica-superficie.R            # esegue
#   Rscript dev/riqualifica-superficie.R --diagnosi # dice solo dove siamo
#
# Chiede rete, segreto e istanza: server, segreto e progetto di conformità
# arrivano da `.Renviron` e in questo repository pubblico non compaiono.

solo_diagnosi <- "--diagnosi" %in% commandArgs(trailingOnly = TRUE)

arresta <- function(...) {
  cat("\nARRESTO:", ..., "\n")
  quit(status = 1L, save = "no")
}

cat("== Riqualificazione di una superficie ==\n")
if (solo_diagnosi) cat("(modo diagnosi: nessuna scrittura)\n")


# --- Precondizioni -----------------------------------------------------

# Il registro va scritto nell'albero sorgente, o la data non arriva mai in
# git: contro una copia installata `system.file()` risolve nella libreria di
# installazione, e non c'è nessun errore — semplicemente niente da committare.
suppressMessages(devtools::load_all("."))

percorso <- system.file(
  "extdata", "tested-fingerprints.csv",
  package = "ubep.azure"
)
atteso <- normalizePath(
  file.path("inst", "extdata", "tested-fingerprints.csv"),
  mustWork = FALSE
)
if (!nzchar(percorso) || normalizePath(percorso) != atteso) {
  arresta(
    "il registro non risolve nell'albero sorgente ma in", percorso,
    "\n  Lanciare dalla radice del repository, non contro una copia",
    "installata."
  )
}

variabili <- c(
  "UBEP_REDCAP_SERVER", "UBEP_REDCAP_SECRET",
  "UBEP_TEST_PROJECT", "UBEP_TEST_USER"
)
mancanti <- variabili[!nzchar(Sys.getenv(variabili))]
if (length(mancanti)) {
  arresta("mancano in .Renviron:", paste(mancanti, collapse = ", "))
}


# --- Passo 1: leggere l'impronta corrente ------------------------------

cat("\n-- passo 1: stato dell'istanza --\n")
stato <- module_state(
  Sys.getenv("UBEP_REDCAP_SERVER"), Sys.getenv("UBEP_REDCAP_SECRET"),
  pairs = list()
)
if (!isTRUE(stato[["ok"]])) {
  arresta(
    "l'istanza non ha risposto come attesa:",
    paste(unlist(stato[["errors"]]), collapse = ", ")
  )
}

payload <- stato[["payload"]]
versione <- as.character(payload[["redcap_version"]])
major <- as.integer(strsplit(versione, ".", fixed = TRUE)[[1]][[1]])
impronta <- as.character(payload[["surface_fingerprint"]])

cat("  REDCap         :", versione, "(major", major, ")\n")
cat("  modulo         :", as.character(payload[["module_version"]]), "\n")
cat("  contratto      :", format(payload[["contract_version"]]), "\n")
cat("  impronta        :", impronta, "\n")
cat("  cancello major :", as.character(payload[["version_gate"]]), "\n")

# Il cancello di major è l'altro asse, e ha un vincolo d'ordine suo: sopra il
# soffitto la scrittura è forzata a `dry_run`, quindi la conformità non
# potrebbe scrivere e i cinque casi risulterebbero rossi per una ragione che
# non è una difformità. Va alzato prima il soffitto nel modulo, e solo dopo
# rieseguita la conformità — mai il contrario. Per un aggiornamento dentro la
# stessa major questo ramo non scatta, ed è il caso ordinario.
cancello <- as.character(payload[["version_gate"]])
if (identical(cancello, "sotto_minimo")) {
  arresta(
    "l'istanza è sotto il pavimento di major del modulo: il canale rifiuta",
    "ogni operazione, e non c'è niente da riqualificare."
  )
}
if (identical(cancello, "non_collaudata")) {
  arresta(
    "l'istanza è sopra il soffitto collaudato: la scrittura sarebbe forzata",
    "a dry_run e tutti i casi della conformità risulterebbero rossi senza",
    "essere difformità.\n  Prima si alza UBEP_CEILING_MAJOR in",
    "inst/redcap-module/api.php e si ridistribuisce il modulo, poi si",
    "rilancia questo script."
  )
}


# --- Passo 2: la riga nel registro -------------------------------------

cat("\n-- passo 2: il registro --\n")
registro <- readr::read_csv(percorso, show_col_types = FALSE)

riga <- !is.na(registro[["redcap_major"]]) &
  registro[["redcap_major"]] == major &
  !is.na(registro[["fingerprint"]]) &
  registro[["fingerprint"]] == impronta

if (any(riga)) {
  gia_certificata <- !is.na(registro[["conformance_passed_on"]][riga])
  if (any(gia_certificata)) {
    cat(
      "  la coppia (", major, ", ", impronta,
      ") è già certificata il ",
      as.character(registro[["conformance_passed_on"]][riga][[1]]),
      ".\n", sep = ""
    )
    cat("  Non c'è niente da riqualificare: l'impronta non è cambiata.\n")
    cat("\n== nulla da fare ==\n")
    quit(status = 0L, save = "no")
  }
  cat("  la riga esiste già senza data: riprendo da lì.\n")
} else {
  cat("  impronta nuova: la coppia (", major, ", ", impronta,
      ") non è nel registro.\n", sep = "")
  if (solo_diagnosi) {
    cat("  (in diagnosi non la aggiungo)\n")
  } else {
    nuova <- registro[0, ]
    nuova[1, "redcap_major"] <- major
    nuova[1, "fingerprint"] <- impronta
    nuova[1, "tested_on"] <- Sys.Date()
    nuova[1, "conformance_passed_on"] <- NA
    nuova[1, "note"] <- paste0("REDCap ", versione)
    # Le righe vecchie non si toccano: restano il collaudo delle superfici
    # che certificano, e una di esse è ancora quella che le istanze non
    # ancora aggiornate espongono.
    readr::write_csv(rbind(registro, nuova), percorso)
    cat("  riga aggiunta, conformità vuota.\n")
  }
}

if (solo_diagnosi) {
  cat("\n== diagnosi conclusa: servirebbe una riqualificazione ==\n")
  quit(status = 0L, save = "no")
}


# --- Passi 3 e 4: la conformità, che scrive lei la data ----------------

cat("\n-- passi 3 e 4: conformità --\n")
cat("  Precondizioni che questo script non può verificare da solo:\n")
cat("   - l'account di prova non deve avere diritti nel progetto;\n")
cat("   - il progetto deve definire i ruoli e il DAG che i casi nominano.\n")

esito <- run_conformance_check(
  server     = Sys.getenv("UBEP_REDCAP_SERVER"),
  secret     = Sys.getenv("UBEP_REDCAP_SECRET"),
  project_id = as.integer(Sys.getenv("UBEP_TEST_PROJECT")),
  username   = Sys.getenv("UBEP_TEST_USER")
)

for (nome in names(esito[["steps"]])) {
  cat(sprintf("  %-32s %s\n", nome, format(esito[["steps"]][[nome]])))
}

if (!isTRUE(esito[["conforms"]])) {
  cat("\n  differenze:\n")
  cat(paste0("   - ", esito[["differences"]], collapse = "\n"), "\n")
  arresta(
    "la conformità non è passata. La riga nel registro resta senza data,",
    "che è lo stato corretto: la superficie non è certificata.\n ",
    "Prima di sospettare la versione nuova, verificare le due precondizioni",
    "qui sopra — un ruolo mancante somiglia a una difformità e non lo è."
  )
}


# --- Esito -------------------------------------------------------------

cat("\n== riqualificata ==\n")
cat(readLines(percorso), sep = "\n")
cat("\n\nDa committare (data e riga nascono qui, non si digitano):\n")
cat("  git add inst/extdata/tested-fingerprints.csv\n")
cat("  git commit -m \"Riqualifica la superficie di REDCap ", versione, "\"\n",
    sep = "")
