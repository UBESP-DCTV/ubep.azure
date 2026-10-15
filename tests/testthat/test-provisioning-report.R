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


test_that("the tolerance between the dates is sixty seconds, in one place", {
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


# --- which rows, and whose ---------------------------------------------------

# One register row as the round leaves it once applied. Projects above the
# fixture floor; people and addresses invented.
richiesta <- function(...) {
  utils::modifyList(
    list(
      record_id = "41", server = "edc10", project_id = "9301",
      username = "carla.inventata@ubep.unipd.it",
      first_name = "Carla", last_name = "Inventata",
      contact_email = "carla.inventata@example.org", identity = "created",
      role_name = "user", dag_name = "", expiration = "",
      requested_by = "anna.esempio@ubep.unipd.it", request_status = "active",
      outcome = "applied", outcome_detail = "",
      outcome_at = "2026-10-08 21:03", applied_as = "",
      applied_seal = "aaaaaaaaaaaa", seal_state = "intact", approved_seal = ""
    ),
    list(...)
  )
}

registro_di <- function(...) {
  do.call(rbind, lapply(list(...), as.data.frame, stringsAsFactors = FALSE))
}

novembre <- function() {
  report_month(as.POSIXct("2026-11-01 06:30", tz = "UTC"))
}

referente <- "anna.esempio@ubep.unipd.it"


test_that("only active and applied rows enter the report", {
  # eval
  registro <- registro_di(
    richiesta(record_id = "41"),
    # Revoked: the access is gone, and a revocation the round carried out
    # closes with `applied` too, so the filter is on the request.
    richiesta(record_id = "42", request_status = "revoked"),
    # Not an access, and every change of outcome already has its mail.
    richiesta(record_id = "43", outcome = "transport_error"),
    richiesta(record_id = "44", outcome = "held")
  )
  esecuzioni <- rep(list("2026-10-08 23:03"), 4L)

  righe <- report_rows(registro, rep(referente, 4L), esecuzioni, novembre())

  # test
  expect_equal(righe[["record_id"]], "41")
  expect_equal(righe[["creator"]], referente)
  expect_equal(righe[["attivata_il"]], "2026-10-08 23:03")
  expect_equal(righe[["nel_mese"]], "attivata")
})


test_that("a row is new, modified or neither, and later ones wait", {
  # eval
  registro <- registro_di(
    richiesta(record_id = "41"),
    richiesta(record_id = "42"),
    richiesta(record_id = "43"),
    richiesta(record_id = "44"),
    richiesta(record_id = "45")
  )
  esecuzioni <- list(
    # Activated on the last evening of the month, Italian time: inside.
    "2026-10-31 22:00",
    # Activated in September, executed again in October after a change.
    c("2026-09-12 23:03", "2026-10-20 07:03"),
    # Activated in September and left alone.
    "2026-09-12 23:03",
    # Activated after the month: it belongs to the next report.
    "2026-11-01 00:03",
    # Activated in September, changed in November: not this month's news.
    c("2026-09-12 23:03", "2026-11-01 00:03")
  )

  righe <- report_rows(registro, rep(referente, 5L), esecuzioni, novembre())

  # test
  expect_equal(righe[["record_id"]], c("41", "42", "43", "45"))
  expect_equal(righe[["nel_mese"]], c("attivata", "modificata", "", ""))
})


test_that("a row without a date is kept for IT, an unread one is left out", {
  # eval
  registro <- registro_di(
    richiesta(record_id = "41"),
    richiesta(record_id = "42"),
    richiesta(record_id = "43")
  )
  # `NULL` is a log the run could not read: the run sends nothing that day,
  # and the row is not judged on a reading that did not happen.
  esecuzioni <- list(character(), NA_character_, NULL)

  righe <- report_rows(registro, rep(referente, 3L), esecuzioni, novembre())

  # test
  expect_equal(righe[["record_id"]], c("41", "42"))
  expect_equal(righe[["senza_data"]], c(TRUE, TRUE))
})


# The directory of the tests below: the referent, a second referent, and the
# people they asked for.
rubrica_mensile <- function(...) {
  persone <- list(
    conto(userPrincipalName = "anna.esempio@ubep.unipd.it",
          createdDateTime = "2025-01-10T08:00:00Z",
          lastPasswordChangeDateTime = "2025-03-01T08:00:00Z"),
    conto(userPrincipalName = "bruno.fittizio@ubep.unipd.it",
          createdDateTime = "2025-01-10T08:00:00Z",
          lastPasswordChangeDateTime = "2025-03-01T08:00:00Z"),
    # Never signed in: the two dates are equal.
    conto(userPrincipalName = "carla.inventata@ubep.unipd.it",
          createdDateTime = "2026-08-03T08:00:00Z",
          lastPasswordChangeDateTime = "2026-08-03T08:00:00Z"),
    # Signed in: the key changed a week after the account was born.
    conto(userPrincipalName = "dario.ipotetico@ubep.unipd.it",
          createdDateTime = "2026-08-03T08:00:00Z",
          lastPasswordChangeDateTime = "2026-08-10T08:00:00Z")
  )
  directory_frame(c(persone, list(...)))
}


test_that("the first-access item waits thirty days on the calendar", {
  # eval
  registro <- registro_di(
    richiesta(record_id = "41", project_id = "9301"),
    richiesta(record_id = "42", project_id = "9302")
  )
  # The 2nd of October is 30 days before the 1st of November; the 3rd is 29.
  esecuzioni <- list("2026-10-02 23:03", "2026-10-03 23:03")
  righe <- report_rows(registro, rep(referente, 2L), esecuzioni, novembre())

  rapporto <- report_assemble(righe, rubrica_mensile(), novembre())
  mio <- rapporto[["referenti"]][[referente]]

  # test
  persone <- mio[["senza_primo_accesso"]]
  expect_length(persone, 1L)
  expect_equal(persone[[1L]][["upn"]], "carla.inventata@ubep.unipd.it")
  expect_equal(persone[[1L]][["progetti"]][["project_id"]], "9301")
  expect_equal(persone[[1L]][["attivata_il"]], "2026-10-02")
  expect_equal(persone[[1L]][["giorni"]], 30L)
  # Both rows were activated in October, so both are news this month.
  expect_equal(mio[["attivati"]][["record_id"]], c("41", "42"))
})


test_that("a person is one item, with every project of theirs", {
  # eval
  registro <- registro_di(
    richiesta(record_id = "41", server = "edc10", project_id = "9302"),
    richiesta(record_id = "42", server = "edc10", project_id = "9301"),
    richiesta(record_id = "43", server = "edc12", project_id = "9303"),
    richiesta(record_id = "44", username = "dario.ipotetico@ubep.unipd.it")
  )
  esecuzioni <- list(
    "2026-08-03 23:03", "2026-09-12 23:03", "2026-09-20 23:03",
    "2026-08-03 23:03"
  )
  righe <- report_rows(registro, rep(referente, 4L), esecuzioni, novembre())

  rapporto <- report_assemble(righe, rubrica_mensile(), novembre())
  persone <- rapporto[["referenti"]][[referente]][["senza_primo_accesso"]]

  # test
  # Dario signed in, so he is not there; Carla is there once.
  expect_length(persone, 1L)
  carla <- persone[[1L]]
  expect_equal(carla[["nome"]], "Carla Inventata")
  expect_equal(carla[["progetti"]][["server"]], c("edc10", "edc10", "edc12"))
  expect_equal(carla[["progetti"]][["project_id"]], c("9301", "9302", "9303"))
  # Dated by her oldest request: 90 days, three months of thirty days.
  expect_equal(carla[["attivata_il"]], "2026-08-03")
  expect_equal(carla[["giorni"]], 90L)
  expect_equal(carla[["mesi"]], 3L)
  expect_equal(carla[["segnalata"]], character())
  # None of the four was activated or changed in October.
  expect_equal(nrow(rapporto[["referenti"]][[referente]][["attivati"]]), 0L)
})


test_that("an expired access is news in its month and nothing after", {
  # eval
  registro <- registro_di(
    richiesta(record_id = "41", expiration = "2026-10-31"),
    richiesta(record_id = "42", expiration = "2026-11-01"),
    richiesta(record_id = "43", expiration = "2026-11-02",
              username = "bruno.fittizio@ubep.unipd.it")
  )
  esecuzioni <- list(
    "2026-10-01 10:00", "2026-09-01 10:00", "2026-09-01 10:00"
  )
  righe <- report_rows(registro, rep(referente, 3L), esecuzioni, novembre())

  rapporto <- report_assemble(righe, rubrica_mensile(), novembre())
  mio <- rapporto[["referenti"]][[referente]]

  # test
  # REDCap refuses on `expiration <= today`, so the 1st of November, read on
  # the 1st of November, is already over: neither Carla row is asked about,
  # and Bruno signed in long ago.
  expect_length(mio[["senza_primo_accesso"]], 0L)
  expect_equal(mio[["attivati"]][["record_id"]], "41")
})


test_that("a person asked for by two referents is in both, with each's rows", {
  # eval
  bruno <- "bruno.fittizio@ubep.unipd.it"
  registro <- registro_di(
    richiesta(record_id = "41", project_id = "9301"),
    richiesta(record_id = "42", project_id = "9302")
  )
  righe <- report_rows(
    registro, c(referente, bruno),
    list("2026-08-03 23:03", "2026-09-03 23:03"), novembre()
  )

  rapporto <- report_assemble(righe, rubrica_mensile(), novembre())

  # test
  expect_setequal(names(rapporto[["referenti"]]), c(referente, bruno))
  di <- function(chi) {
    rapporto[["referenti"]][[chi]][["senza_primo_accesso"]][[1L]]
  }
  expect_equal(di(referente)[["progetti"]][["project_id"]], "9301")
  expect_equal(di(bruno)[["progetti"]][["project_id"]], "9302")
  expect_null(rapporto[["it"]])
})


test_that("earlier reports are read back for the same referent only", {
  # eval
  registro <- registro_di(richiesta(record_id = "41"))
  righe <- report_rows(
    registro, referente, list("2026-08-03 23:03"), novembre()
  )
  precedenti <- list(
    list(destinatario = referente, at = "2026-09-01 07:31",
         senza_primo_accesso = character()),
    list(destinatario = referente, at = "2026-10-01 07:30",
         senza_primo_accesso = "Carla.Inventata@ubep.unipd.it"),
    # Somebody else's report about the same person is somebody else's.
    list(destinatario = "bruno.fittizio@ubep.unipd.it",
         at = "2026-10-02 07:30",
         senza_primo_accesso = "carla.inventata@ubep.unipd.it")
  )

  rapporto <- report_assemble(righe, rubrica_mensile(), novembre(), precedenti)

  # test
  carla <- rapporto[["referenti"]][[referente]][["senza_primo_accesso"]][[1L]]
  expect_equal(carla[["segnalata"]], "2026-10-01")
})


test_that("rows with nobody to send them to go to IT, with the reason", {
  # eval
  sconosciuto <- "chi.non.esiste@ubep.unipd.it"
  spento <- "bruno.fittizio@ubep.unipd.it"
  registro <- registro_di(
    richiesta(record_id = "41"),
    richiesta(record_id = "42"),
    richiesta(record_id = "43")
  )
  righe <- report_rows(
    registro, c("", spento, sconosciuto),
    rep(list("2026-10-08 23:03"), 3L), novembre()
  )
  rubrica <- rubrica_mensile()
  rubrica[["accountEnabled"]][
    rubrica[["userPrincipalName"]] == spento
  ] <- FALSE

  rapporto <- report_assemble(righe, rubrica, novembre())

  # test
  # A creator the log does not name, one whose account is disabled, one the
  # directory does not hold: none receives anything, and IT gets the rows.
  expect_length(rapporto[["referenti"]], 0L)
  fuori <- rapporto[["it"]][["senza_referente"]]
  expect_equal(fuori[["record_id"]], c("41", "42", "43"))
  expect_equal(
    fuori[["motivo"]], c("non_stabilito", "disabilitato", "non_trovato")
  )
  expect_equal(rapporto[["senza_creatore"]], 3L)
})


test_that("a person the report cannot judge goes to IT, not to the referent", {
  # eval
  registro <- registro_di(
    richiesta(record_id = "41",
              username = "elena.supposta@ubep.unipd.it",
              first_name = "Elena", last_name = "Supposta"),
    richiesta(record_id = "42",
              username = "franco.presunto@ubep.unipd.it",
              first_name = "Franco", last_name = "Presunto"),
    richiesta(record_id = "43",
              username = "gina.immaginaria@ubep.unipd.it",
              first_name = "Gina", last_name = "Immaginaria"),
    # Not old enough to be judged: no item anywhere.
    richiesta(record_id = "44",
              username = "elena.supposta@ubep.unipd.it",
              first_name = "Elena", last_name = "Supposta")
  )
  righe <- report_rows(
    registro, rep(referente, 4L),
    list("2026-08-03 23:03", "2026-08-03 23:03", "2026-08-03 23:03",
         "2026-10-20 23:03"),
    novembre()
  )
  rubrica <- rubrica_mensile(
    conto(userPrincipalName = "elena.supposta@ubep.unipd.it",
          accountEnabled = FALSE),
    conto(userPrincipalName = "franco.presunto@ubep.unipd.it",
          createdDateTime = NULL)
  )

  rapporto <- report_assemble(righe, rubrica, novembre())

  # test
  mio <- rapporto[["referenti"]][[referente]]
  expect_length(mio[["senza_primo_accesso"]], 0L)
  persone <- rapporto[["it"]][["non_giudicabili"]]
  expect_equal(
    vapply(persone, `[[`, "", "upn"),
    c(
      "elena.supposta@ubep.unipd.it", "franco.presunto@ubep.unipd.it",
      "gina.immaginaria@ubep.unipd.it"
    )
  )
  expect_equal(
    vapply(persone, `[[`, "", "motivo"),
    c("disabilitato", "senza_creazione", "non_trovato")
  )
  expect_equal(vapply(persone, `[[`, "", "referente"), rep(referente, 3L))
  # The referent still gets a report: they have active requests.
  expect_equal(mio[["attivati"]][["record_id"]], "44")
  expect_equal(rapporto[["senza_creatore"]], 0L)
})


test_that("a row the log does not date goes to IT whoever created it", {
  # eval
  registro <- registro_di(
    richiesta(record_id = "41"),
    richiesta(record_id = "42")
  )
  righe <- report_rows(
    registro, c(referente, referente),
    list(character(), "2026-09-08 23:03"), novembre()
  )

  rapporto <- report_assemble(righe, rubrica_mensile(), novembre())

  # test
  expect_equal(rapporto[["it"]][["senza_data"]][["record_id"]], "41")
  # The other row still makes Anna a referent with a report due.
  expect_named(rapporto[["referenti"]], referente)
})


test_that("a referent with only old, quiet requests still has a report", {
  # eval
  registro <- registro_di(
    richiesta(record_id = "41", username = "dario.ipotetico@ubep.unipd.it")
  )
  righe <- report_rows(
    registro, referente, list("2026-08-03 23:03"), novembre()
  )

  rapporto <- report_assemble(righe, rubrica_mensile(), novembre())

  # test
  # Decided on 2026-10-15: whoever has an active and applied request gets the
  # report, and an all-clear is a report too.
  mio <- rapporto[["referenti"]][[referente]]
  expect_equal(nrow(mio[["attivati"]]), 0L)
  expect_length(mio[["senza_primo_accesso"]], 0L)
})
