test_that("ogni parola del vocabolario degli esiti ha le due lingue", {
  # eval
  detto <- lapply(outcome_vocabulary(), mail_outcome_words)

  # test
  for (parola in detto) {
    expect_named(parola, c("it", "en"))
    expect_true(all(nzchar(parola)))
  }
})


test_that("un esito fuori vocabolario si rifiuta invece di inventarsi", {
  expect_error(mail_outcome_words("inventato"), "fuori vocabolario")
})


test_that("l'ora del registro e' UTC e quella della mail e' italiana", {
  # eval
  detto <- mail_local_time("2026-08-24 12:04")

  # test
  expect_equal(detto, "2026-08-24 14:04")
})


test_that("un `outcome_at` che non e' una data non diventa un'ora sbagliata", {
  expect_true(is.na(mail_local_time("")))
  expect_true(is.na(mail_local_time("mai")))
})


test_that("l'oggetto porta le due lingue e il numero della richiesta", {
  # eval
  detto <- mail_outcome_message(riga_di_prova())

  # test
  expect_equal(
    detto[["subject"]],
    "Richiesta 16: errore di dato / Request 16: data error"
  )
})


test_that("il corpo porta le due lingue, separate", {
  # eval
  detto <- mail_outcome_message(riga_di_prova())[["body"]]

  # test
  expect_match(detto, "La richiesta 16", fixed = TRUE)
  expect_match(detto, "Request 16", fixed = TRUE)
  expect_match(detto, "\n---\n", fixed = TRUE)
})


test_that("un campo vuoto cambia la frase invece di lasciare un buco", {
  # eval
  detto <- mail_outcome_message(
    riga_di_prova(username = "", applied_as = "")
  )[["body"]]

  # test
  expect_match(detto, "non ancora stabilito", fixed = TRUE)
  expect_match(detto, "l'istanza non ha risposto", fixed = TRUE)
  expect_false(grepl("Nome utente risolto: \n", detto, fixed = TRUE))
})


test_that("una revoca eseguita non dice che un accesso e' stato concesso", {
  # eval
  detto <- mail_outcome_message(riga_di_prova(
    outcome = "applied", outcome_detail = "",
    request_status = "revoked", applied_as = "absent"
  ))[["body"]]

  # test
  expect_match(detto, "l'accesso e' stato tolto", fixed = TRUE)
  expect_false(grepl("l'accesso e' stato concesso", detto, fixed = TRUE))
})


test_that("l'ora nel corpo e' quella italiana, e nomina il fuso", {
  # eval
  detto <- mail_outcome_message(riga_di_prova())[["body"]]

  # test
  expect_match(detto, "2026-08-24 14:04", fixed = TRUE)
  expect_match(detto, "ora italiana", fixed = TRUE)
})


test_that("le istruzioni di primo accesso non portano nessun segreto", {
  # eval
  detto <- mail_welcome_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it"
  )[["body"]]

  # test
  expect_match(detto, "sara.collaudozeta@ubep.unipd.it", fixed = TRUE)
  expect_match(detto, "cinzia@ubep.unipd.it", fixed = TRUE)
  expect_match(detto, "second factor", fixed = TRUE)
  expect_false(grepl(finti[["parola"]], detto, fixed = TRUE))
})


test_that("il benvenuto dice da dove si apre REDCap, nelle due lingue", {
  # eval
  detto <- mail_welcome_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    url = "https://edc10.example.org/redcap/"
  )[["body"]]

  # test
  expect_match(
    detto, "REDCap si apre da: https://edc10.example.org/redcap/",
    fixed = TRUE
  )
  expect_match(
    detto, "REDCap opens at: https://edc10.example.org/redcap/", fixed = TRUE
  )
  expect_match(detto, "entro quattro ore da questo messaggio", fixed = TRUE)
  expect_match(detto, "within four hours of this message", fixed = TRUE)
})


