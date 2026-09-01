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


test_that("nessun altro messaggio puo' nominare la chiave d'ingresso", {
  # eval
  riga <- riga_di_prova()
  altri <- list(
    mail_outcome_message(riga)[["body"]],
    mail_welcome_message(riga, upn = "sara@ubep.unipd.it")[["body"]]
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
