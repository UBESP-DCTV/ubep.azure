test_that("compose_upn normalizes names into an identity", {
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
    project_id = 9003L,
    role_name = "data entry",
    dag_name = "centro-01",
    expiration = as.character(redcap_today() + 30L)
  )

  # test
  expect_equal(validate_request(request), character())
})


test_that("validate_request reports data errors by code", {
  # eval
  no_upn <- validate_request(list(username = "not-an-upn", project_id = 9003L))
  no_project <- validate_request(
    list(username = "mario.rossi@ubep.unipd.it", project_id = "abc")
  )
  past <- validate_request(list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 9003L,
    expiration = "1999-01-01"
  ))
  malformed <- validate_request(list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 9003L,
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
  # below: relative to redcap_today() so the fixture never expires.
  last_day <- redcap_today() + 30L
  taken <- intake_request(list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 9003L,
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
    username = "mario.rossi@ubep.unipd.it", project_id = 9003L
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
    project_id = 9003L,
    expiration = as.character(redcap_today())
  ))
  yesterday <- intake_request(list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 9003L,
    expiration = as.character(redcap_today() - 1)
  ))

  # test
  # This reverses the phase one rule, and it is a unit correction rather than a
  # loosening: a last day of access of today becomes a REDCap value of tomorrow,
  # so today's access exists. Yesterday is still past.
  expect_equal(today[["errors"]], character())
  expect_equal(
    today[["request"]][["expiration"]], as.character(redcap_today() + 1)
  )
  expect_true("DATO_SCADENZA_NON_VALIDA" %in% yesterday[["errors"]])
})


test_that("the last day of a request is judged on REDCap's date, the one in Rome", { # nolint: line_length_linter.
  # eval
  # Accepted while the machine is still on the day before, the request would
  # be written with an expiration REDCap has already reached, and the mail
  # would say the access was granted. Dates far from any real today.
  local_mocked_bindings(redcap_today = function(now = Sys.time()) {
    as.Date("2099-01-02")
  })
  ask <- function(last_day) {
    validate_request(list(
      username = "mario.rossi@ubep.unipd.it",
      project_id = 9003L,
      expiration = last_day
    ))
  }

  # test
  expect_true("DATO_SCADENZA_NON_VALIDA" %in% ask("2099-01-01"))
  expect_equal(ask("2099-01-02"), character())
})


test_that("REDCap's date is the one in Rome, a day ahead of UTC late in the evening", { # nolint: line_length_linter.
  # eval
  utc <- function(at) as.POSIXct(at, tz = "UTC")

  # test
  # Winter: Rome is UTC+1, so the date moves at 23:00 UTC.
  expect_equal(redcap_today(utc("2026-11-24 12:00")), as.Date("2026-11-24"))
  expect_equal(redcap_today(utc("2026-11-24 22:30")), as.Date("2026-11-24"))
  expect_equal(redcap_today(utc("2026-11-24 23:30")), as.Date("2026-11-25"))
  # Summer: UTC+2, at 22:00 UTC.
  expect_equal(redcap_today(utc("2026-06-30 21:30")), as.Date("2026-06-30"))
  expect_equal(redcap_today(utc("2026-06-30 22:30")), as.Date("2026-07-01"))
  # The same instant read from another zone is the same date.
  expect_equal(
    redcap_today(as.POSIXct("2026-11-24 18:30", tz = "America/New_York")),
    as.Date("2026-11-25")
  )
})


test_that("a request already carried out keeps a last day that has passed", {
  # eval
  request <- list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 9003L,
    expiration = as.character(redcap_today() - 1L)
  )
  carried <- intake_request(request, executed = TRUE)

  # test
  # The last day was valid when the round carried the request out, and the
  # request has not changed since: its passing is the expiration doing its
  # job, not a mistake to send back. The conversion still happens, so the
  # round compares the instance with the value REDCap stores.
  expect_equal(validate_request(request, executed = TRUE), character())
  expect_equal(carried[["errors"]], character())
  expect_equal(
    carried[["request"]][["expiration"]], as.character(redcap_today())
  )
})


test_that("a request carried out still refuses a last day that is not a date", {
  # eval
  malformed <- validate_request(
    list(
      username = "mario.rossi@ubep.unipd.it",
      project_id = 9003L,
      expiration = "31/12/2026"
    ),
    executed = TRUE
  )

  # test
  expect_equal(malformed, "DATO_SCADENZA_NON_VALIDA")
})


test_that("without the flag a last day that has passed is refused as before", {
  # eval
  request <- list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 9003L,
    expiration = as.character(redcap_today() - 1L)
  )

  # test
  expect_equal(validate_request(request), "DATO_SCADENZA_NON_VALIDA")
  expect_equal(
    intake_request(request)[["errors"]], "DATO_SCADENZA_NON_VALIDA"
  )
})