test_that("l'indirizzo dell'istanza segue il nome utente, non la chiave", {
  # eval
  righe <- strsplit(mail_welcome_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    url = "https://edc10.example.org/"
  )[["body"]], "\n", fixed = TRUE)[[1]]
  dove <- function(testo) grep(testo, righe, fixed = TRUE)

  # test
  # In each language: the user name, then the address and the four hours, then
  # who hands over the key. The rest of the message is where it was.
  expect_true(dove("ti autentichi")[[1]] < dove("REDCap si apre da")[[1]])
  expect_true(dove("REDCap si apre da")[[1]] < dove("quattro ore")[[1]])
  expect_true(dove("quattro ore")[[1]] < dove("non e' in questo")[[1]])
  expect_true(dove("sign in with")[[1]] < dove("REDCap opens at")[[1]])
  expect_true(dove("REDCap opens at")[[1]] < dove("four hours")[[1]])
  expect_true(dove("four hours")[[1]] < dove("The way in is not")[[1]])
})


test_that("senza indirizzo dell'istanza il benvenuto parte com'era", {
  # eval
  riga <- riga_di_prova()
  upn <- "sara.collaudozeta@ubep.unipd.it"
  com_era <- mail_welcome_message(riga, upn = upn)

  # test
  # A missing address is not a reason to lose the message: it leaves without
  # the two lines, and otherwise exactly as it did before they existed.
  for (url in list(NULL, NA_character_, "")) {
    detto <- mail_welcome_message(riga, upn = upn, url = url)
    expect_identical(detto, com_era)
    expect_false(grepl("REDCap si apre da", detto[["body"]], fixed = TRUE))
    expect_false(grepl("quattro ore", detto[["body"]], fixed = TRUE))
    expect_false(grepl("REDCap opens at", detto[["body"]], fixed = TRUE))
    expect_match(detto[["body"]], upn, fixed = TRUE)
  }
})


test_that("l'indirizzo dell'istanza si compone dall'host dell'inventario", {
  # test
  expect_equal(
    mail_instance_url("edc03.example.org"), "https://edc03.example.org/"
  )
  expect_equal(
    mail_instance_url("edc01.example.org/redcap"),
    "https://edc01.example.org/redcap/"
  )
  # The same normalization `module_call()` makes, so a host the instances
  # answer on cannot turn into an address nobody can open.
  expect_equal(
    mail_instance_url("https://edc01.example.org/redcap/"),
    "https://edc01.example.org/redcap/"
  )
  expect_null(mail_instance_url(NULL))
  expect_null(mail_instance_url(NA_character_))
  expect_null(mail_instance_url(""))
})


test_that("il messaggio d'ingresso non nomina istanza, progetto, ruolo", {
  # eval
  detto <- mail_credential_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    credential = finti[["parola"]]
  )[["body"]]

  # test
  expect_match(detto, finti[["parola"]], fixed = TRUE)
  expect_false(grepl("edc10", detto, fixed = TRUE))
  expect_false(grepl("29", detto, fixed = TRUE))
  expect_false(grepl("collaudo-canale", detto, fixed = TRUE))
})


test_that("il messaggio con la chiave dice come consegnarla", {
  # eval
  detto <- mail_credential_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    credential = finti[["parola"]]
  )[["body"]]

  # test
  # The rule the referent follows, decided on 2026-10-14: a new message with
  # the key alone, to the address they know, never a forward of this one.
  it <- c(
    paste0(
      "Consegna la chiave alla persona, e non inoltrare questo messaggio. Se ",
      "hai un canale diverso dalla posta, usa quello; altrimenti scrivile una ",
      "mail nuova con la sola chiave: il nome utente le e' gia' arrivato in ",
      "un messaggio a parte. Usa l'indirizzo che conosci dalla tua ",
      "corrispondenza con lei, non quello copiato dalla richiesta. Se i due ",
      "non coincidono, fermati e rispondi a questo messaggio senza la chiave ",
      "(togli il testo citato): quel messaggio a parte e' andato ",
      "all'indirizzo della richiesta."
    ),
    "Va cambiata al primo accesso, e chi la usa per prima si prende l'account."
  )
  en <- c(
    paste0(
      "Hand the key to the person, and do not forward this message. If you ",
      "have a channel other than e-mail, use it; otherwise write them a new ",
      "e-mail with the key alone: the user name has already reached them in a ",
      "separate message. Use the address you know from your own ",
      "correspondence with them, not the one copied from the request. If the ",
      "two differ, stop and reply to this message without the key (delete ",
      "the quoted text): that separate message went to the address in the ",
      "request."
    ),
    paste0(
      "It must be changed at first sign-in, and whoever uses it first takes ",
      "the account."
    )
  )
  righe <- strsplit(detto, "\n", fixed = TRUE)[[1]]
  for (frase in c(it, en)) {
    expect_true(frase %in% righe, info = frase)
  }
  expect_false(grepl("per una via sicura", detto, fixed = TRUE))
  expect_false(grepl("Hand it over securely", detto, fixed = TRUE))
})


