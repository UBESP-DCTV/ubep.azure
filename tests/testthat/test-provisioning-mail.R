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
