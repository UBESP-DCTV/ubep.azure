# The monthly report to the referents. Every person, address and project in
# this file is invented; projects live above the fixture floor, like the rest
# of the suite.

# One event of a row's log, newest first in the frame as REDCap answers.
evento <- function(timestamp, username, details, record = "41",
                   action = "Update record") {
  data.frame(
    timestamp = timestamp, username = username, action = action,
    details = details, record = record, stringsAsFactors = FALSE
  )
}

canale <- "svc-canale-prova"


# --- the month ---------------------------------------------------------------

test_that("the report of the first of the month covers the month before", {
  # eval
  periodo <- report_month(as.POSIXct("2026-11-01 06:30", tz = "UTC"))

  # test
  expect_equal(periodo[["mese"]], "2026-10")
  expect_false(periodo[["forzato"]])
  expect_equal(periodo[["giorno"]], 1L)
  # 06:30 UTC is 07:30 in Rome in November: the hour the mail says it read
  # the state at is the one a person in Padova reads on the clock.
  expect_equal(periodo[["letto"]], "2026-11-01 07:30")
  expect_equal(periodo[["oggi"]], as.Date("2026-11-01"))
  expect_equal(periodo[["prossimo"]], as.Date("2026-12-01"))
})


test_that("the month turns at midnight in Rome, not at midnight UTC", {
  # eval
  # 23:30 UTC on 31 October is already half past midnight on 1 November in
  # Rome. Cut in UTC, this run would still be in October and would cover
  # September.
  periodo <- report_month(as.POSIXct("2026-10-31 23:30", tz = "UTC"))

  # test
  expect_equal(periodo[["mese"]], "2026-10")
  expect_equal(periodo[["giorno"]], 1L)
})


test_that("January's report covers December of the year before", {
  # eval
  periodo <- report_month(as.POSIXct("2027-01-01 06:30", tz = "UTC"))

  # test
  expect_equal(periodo[["mese"]], "2026-12")
  expect_equal(periodo[["prossimo"]], as.Date("2027-02-01"))
})


test_that("a forced month replaces the one the clock gives, and says so", {
  # eval
  periodo <- report_month(
    as.POSIXct("2026-10-20 08:00", tz = "UTC"), forced = "2026-10"
  )

  # test
  expect_equal(periodo[["mese"]], "2026-10")
  expect_true(periodo[["forzato"]])
  # The day stays the real one: it is what lateness is judged on.
  expect_equal(periodo[["giorno"]], 20L)
  expect_equal(periodo[["prossimo"]], as.Date("2026-12-01"))
})


test_that("a forced month that is not a month stops the run", {
  ora <- as.POSIXct("2026-10-20 08:00", tz = "UTC")

  expect_error(report_month(ora, forced = "2026-13"), "AAAA-MM")
  expect_error(report_month(ora, forced = "ottobre"), "AAAA-MM")
  expect_error(report_month(ora, forced = "2026-1"), "AAAA-MM")
})


test_that("a month is said in both languages without asking the locale", {
  expect_equal(
    report_month_words("2026-10"),
    c(it = "ottobre 2026", en = "October 2026")
  )
  expect_equal(
    report_day_words(as.Date("2026-12-01")),
    c(it = "1 dicembre 2026", en = "1 December 2026")
  )
})


# --- when a request was activated -------------------------------------------

test_that("activation is the channel's first seal, not the last outcome", {
  # eval
  # Newest first, as REDCap answers. The row was applied on the 8th, modified
  # by its creator on the 11th and applied again on the 12th: `outcome_at`
  # would say the 12th, and the request would look activated twice.
  eventi <- rbind(
    evento("2026-10-12 06:03", canale,
           "outcome = 'applied', applied_seal = 'bbbbbbbbbbbb'"),
    evento("2026-10-11 15:20", "anna.esempio@ubep.unipd.it",
           "role_name = 'data_entry'"),
    evento("2026-10-08 23:03", canale, paste0(
      "outcome = 'applied', applied_seal = 'aaaaaaaaaaaa', ",
      "seal_state = 'intact'"
    )),
    evento("2026-10-08 10:00", "anna.esempio@ubep.unipd.it",
           "record_id = '41', role_name = 'user'", action = "Create record 41")
  )

  # test
  expect_equal(
    report_executions(eventi, "41"),
    c("2026-10-08 23:03", "2026-10-12 06:03")
  )
})


test_that("events of other records are dropped here, whatever REDCap sent", {
  # eval
  # Whether `exportLogging` honors `record` is measured only with the 0.19.0
  # in service. If it does not, the answer is the whole log, and another
  # row's execution must not date this one.
  eventi <- rbind(
    evento("2026-10-09 06:03", canale,
           "applied_seal = 'cccccccccccc'", record = "42"),
    evento("2026-10-08 23:03", canale,
           "applied_seal = 'aaaaaaaaaaaa'", record = "41"),
    evento("2026-09-30 23:03", canale,
           "applied_seal = 'dddddddddddd'", record = "42")
  )

  # test
  expect_equal(report_executions(eventi, "41"), "2026-10-08 23:03")
})


