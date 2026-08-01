test_that("compose_upn normalises names into an identity", {
  # eval
  plain <- compose_upn("Mario", "Rossi")
  accented <- compose_upn("Niccolò", "Dall'Acqua")
  spaced <- compose_upn("  Anna   Maria ", "De  Luca")

  # test
  expect_equal(plain, "mario.rossi@ubep.unipd.it")
  expect_equal(accented, "niccolo.dallacqua@ubep.unipd.it")
  expect_equal(spaced, "anna.maria.de.luca@ubep.unipd.it")
  expect_equal(
    compose_upn("Mario", "Rossi", domain = "example.org"),
    "mario.rossi@example.org"
  )
})


test_that("validate_request accepts a complete request", {
  # eval
  request <- list(
    username = "mario.rossi@ubep.unipd.it",
    contact_email = "mario.rossi@example.org",
    project_id = 27L,
    role_name = "data entry",
    dag_name = "centro-01",
    expiration = "2026-12-31"
  )

  # test
  expect_equal(validate_request(request), character())
})


test_that("validate_request reports data errors by code", {
  # eval
  no_upn <- validate_request(list(username = "not-an-upn", project_id = 27L))
  no_project <- validate_request(
    list(username = "mario.rossi@ubep.unipd.it", project_id = "abc")
  )
  past <- validate_request(list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 27L,
    expiration = "1999-01-01"
  ))
  malformed <- validate_request(list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 27L,
    expiration = "31/12/2026"
  ))

  # test
  expect_true("DATO_UTENTE_NON_VALIDO" %in% no_upn)
  expect_true("DATO_PROGETTO_INESISTENTE" %in% no_project)
  expect_true("DATO_SCADENZA_NON_VALIDA" %in% past)
  expect_true("DATO_SCADENZA_NON_VALIDA" %in% malformed)
})


test_that("validate_request only ever returns data codes", {
  # eval
  every_error <- validate_request(list(
    username = "not-an-upn",
    project_id = "abc",
    expiration = "31/12/2026"
  ))

  # test
  # This layer is pure: it cannot know whether a server is reachable or which
  # version it runs, so a transport code from here would be a guess. The split
  # is by recipient, and everything decidable here belongs to the requester.
  expect_length(every_error, 3L)
  expect_true(all(grepl("^DATO_", every_error)))
})


test_that("intake_request converts the expiration to the REDCap value", {
  # eval
  # A plain future date, away from the today/yesterday boundary covered
  # below: relative to Sys.Date() so the fixture never expires.
  last_day <- Sys.Date() + 30L
  taken <- intake_request(list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 27L,
    role_name = "data entry",
    expiration = as.character(last_day)
  ))

  # test
  # The request says the last day of access; REDCap denies from the day it
  # holds, so the value written is the day after.
  expect_equal(taken[["errors"]], character())
  expect_equal(
    taken[["request"]][["expiration"]],
    as.character(last_day + 1L)
  )
})


test_that("a request without an expiration keeps none", {
  # eval
  taken <- intake_request(list(
    username = "mario.rossi@ubep.unipd.it", project_id = 27L
  ))

  # test
  expect_equal(taken[["errors"]], character())
  expect_null(taken[["request"]][["expiration"]])
})


test_that("an invalid request yields errors and no request at all", {
  # eval
  taken <- intake_request(list(username = "not-an-upn", project_id = "abc"))

  # test
  # There is no door that returns an unconverted request: a caller cannot get
  # the validation without the conversion, so the conversion cannot be skipped.
  expect_true("DATO_UTENTE_NON_VALIDO" %in% taken[["errors"]])
  expect_null(taken[["request"]])
})


test_that("today is a valid last day of access", {
  # eval
  today <- intake_request(list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 27L,
    expiration = as.character(Sys.Date())
  ))
  yesterday <- intake_request(list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 27L,
    expiration = as.character(Sys.Date() - 1)
  ))

  # test
  # This reverses the phase one rule, and it is a unit correction rather than a
  # loosening: a last day of access of today becomes a REDCap value of tomorrow,
  # so today's access exists. Yesterday is still past.
  expect_equal(today[["errors"]], character())
  expect_equal(today[["request"]][["expiration"]], as.character(Sys.Date() + 1))
  expect_true("DATO_SCADENZA_NON_VALIDA" %in% yesterday[["errors"]])
})
