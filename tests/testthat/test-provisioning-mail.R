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