test_that("la risposta chiesta dal messaggio con la chiave la lascia fuori", {
  # eval
  detto <- mail_credential_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    credential = finti[["parola"]]
  )[["body"]]

  # test
  # A reply goes to reply_to, the shared mailbox of IT, and a mail client
  # quotes the body by default: the key, still unused, would land there. So
  # the very sentence that asks for a reply says to leave the key out of it.
  expect_match(
    detto, "rispondi a questo messaggio senza la chiave", fixed = TRUE
  )
  expect_match(detto, "reply to this message without the key", fixed = TRUE)
})


test_that("il messaggio con la chiave non porta il contesto della persona", {
  # eval
  riga <- riga_di_prova()
  detto <- mail_credential_message(
    riga, upn = "sara.collaudozeta@ubep.unipd.it",
    credential = finti[["parola"]]
  )[["body"]]

  # test
  # It tells the referent to use the address they know, and does not name the
  # one in the request: copying it from here is what the rule forbids.
  expect_false(grepl(riga[["contact_email"]], detto, fixed = TRUE))
  expect_false(grepl(riga[["last_name"]], detto, fixed = TRUE))
  expect_false(grepl("https://", detto, fixed = TRUE))
})


test_that("nessun altro messaggio puo' nominare la chiave d'ingresso", {
  # eval
  riga <- riga_di_prova()
  altri <- list(
    mail_outcome_message(riga)[["body"]],
    mail_welcome_message(riga, upn = "sara@ubep.unipd.it")[["body"]],
    mail_welcome_message(
      riga, upn = "sara@ubep.unipd.it", url = "https://edc10.example.org/"
    )[["body"]]
  )

  # test
  for (corpo in altri) {
    expect_false(grepl(finti[["parola"]], corpo, fixed = TRUE))
  }
})


test_that("manda al servizio di posta, col mittente e la chiave che riceve", {
  # eval
  catturata <- NULL
  detto <- httr2::with_mocked_responses(
    function(req) {
      catturata <<- req
      httr2::response(status_code = 202L)
    },
    mail_send(
      api_key = finti[["chiave"]], from = "mittente@example.org",
      to = "destinatario@example.org", subject = "oggetto", body = "corpo",
      cc = "copia@example.org", reply_to = "risposte@example.org"
    )
  )

  # test
  expect_true(detto[["ok"]])
  expect_equal(detto[["errors"]], character())
  expect_match(catturata[["url"]], "api.sendgrid.com", fixed = TRUE)
  expect_equal(catturata[["method"]], "POST")
  # `httr2` redige `Authorization` da se': letto come lista, l'header e' un
  # riferimento debole e non una stringa. `req_get_headers(redact = FALSE)` e'
  # la via pubblica per rivederlo, ed e' anche la prova che la redazione c'e' --
  # cioe' che la chiave non finisce in un `print()` della richiesta.
  expect_equal(
    httr2::req_get_headers(catturata, redacted = "reveal")[["Authorization"]],
    paste("Bearer", finti[["chiave"]])
  )
})


test_that("un rifiuto del servizio non e' un giro rotto, e' un esito", {
  # eval
  # Silenziato di proposito: le parole del servizio hanno i loro test qui
  # sotto, e questo prova che un rifiuto resta un esito e non un giro rotto.
  detto <- suppressMessages(httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 403L),
    mail_send(
      api_key = finti[["chiave"]], from = "m@example.org",
      to = "d@example.org", subject = "o", body = "c"
    )
  ))

  # test
  expect_false(detto[["ok"]])
  expect_equal(detto[["errors"]], "TRASPORTO_POSTA_RIFIUTATA")
})