test_that("a log with no seal by the channel has no activation", {
  # eval
  eventi <- rbind(
    evento("2026-10-08 23:03", canale, "outcome = 'transport_error'"),
    # A seal blanked is not an execution: the round seals what it applied,
    # and an empty value applied nothing.
    evento("2026-10-07 23:03", canale, "applied_seal = ''")
  )

  # test
  expect_equal(report_executions(eventi, "41"), character())
  expect_equal(report_executions(eventi[0, ], "41"), character())
})


test_that("two accounts writing the channel's fields leave the date unknown", {
  # eval
  # Only the channel writes `applied_seal`; a second account doing it is
  # nothing anybody planned, and which of the two executed the row is not a
  # question the log can answer.
  eventi <- rbind(
    evento("2026-10-09 06:03", "qualcun.altro@ubep.unipd.it",
           "applied_seal = 'cccccccccccc'"),
    evento("2026-10-08 23:03", canale, "applied_seal = 'aaaaaaaaaaaa'")
  )

  # test
  expect_identical(report_executions(eventi, "41"), NA_character_)
})


# --- the first sign-in, from Entra ------------------------------------------

# One directory account in the shape the sweep hands back, built through the
# same function, so the report is tested against the frame that arrives.
conto <- function(...) {
  utils::modifyList(
    list(
      id = "00000000-0000-0000-0000-000000000001",
      userPrincipalName = "carla.inventata@ubep.unipd.it",
      givenName = "Carla", surname = "Inventata",
      createdDateTime = "2026-09-12T08:00:00Z",
      lastPasswordChangeDateTime = "2026-09-12T08:00:00Z",
      accountEnabled = TRUE, userType = "Member"
    ),
    list(...)
  )
}

rubrica <- function(...) {
  directory_frame(list(...))
}


test_that("the tolerance between the two dates is sixty seconds, in one place", {
  expect_equal(report_tolerance(), 60)
  expect_equal(report_grace_days(), 30L)
})


test_that("equal dates mean nobody has signed in, within the tolerance", {
  # eval
  uguali <- rubrica(conto())
  vicine <- rubrica(conto(lastPasswordChangeDateTime = "2026-09-12T08:01:00Z"))
  lontane <- rubrica(conto(lastPasswordChangeDateTime = "2026-09-12T08:01:01Z"))

  # test
  expect_equal(
    report_first_access(uguali, "carla.inventata@ubep.unipd.it"),
    "mai_entrata"
  )
  # Sixty seconds is inside; sixty-one is a key that changed.
  expect_equal(
    report_first_access(vicine, "carla.inventata@ubep.unipd.it"),
    "mai_entrata"
  )
  expect_equal(
    report_first_access(lontane, "carla.inventata@ubep.unipd.it"),
    "entrata"
  )
})


test_that("the tolerance is read from the constant, not written twice", {
  # eval
  lontane <- rubrica(conto(lastPasswordChangeDateTime = "2026-09-12T08:05:00Z"))

  # test
  expect_equal(
    report_first_access(
      lontane, "carla.inventata@ubep.unipd.it", tolerance = 600
    ),
    "mai_entrata"
  )
})


test_that("the account is found whatever the case of the name", {
  expect_equal(
    report_first_access(rubrica(conto()), " Carla.Inventata@UBEP.unipd.it "),
    "mai_entrata"
  )
})


test_that("an account that cannot sign in or cannot be judged says why", {
  # eval
  disabilitato <- rubrica(conto(accountEnabled = FALSE))
  senza_stato <- rubrica(conto(accountEnabled = NULL))
  senza_nascita <- rubrica(conto(createdDateTime = NULL))
  senza_chiave <- rubrica(conto(lastPasswordChangeDateTime = NULL))
  upn <- "carla.inventata@ubep.unipd.it"

  # test
  # Disabled: it cannot make a first sign-in, and the referent is not the one
  # to ask why. It goes to IT, like the three that cannot be judged.
  expect_equal(report_first_access(disabilitato, upn), "disabilitato")
  expect_equal(report_first_access(senza_stato, upn), "non_giudicabile")
  # Null for some accounts created before June 2018, says Learn.
  expect_equal(report_first_access(senza_nascita, upn), "senza_creazione")
  expect_equal(report_first_access(senza_chiave, upn), "non_giudicabile")
  expect_equal(
    report_first_access(rubrica(conto()), "nessuno@ubep.unipd.it"),
    "non_trovato"
  )
  expect_equal(report_first_access(rubrica(conto()), ""), "non_trovato")
})