test_that("il servizio irraggiungibile si distingue dal servizio che rifiuta", {
  # eval
  detto <- httr2::with_mocked_responses(
    function(req) stop("rete assente"),
    mail_send(
      api_key = finti[["chiave"]], from = "m@example.org",
      to = "d@example.org", subject = "o", body = "c"
    )
  )

  # test
  expect_false(detto[["ok"]])
  expect_equal(detto[["errors"]], "TRASPORTO_POSTA_NON_RAGGIUNGIBILE")
})


test_that("un rifiuto riporta le parole del servizio, non solo il suo codice", {
  # eval
  corpo <- paste0(
    '{"errors":[{"message":"The requestor\'s IP Address is not whitelisted",',
    '"field":null,"help":null}]}'
  )

  detto <- NULL
  avviso <- testthat::capture_messages(
    detto <- httr2::with_mocked_responses(
      function(req) {
        httr2::response(status_code = 403L, body = charToRaw(corpo))
      },
      mail_send(
        api_key = finti[["chiave"]], from = "m@example.org",
        to = "d@example.org", subject = "o", body = "c"
      )
    )
  )

  # test
  # Il codice del vocabolario chiuso e' cio' che la telemetria conta, e non
  # cambia. Le parole del servizio sono cio' che dice PERCHE', e vanno sullo
  # standard di errore, cioe' nel journal, dove chi diagnostica un giro sta
  # gia' guardando. Il 2026-08-27 quella stessa condizione ha dato 403 su un
  # endpoint e 401 su un altro, con dentro la stessa frase: senza questa riga
  # si va a cercare un guasto di rete.
  expect_equal(detto[["errors"]], "TRASPORTO_POSTA_RIFIUTATA")
  expect_match(avviso, "not whitelisted", fixed = TRUE, all = FALSE)
  expect_match(avviso, "403", fixed = TRUE, all = FALSE)
})


test_that("le parole del servizio non portano con se' la chiave", {
  # eval
  avviso <- testthat::capture_messages(
    httr2::with_mocked_responses(
      function(req) {
        httr2::response(
          status_code = 401L, body = charToRaw("chiave non valida")
        )
      },
      mail_send(
        api_key = finti[["chiave"]], from = "m@example.org",
        to = "d@example.org", subject = "o", body = "c"
      )
    )
  )

  # test
  # Il corpo della risposta e' del servizio e non nostro, quindi non riecheggia
  # la richiesta. Questa guardia lo verifica invece di darlo per buono, ed e' la
  # sorella di quella sull'header che `httr2` redige.
  expect_false(any(grepl(finti[["chiave"]], avviso, fixed = TRUE)))
})


test_that("un rifiuto senza corpo resta un esito, non un errore", {
  # eval
  detto <- NULL
  avviso <- testthat::capture_messages(
    detto <- httr2::with_mocked_responses(
      function(req) httr2::response(status_code = 500L),
      mail_send(
        api_key = finti[["chiave"]], from = "m@example.org",
        to = "d@example.org", subject = "o", body = "c"
      )
    )
  )

  # test
  # Un corpo assente o illeggibile -- un proxy che risponde HTML, una risposta
  # troncata -- non deve trasformare un esito in un'eccezione: sarebbe un
  # guasto nuovo introdotto dalla diagnosi che doveva renderne leggibile un
  # altro. Lo stato resta, ed e' gia' meta' della risposta.
  expect_equal(detto[["errors"]], "TRASPORTO_POSTA_RIFIUTATA")
  expect_match(avviso, "500", fixed = TRUE, all = FALSE)
})


test_that("i due messaggi nuovi portano le due lingue", {
  # eval
  riga <- riga_di_prova()
  corpi <- c(
    mail_welcome_message(riga, upn = "sara@ubep.unipd.it")[["body"]],
    mail_credential_message(
      riga, upn = "sara@ubep.unipd.it", credential = finti[["parola"]]
    )[["body"]]
  )

  # test
  for (corpo in corpi) {
    expect_match(corpo, "\n---\n", fixed = TRUE)
  }
})


raccoglitore <- function(riesce = TRUE) {
  mandate <- list()
  list(
    mailer = function(to, cc, subject, body) {
      mandate[[length(mandate) + 1L]] <<- list(
        to = to, cc = cc, subject = subject, body = body
      )
      if (isTRUE(riesce)) {
        list(ok = TRUE, errors = character())
      } else {
        list(ok = FALSE, errors = "TRASPORTO_POSTA_RIFIUTATA")
      }
    },
    mandate = function() mandate
  )
}


colonne_cambiate <- c("record_id", "outcome", "outcome_detail", "applied_as")


registro_di_prova <- function(...) {
  as.data.frame(riga_di_prova(...), stringsAsFactors = FALSE)
}


test_that("l'esito va a chi ha compilato, non alla persona nominata", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  # eval
  mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = FALSE, copy_to = "it@example.org"
  )

  # test
  mandate <- posta[["mandate"]]()
  expect_length(mandate, 1L)
  expect_equal(mandate[[1L]][["to"]], "cinzia@ubep.unipd.it")
  expect_equal(mandate[[1L]][["cc"]], "it@example.org")
})


test_that("un giro che simula non manda niente, e scrive tutto", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  # eval
  detto <- mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = TRUE
  )

  # test
  expect_length(posta[["mandate"]](), 0L)
  expect_equal(nrow(detto[["recapitate"]]), 1L)
})


test_that("una riga la cui mail non parte non si puo' scrivere", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[, colonne_cambiate, drop = FALSE]

  # eval
  detto <- mail_round(
    changed, registro, born = list(),
    mailer = raccoglitore(riesce = FALSE)[["mailer"]], dry_run = FALSE
  )

  # test
  expect_equal(nrow(detto[["recapitate"]]), 0L)
  expect_equal(detto[["errori"]], "TRASPORTO_POSTA_RIFIUTATA")
  expect_equal(detto[["contatori"]][["posta_fallite"]], 1L)
})


test_that("il messaggio porta l'esito di questo giro, non quello vecchio", {
  # eval
  registro <- registro_di_prova(
    outcome = "data_error", outcome_detail = "DATO_RUOLO_INESISTENTE"
  )
  changed <- registro[, colonne_cambiate, drop = FALSE]
  changed[["outcome"]] <- "applied"
  changed[["outcome_detail"]] <- ""
  posta <- raccoglitore()

  # eval
  mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = FALSE
  )

  # test
  corpo <- posta[["mandate"]]()[[1L]][["body"]]
  expect_match(corpo, "eseguita", fixed = TRUE)
  expect_false(grepl("DATO_RUOLO_INESISTENTE", corpo, fixed = TRUE))
})


test_that("il messaggio nomina l'identita' che il giro ha stabilito", {
  # eval
  # A row as a referent files it: the UPN is not typed, the round resolves it.
  registro <- registro_di_prova(username = "", identity = "")
  changed <- registro[, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  # eval
  mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = FALSE,
    identified = data.frame(
      record_id = "16",
      username = "sara.collaudozeta@ubep.unipd.it",
      identity = "existing",
      stringsAsFactors = FALSE
    )
  )

  # test
  # The resolution happens before the mail and is already in the register by
  # the time it leaves, so the message that says it is not established yet is
  # contradicting a value this same round wrote.
  corpo <- posta[["mandate"]]()[[1L]][["body"]]
  expect_match(corpo, "sara.collaudozeta@ubep.unipd.it", fixed = TRUE)
  expect_false(grepl("non ancora stabilito", corpo, fixed = TRUE))
})


test_that("una nascita produce due messaggi, a due destinatari diversi", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()
  nati <- list(list(
    record_id = "16", upn = "sara@ubep.unipd.it",
    credential = finti[["parola"]]
  ))

  # eval
  detto <- mail_round(
    changed, registro, born = nati, mailer = posta[["mailer"]],
    dry_run = FALSE
  )

  # test
  mandate <- posta[["mandate"]]()
  expect_length(mandate, 2L)
  expect_setequal(
    vapply(mandate, function(m) m[["to"]], character(1)),
    c("sara.esterna@example.org", "cinzia@ubep.unipd.it")
  )
  expect_equal(detto[["contatori"]][["credenziali_recapitate"]], 1L)
})


test_that("il benvenuto porta l'indirizzo dell'istanza della sua riga", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()
  nati <- list(list(
    record_id = "16", upn = "sara@ubep.unipd.it",
    credential = finti[["parola"]]
  ))

  # eval
  mail_round(
    changed, registro, born = nati, mailer = posta[["mailer"]],
    dry_run = FALSE,
    hosts = c(edc10 = "edc10.example.org/redcap", edc12 = "edc12.example.org")
  )

  # test
  mandate <- posta[["mandate"]]()
  a <- function(chi) {
    Filter(function(m) identical(m[["to"]], chi), mandate)[[1L]][["body"]]
  }
  benvenuto <- a("sara.esterna@example.org")
  chiave <- a("cinzia@ubep.unipd.it")
  expect_match(
    benvenuto, "REDCap si apre da: https://edc10.example.org/redcap/",
    fixed = TRUE
  )
  expect_false(grepl("edc12", benvenuto, fixed = TRUE))
  # The message with the key carries no context, and an address is context:
  # with it, a key that leaked would come with the door it opens.
  expect_false(grepl("example.org", chiave, fixed = TRUE))
  expect_false(grepl("https://", chiave, fixed = TRUE))
  expect_false(grepl("edc10", chiave, fixed = TRUE))
})


test_that("un'istanza che l'inventario non conosce non ferma il benvenuto", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  nati <- list(list(
    record_id = "16", upn = "sara@ubep.unipd.it",
    credential = finti[["parola"]]
  ))

  for (hosts in list(NULL, c(edc12 = "edc12.example.org"))) {
    posta <- raccoglitore()

    # eval
    mail_round(
      changed, registro, born = nati, mailer = posta[["mailer"]],
      dry_run = FALSE, hosts = hosts
    )

    # test
    benvenuto <- Filter(
      function(m) identical(m[["to"]], "sara.esterna@example.org"),
      posta[["mandate"]]()
    )
    expect_length(benvenuto, 1L)
    expect_false(
      grepl("REDCap si apre da", benvenuto[[1L]][["body"]], fixed = TRUE)
    )
  }
})


test_that("una chiave d'ingresso non recapitata ha un codice suo", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  nati <- list(list(
    record_id = "16", upn = "sara@ubep.unipd.it",
    credential = finti[["parola"]]
  ))

  # eval
  detto <- mail_round(
    changed, registro, born = nati,
    mailer = raccoglitore(riesce = FALSE)[["mailer"]], dry_run = FALSE
  )

  # test
  expect_true("POSTA_CREDENZIALE_PERSA" %in% detto[["errori"]])
  expect_equal(detto[["contatori"]][["credenziali_perse"]], 1L)
})


# A mailer that fails for one recipient only, so a test can lose the welcome
# and keep the key, or the other way round.
rifiuta_a <- function(chi) {
  mandate <- list()
  list(
    mailer = function(to, cc, subject, body) {
      mandate[[length(mandate) + 1L]] <<- list(to = to, subject = subject)
      if (identical(to, chi)) {
        list(ok = FALSE, errors = "TRASPORTO_POSTA_RIFIUTATA")
      } else {
        list(ok = TRUE, errors = character())
      }
    },
    mandate = function() mandate
  )
}


nascita_di_prova <- function(credential, record_id = "16") {
  list(list(
    record_id = record_id, upn = "sara@ubep.unipd.it", credential = credential
  ))
}


test_that("un benvenuto recapitato si conta, accanto alla chiave", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]

  # eval
  detto <- mail_round(
    changed, registro, born = nascita_di_prova(finti[["parola"]]),
    mailer = raccoglitore()[["mailer"]], dry_run = FALSE
  )

  # test
  conto <- detto[["contatori"]]
  expect_equal(conto[["benvenuti_recapitati"]], 1L)
  expect_equal(conto[["benvenuti_persi"]], 0L)
  expect_equal(conto[["credenziali_recapitate"]], 1L)
  expect_equal(conto[["credenziali_perse"]], 0L)
  # Not added to the outcome messages: those have a next round, and these two
  # do not.
  expect_equal(conto[["posta_partite"]], 0L)
  expect_equal(conto[["posta_fallite"]], 0L)
  expect_equal(detto[["errori"]], character())
})


test_that("un benvenuto non recapitato ha un codice suo", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]

  # eval
  detto <- mail_round(
    changed, registro, born = nascita_di_prova(finti[["parola"]]),
    mailer = rifiuta_a("sara.esterna@example.org")[["mailer"]],
    dry_run = FALSE
  )

  # test
  # The code alone, as for the key: the transport's word is in the journal,
  # and this string reaches the telemetry record.
  conto <- detto[["contatori"]]
  expect_equal(detto[["errori"]], "POSTA_BENVENUTO_PERSO")
  expect_equal(conto[["benvenuti_persi"]], 1L)
  expect_equal(conto[["benvenuti_recapitati"]], 0L)
  expect_equal(conto[["credenziali_recapitate"]], 1L)
  expect_equal(conto[["credenziali_perse"]], 0L)
  expect_equal(conto[["posta_fallite"]], 0L)
})


test_that("un benvenuto senza destinatario e' un benvenuto perso", {
  # eval
  registro <- registro_di_prova(contact_email = "")
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  # eval
  detto <- mail_round(
    changed, registro, born = nascita_di_prova(finti[["parola"]]),
    mailer = posta[["mailer"]], dry_run = FALSE
  )

  # test
  expect_length(posta[["mandate"]](), 1L)
  expect_equal(detto[["errori"]], "POSTA_BENVENUTO_PERSO")
  expect_equal(detto[["contatori"]][["benvenuti_persi"]], 1L)
  expect_equal(detto[["contatori"]][["credenziali_recapitate"]], 1L)
})


test_that("benvenuto e chiave persi insieme si contano tutti e due", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]

  # eval
  detto <- mail_round(
    changed, registro, born = nascita_di_prova(finti[["parola"]]),
    mailer = raccoglitore(riesce = FALSE)[["mailer"]], dry_run = FALSE
  )

  # test
  conto <- detto[["contatori"]]
  expect_equal(
    detto[["errori"]], c("POSTA_BENVENUTO_PERSO", "POSTA_CREDENZIALE_PERSA")
  )
  expect_equal(conto[["benvenuti_persi"]], 1L)
  expect_equal(conto[["credenziali_perse"]], 1L)
  expect_equal(conto[["benvenuti_recapitati"]], 0L)
  expect_equal(conto[["credenziali_recapitate"]], 0L)
})


test_that("una nascita senza riga nel registro perde benvenuto e chiave", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  # eval
  detto <- mail_round(
    changed, registro,
    born = nascita_di_prova(finti[["parola"]], record_id = "99"),
    mailer = posta[["mailer"]], dry_run = FALSE
  )

  # test
  # Neither message has anybody to go to, and both are lost the same way.
  expect_length(posta[["mandate"]](), 0L)
  expect_equal(
    detto[["errori"]], c("POSTA_BENVENUTO_PERSO", "POSTA_CREDENZIALE_PERSA")
  )
  expect_equal(detto[["contatori"]][["benvenuti_persi"]], 1L)
  expect_equal(detto[["contatori"]][["credenziali_perse"]], 1L)
})


test_that("un benvenuto perso non si ritenta, e non trattiene nessuna riga", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[, colonne_cambiate, drop = FALSE]

  # eval
  detto <- mail_round(
    changed, registro, born = nascita_di_prova(finti[["parola"]]),
    mailer = rifiuta_a("sara.esterna@example.org")[["mailer"]],
    dry_run = FALSE
  )

  # test
  # The account is already born and the round does not create it twice, so
  # the next round has no occasion to send the welcome again. Holding the row
  # back would not bring it back: it would only stop the outcome being written.
  expect_equal(nrow(detto[["recapitate"]]), 1L)
  expect_equal(detto[["errori"]], "POSTA_BENVENUTO_PERSO")
  expect_equal(detto[["contatori"]][["posta_partite"]], 1L)
})


test_that("un giro che simula o non manda porta i quattro contatori a zero", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[, colonne_cambiate, drop = FALSE]

  # eval
  detto <- mail_round(
    changed, registro, born = nascita_di_prova(finti[["parola"]]),
    mailer = raccoglitore()[["mailer"]], dry_run = TRUE
  )

  # test
  for (campo in c(
    "benvenuti_recapitati", "benvenuti_persi",
    "credenziali_recapitate", "credenziali_perse"
  )) {
    expect_identical(detto[["contatori"]][[campo]], 0L)
  }
})


test_that("il dirottamento sostituisce i destinatari e lo dichiara nel corpo", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  # eval
  detto <- mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = FALSE, redirect_to = "corrado@example.org",
    copy_to = "it@example.org"
  )

  # test
  mandata <- posta[["mandate"]]()[[1L]]
  expect_equal(mandata[["to"]], "corrado@example.org")
  expect_null(mandata[["cc"]])
  expect_match(mandata[["body"]], "cinzia@ubep.unipd.it", fixed = TRUE)
  expect_true(detto[["contatori"]][["posta_dirottata"]])
})


test_that("una riga trattenuta dice quale sigillo incollare, e dove", {
  # eval
  messaggio <- mail_outcome_message(list(
    record_id = "42", outcome = "held", outcome_detail = "SIGILLO_DIVERSO",
    outcome_at = "2026-09-02 04:02", request_status = "active",
    first_name = "Mario", last_name = "Rossi",
    contact_email = "mario.rossi@example.org",
    server = "edc10", project_id = "9003", role_name = "data entry",
    username = "mario.rossi@ubep.unipd.it", applied_as = "",
    seal_now = "9f3c1a7b04de"
  ))

  # test
  # The approval is a value to paste, not a box to tick, and the only place
  # that value exists is this message: the current seal is computed, not
  # stored, so a referent who is not told it cannot approve anything. A
  # protection nobody can clear is an outage with a nicer name.
  expect_true(grepl("9f3c1a7b04de", messaggio[["body"]], fixed = TRUE))
  expect_true(grepl("approved_seal", messaggio[["body"]], fixed = TRUE))
})


test_that("solo la riga trattenuta va al creatore, le altre a requested_by", {
  # eval
  riga <- list(
    record_id = "42", requested_by = "carla.neri@ubep.unipd.it",
    creator = "anna.bianchi@ubep.unipd.it"
  )

  # test
  # The held message asks for an approval, which only the creator can give.
  # Every other outcome tells whoever the row names, as it always has: moving
  # them would change where a credential's notice goes on a question nobody
  # asked here.
  expect_equal(
    mail_outcome_recipient(c(riga, outcome = "held")),
    "anna.bianchi@ubep.unipd.it"
  )
  expect_equal(
    mail_outcome_recipient(c(riga, outcome = "applied")),
    "carla.neri@ubep.unipd.it"
  )
  expect_equal(
    mail_outcome_recipient(
      list(record_id = "42", outcome = "held", requested_by = "x@y.it")
    ),
    "x@y.it"
  )
})


test_that("gli altri esiti non parlano di sigilli", {
  # eval
  messaggio <- mail_outcome_message(list(
    record_id = "42", outcome = "applied", outcome_detail = "",
    outcome_at = "2026-09-02 04:02", request_status = "active",
    first_name = "Mario", last_name = "Rossi",
    contact_email = "mario.rossi@example.org",
    server = "edc10", project_id = "9003", role_name = "data entry",
    username = "mario.rossi@ubep.unipd.it", applied_as = "role_name=data entry",
    seal_now = "9f3c1a7b04de"
  ))

  # test
  # Instructions for a situation the reader is not in are the fastest way to
  # make the rest of the message unread.
  expect_false(grepl("approved_seal", messaggio[["body"]], fixed = TRUE))
})


test_that("il giro mette nel messaggio il sigillo che la riga vale adesso", {
  # eval
  registro <- registro_di_prova(outcome = "held")
  changed <- registro[, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = FALSE
  )
  corpo <- posta[["mandate"]]()[[1L]][["body"]]

  # test
  # The current seal is computed from the row and stored nowhere, so it exists
  # only here. `register` is the register as read, which is exactly the frame
  # the seal has to be computed from: computing it from what the round has
  # been rewriting would hand the referent a value for a row that no longer
  # matches what they are looking at.
  expect_true(grepl(request_seal(registro), corpo, fixed = TRUE))
})
