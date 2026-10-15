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


test_that("a record id used before keeps its earlier life out of the date", {
  # eval
  # The register reuses ids: one was created for a field test, deleted with
  # the rest on 2026-09-01, and created again as the first real request.
  # Asked by `record`, REDCap answers with both lives, newest first.
  vecchia_e_nuova <- rbind(
    evento("2026-10-12 06:03", canale, "applied_seal = 'bbbbbbbbbbbb'"),
    evento("2026-10-08 23:03", canale, "applied_seal = 'aaaaaaaaaaaa'"),
    evento("2026-10-08 10:00", "anna.esempio@ubep.unipd.it",
           "record_id = '41'", action = "Create record 41"),
    evento("2026-09-01 12:00", "amministratore.prova@ubep.unipd.it",
           "record_id = '41'", action = "Delete record 41"),
    evento("2026-08-15 23:03", canale, "applied_seal = 'eeeeeeeeeeee'"),
    evento("2026-08-15 10:00", "collaudo.prova@ubep.unipd.it",
           "record_id = '41'", action = "Create record 41")
  )

  # test
  # The old life's execution would date the request in August, and the
  # October one would read as a change: a new request reported as modified.
  expect_equal(
    report_executions(vecchia_e_nuova, "41"),
    c("2026-10-08 23:03", "2026-10-12 06:03")
  )
})


test_that("a new life not executed yet does not inherit the old one's date", {
  # eval
  eventi <- rbind(
    evento("2026-10-08 10:00", "anna.esempio@ubep.unipd.it",
           "record_id = '41'", action = "Create record 41"),
    evento("2026-08-15 23:03", canale, "applied_seal = 'eeeeeeeeeeee'"),
    evento("2026-08-15 10:00", "collaudo.prova@ubep.unipd.it",
           "record_id = '41'", action = "Create record 41")
  )

  # test
  expect_equal(report_executions(eventi, "41"), character())
})


test_that("another account that served the old life does not blind the new", {
  # eval
  # A field test that ran under a different token wrote the channel's fields
  # under a second account. Counted on the whole log, the date would be
  # unknown; the row that stands now was executed by one account only.
  eventi <- rbind(
    evento("2026-10-08 23:03", canale, "applied_seal = 'aaaaaaaaaaaa'"),
    evento("2026-10-08 10:00", "anna.esempio@ubep.unipd.it",
           "record_id = '41'", action = "Create record 41"),
    evento("2026-08-15 23:03", "svc-collaudo-prova",
           "applied_seal = 'eeeeeeeeeeee'"),
    evento("2026-08-15 10:00", "collaudo.prova@ubep.unipd.it",
           "record_id = '41'", action = "Create record 41")
  )

  # test
  expect_equal(report_executions(eventi, "41"), "2026-10-08 23:03")
})


test_that("the creator of a reused id is the one of the life standing now", {
  # eval
  # What the report sends a row by. `log_creators()` reads the creations
  # newest first and takes the first, which is the current life; this pins
  # it from the report's side too, since a report sent to the creator of a
  # row that no longer exists would describe somebody else's request.
  creazioni <- rbind(
    evento("2026-10-08 10:00", "anna.esempio@ubep.unipd.it",
           "record_id = '41'", action = "Create record 41"),
    evento("2026-08-15 10:00", "collaudo.prova@ubep.unipd.it",
           "record_id = '41'", action = "Create record 41")
  )

  # test
  expect_equal(log_creators(creazioni, "41"), "anna.esempio@ubep.unipd.it")
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
  # No seal by the channel, and seals by two accounts: IT looks for different
  # things in the two.
  expect_equal(righe[["data_motivo"]], c("senza_sigillo", "log_ambiguo"))
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


# --- the mails ---------------------------------------------------------------

# A referent's report as report_assemble() hands it over, built by hand so
# each test names the item it is about.
attivati_di <- function(...) {
  righe <- registro_di(...)
  righe[["attivata_il"]] <- "2026-10-08 23:03"
  righe[["nel_mese"]] <- "attivata"
  righe
}

# `progetti` is set apart from the rest: modifyList() walks into a data frame
# as into any list, and would merge the frames column by column.
persona <- function(..., progetti = data.frame(
  server = "edc10", project_id = "9301", stringsAsFactors = FALSE
)) {
  chi <- utils::modifyList(
    list(
      nome = "Carla Inventata", upn = "carla.inventata@ubep.unipd.it",
      attivata_il = "2026-09-12", giorni = 50L, mesi = 1L,
      segnalata = character()
    ),
    list(...)
  )
  chi[["progetti"]] <- progetti
  chi
}

rapporto_di <- function(attivati = attivati_di(richiesta())[0, ],
                        persone = list()) {
  list(
    referente = referente, attivati = attivati, senza_primo_accesso = persone
  )
}

parti <- function(messaggio) {
  testo <- strsplit(messaggio[["body"]], "\n", fixed = TRUE)[[1L]]
  taglio <- which(testo == "---")
  list(it = testo[seq_len(taglio - 1L)], en = testo[-seq_len(taglio)])
}


test_that("an all-clear report says so in the first word of the subject", {
  # eval
  messaggio <- report_message(
    rapporto_di(attivati_di(
      richiesta(record_id = "41", dag_name = "torino"),
      richiesta(record_id = "42", identity = "existing",
                username = "bruno.fittizio@ubep.unipd.it",
                first_name = "Bruno", last_name = "Fittizio",
                project_id = "9302", role_name = "data_entry",
                expiration = "2027-06-30")
    )),
    novembre()
  )
  testo <- parti(messaggio)

  # test
  expect_equal(messaggio[["forma"]], "in_ordine")
  expect_equal(messaggio[["n"]], 0L)
  expect_equal(
    messaggio[["subject"]],
    paste0(
      "Tutto in ordine: accessi REDCap, ottobre 2026 / ",
      "All clear: REDCap access, October 2026"
    )
  )
  # A mail of plain text, so the verdict is said again on the first line.
  expect_equal(testo[["it"]][[1L]], "TUTTO IN ORDINE")
  expect_equal(testo[["en"]][[2L]], "ALL CLEAR")
  expect_true(
    "Persone senza primo accesso dopo 30 giorni: nessuna." %in% testo[["it"]]
  )
  # Phase 1 does not look at the year without access, and an all-clear that
  # covered it would say something false.
  expect_true(
    "Persone senza accessi da piu' di un anno: non ancora controllato." %in%
      testo[["it"]]
  )
  expect_true(
    "People with no access in more than a year: not checked yet." %in%
      testo[["en"]]
  )
  expect_true(
    "Accessi attivati nel mese (2), per informazione:" %in% testo[["it"]]
  )
  expect_true(paste0(
    "- Carla Inventata, carla.inventata@ubep.unipd.it: edc10, progetto 9301, ",
    "ruolo user, DAG torino, senza scadenza. Account nuovo."
  ) %in% testo[["it"]])
  expect_true(paste0(
    "- Bruno Fittizio, bruno.fittizio@ubep.unipd.it: edc10, progetto 9302, ",
    "ruolo data_entry, scadenza 2027-06-30. Account gia' esistente."
  ) %in% testo[["it"]])
  expect_true(paste0(
    "- Bruno Fittizio, bruno.fittizio@ubep.unipd.it: edc10, project 9302, ",
    "role data_entry, last day 2027-06-30. Existing account."
  ) %in% testo[["en"]])
  expect_true(paste0(
    "Situazione letta il 2026-11-01 alle 07:30 (ora italiana). ",
    "Prossimo rapporto: 1 dicembre 2026."
  ) %in% testo[["it"]])
  expect_true(paste0(
    "State read on 2026-11-01 at 07:30 (Italian time). ",
    "Next report: 1 December 2026."
  ) %in% testo[["en"]])
})


test_that("a modified request is said to be one, and a quiet month is said", {
  # eval
  modificata <- attivati_di(richiesta(record_id = "41"))
  modificata[["nel_mese"]] <- "modificata"
  con_modifica <- parti(report_message(rapporto_di(modificata), novembre()))
  vuoto <- parti(report_message(rapporto_di(), novembre()))

  # test
  expect_true(paste0(
    "- Carla Inventata, carla.inventata@ubep.unipd.it: edc10, progetto 9301, ",
    "ruolo user, senza scadenza. Richiesta modificata e rieseguita nel mese."
  ) %in% con_modifica[["it"]])
  expect_true("Accessi attivati nel mese: nessuno." %in% vuoto[["it"]])
  expect_true("Access granted this month: none." %in% vuoto[["en"]])
})


test_that("a report to review counts the people, and puts them first", {
  # eval
  messaggio <- report_message(
    rapporto_di(
      attivati_di(richiesta(record_id = "45")),
      list(
        persona(),
        persona(
          nome = "Dario Ipotetico", upn = "dario.ipotetico@ubep.unipd.it",
          progetti = data.frame(
            server = c("edc10", "edc10", "edc12"),
            project_id = c("9301", "9302", "9303"), stringsAsFactors = FALSE
          ),
          attivata_il = "2026-08-03", giorni = 90L, mesi = 3L,
          segnalata = c("2026-09-01", "2026-10-01")
        )
      )
    ),
    novembre()
  )
  testo <- parti(messaggio)

  # test
  expect_equal(messaggio[["forma"]], "da_guardare")
  expect_equal(messaggio[["n"]], 2L)
  expect_equal(
    messaggio[["subject"]],
    paste0(
      "2 da guardare: accessi REDCap, ottobre 2026 / ",
      "2 to review: REDCap access, October 2026"
    )
  )
  expect_equal(testo[["it"]][[1L]], "2 DA GUARDARE")
  expect_equal(testo[["en"]][[2L]], "2 TO REVIEW")

  # The anomalies first, the information after.
  prima <- which(testo[["it"]] == "1. Senza primo accesso dopo 30 giorni (2)")
  dopo <- which(startsWith(testo[["it"]], "Accessi attivati nel mese"))
  expect_length(prima, 1L)
  expect_lt(prima, dopo)
  expect_true(
    "2. Senza accessi da piu' di un anno: non ancora controllato." %in%
      testo[["it"]]
  )

  expect_true(paste0(
    "   - Carla Inventata, carla.inventata@ubep.unipd.it: attivata il ",
    "2026-09-12, 50 giorni fa; senza primo accesso da 1 mese."
  ) %in% testo[["it"]])
  expect_true(
    "     edc10, progetto 9301. Prima segnalazione." %in% testo[["it"]]
  )
  expect_true(paste0(
    "   - Dario Ipotetico, dario.ipotetico@ubep.unipd.it: attivata il ",
    "2026-08-03, 90 giorni fa; senza primo accesso da 3 mesi."
  ) %in% testo[["it"]])
  expect_true(paste0(
    "     edc10, progetti 9301 e 9302; edc12, progetto 9303. ",
    "Segnalata anche il 2026-09-01 e il 2026-10-01."
  ) %in% testo[["it"]])
  expect_true(paste0(
    "     edc10, projects 9301 and 9302; edc12, project 9303. ",
    "Also reported on 2026-09-01 and 2026-10-01."
  ) %in% testo[["en"]])
  expect_true(any(startsWith(testo[["it"]], "   Che cosa fare: chiedi")))
  expect_true(any(startsWith(testo[["en"]], "   What to do: ask")))
})


test_that("the mails carry no long dash and no character outside ASCII", {
  # eval
  messaggi <- list(
    report_message(rapporto_di(attivati_di(richiesta())), novembre()),
    report_message(rapporto_di(persone = list(persona())), novembre())
  )

  # test
  for (messaggio in messaggi) {
    testo <- paste(messaggio[["subject"]], messaggio[["body"]])
    expect_false(grepl(intToUtf8(0x2014L), testo, fixed = TRUE))
    expect_true(all(utf8ToInt(testo) < 128L))
  }
})


test_that("the mail to IT says what has no referent, by section", {
  # eval
  senza_referente <- registro_di(
    richiesta(record_id = "41"),
    richiesta(record_id = "42")
  )
  senza_referente[["creator"]] <- c("", "bruno.fittizio@ubep.unipd.it")
  senza_referente[["motivo"]] <- c("non_stabilito", "disabilitato")
  per_it <- list(
    senza_referente = senza_referente,
    non_giudicabili = list(c(
      persona(nome = "Elena Supposta", upn = "elena.supposta@ubep.unipd.it"),
      list(referente = referente, motivo = "disabilitato")
    )),
    senza_data = senza_referente[0, ]
  )

  messaggio <- report_it_message(per_it, novembre())
  testo <- parti(messaggio)

  # test
  expect_equal(messaggio[["n"]], 3L)
  expect_equal(messaggio[["forma"]], "da_guardare")
  expect_equal(
    messaggio[["subject"]],
    paste0(
      "3 da guardare: rapporto REDCap per IT, ottobre 2026 / ",
      "3 to review: REDCap report for IT, October 2026"
    )
  )
  expect_equal(testo[["it"]][[1L]], "3 DA GUARDARE")
  expect_true(
    "1. Richieste senza un referente a cui mandare il rapporto (2)" %in%
      testo[["it"]]
  )
  expect_true(paste0(
    "   - Richiesta 41: Carla Inventata, carla.inventata@ubep.unipd.it: ",
    "edc10, progetto 9301. Il registro degli eventi non dice chi l'ha creata."
  ) %in% testo[["it"]])
  expect_true(paste0(
    "   - Richiesta 42: Carla Inventata, carla.inventata@ubep.unipd.it: ",
    "edc10, progetto 9301. Chi l'ha creata, bruno.fittizio@ubep.unipd.it, ",
    "ha l'account disabilitato su Entra."
  ) %in% testo[["it"]])
  expect_true(
    "2. Persone che il rapporto non sa giudicare (1)" %in% testo[["it"]]
  )
  expect_true(paste0(
    "   - Elena Supposta, elena.supposta@ubep.unipd.it: account disabilitato ",
    "su Entra. Referente: ", referente, "; edc10, progetto 9301."
  ) %in% testo[["it"]])
  # An empty section is not announced.
  expect_false(any(startsWith(testo[["it"]], "3.")))
  expect_true(all(utf8ToInt(messaggio[["body"]]) < 128L))
})


# --- the ledger of what was sent ---------------------------------------------

test_that("a month with no ledger yet has sent nothing", {
  cartella <- withr::local_tempdir()

  letto <- report_ledger_read(cartella, "2026-10")

  expect_true(letto[["ok"]])
  expect_equal(letto[["invii"]], list())
})


test_that("what is added to the ledger is read back as written", {
  # eval
  cartella <- withr::local_tempdir()
  vuoto <- report_ledger_read(cartella, "2026-10")
  primo <- report_ledger_add(cartella, "2026-10", vuoto, list(
    destinatario = referente, at = "2026-11-01 07:30",
    senza_primo_accesso = "carla.inventata@ubep.unipd.it"
  ))
  secondo <- report_ledger_add(cartella, "2026-10", primo[["ledger"]], list(
    destinatario = report_it_key(), at = "2026-11-01 07:30",
    senza_primo_accesso = character()
  ))

  letto <- report_ledger_read(cartella, "2026-10")

  # test
  expect_true(primo[["ok"]])
  expect_true(secondo[["ok"]])
  expect_equal(
    vapply(letto[["invii"]], `[[`, "", "destinatario"),
    c(referente, report_it_key())
  )
  # A single address stays a list of one, and none stays a list of none.
  expect_equal(
    letto[["invii"]][[1L]][["senza_primo_accesso"]],
    "carla.inventata@ubep.unipd.it"
  )
  expect_equal(letto[["invii"]][[2L]][["senza_primo_accesso"]], character())
  # Nothing left behind by the write.
  expect_equal(list.files(cartella), "2026-10.json")
})


test_that("a ledger that does not read stops the run from guessing", {
  # eval
  cartella <- withr::local_tempdir()
  writeLines("{ non e' json", file.path(cartella, "2026-10.json"))
  writeLines('{"mese": "2026-09", "invii": []}',
             file.path(cartella, "2026-11.json"))

  # test
  # Read as empty, it would send every report of the month a second time.
  rotto <- report_ledger_read(cartella, "2026-10")
  expect_false(rotto[["ok"]])
  expect_equal(rotto[["errors"]], "RAPPORTO_INVII_ILLEGGIBILI")
  # A file whose month is not its name's is not trusted either.
  expect_false(report_ledger_read(cartella, "2026-11")[["ok"]])
})


test_that("earlier months are read back, later ones and other files are not", {
  # eval
  cartella <- withr::local_tempdir()
  for (mese in c("2026-08", "2026-09", "2026-10")) {
    report_ledger_add(
      cartella, mese, report_ledger_read(cartella, mese),
      list(destinatario = referente,
           at = paste0(report_shift_month(mese, 1L), "-01 07:30"),
           senza_primo_accesso = character())
    )
  }
  writeLines("appunti", file.path(cartella, "note.txt"))

  precedenti <- report_ledger_previous(cartella, "2026-10")

  # test
  expect_true(precedenti[["ok"]])
  expect_equal(
    vapply(precedenti[["invii"]], `[[`, "", "at"),
    c("2026-09-01 07:30", "2026-10-01 07:30")
  )
  assente <- file.path(cartella, "no")
  expect_true(report_ledger_previous(assente, "2026-10")[["ok"]])
})


# --- one run ----------------------------------------------------------------

# The month of these tests: Anna created two requests, one for Carla in
# August, who never signed in, and one for Dario in October; a third row has
# no creation in the log. Dario signed in.
scenario <- function() {
  list(
    registro = registro_di(
      richiesta(record_id = "41"),
      richiesta(record_id = "42", username = "dario.ipotetico@ubep.unipd.it",
                first_name = "Dario", last_name = "Ipotetico",
                project_id = "9302"),
      richiesta(record_id = "43", username = "dario.ipotetico@ubep.unipd.it",
                first_name = "Dario", last_name = "Ipotetico",
                project_id = "9303")
    ),
    creazioni = rbind(
      evento("2026-10-08 10:00", referente, "", record = "42",
             action = "Create record 42"),
      evento("2026-08-03 10:00", referente, "", record = "41",
             action = "Create record 41")
    ),
    # The whole log, whatever row is asked: what an instance that ignored
    # `record` would answer.
    eventi = rbind(
      evento("2026-10-08 23:03", canale, "applied_seal = 'bbbbbbbbbbbb'",
             record = "42"),
      evento("2026-10-01 23:03", canale, "applied_seal = 'cccccccccccc'",
             record = "43"),
      evento("2026-08-03 23:03", canale, "applied_seal = 'aaaaaaaaaaaa'",
             record = "41")
    )
  )
}

# Doubles for the three readings. `letto` and `log_letto` say whether the
# register and a row's log answer; `chiamate` counts the questions asked.
doppie <- function(dati = scenario(), letto = TRUE, log_letto = TRUE,
                   rubrica = rubrica_mensile(), env = parent.frame()) {
  chiamate <- new.env()
  chiamate[["righe"]] <- character()
  guasto <- list(
    ok = FALSE, errors = "TRASPORTO_REGISTRO_NON_RAGGIUNGIBILE",
    payload = NULL
  )
  testthat::local_mocked_bindings(
    register_records = function(url, token) {
      if (!letto) {
        return(c(guasto, list(records = NULL)))
      }
      list(
        ok = TRUE, errors = character(), payload = NULL,
        records = dati[["registro"]]
      )
    },
    register_log = function(url, token, since = NULL, logtype = NULL,
                            record = NULL) {
      if (!is.null(logtype)) {
        return(list(
          ok = TRUE, errors = character(), payload = NULL,
          log = dati[["creazioni"]]
        ))
      }
      chiamate[["righe"]] <- c(chiamate[["righe"]], record)
      if (!log_letto) {
        return(c(guasto, list(log = NULL)))
      }
      list(
        ok = TRUE, errors = character(), payload = NULL,
        log = dati[["eventi"]]
      )
    },
    directory_users = function(token, base_url) {
      list(ok = TRUE, errors = character(), payload = list(), users = rubrica)
    },
    .env = env
  )
  chiamate
}

posta_finta <- function(rifiuta = character()) {
  inviate <- new.env()
  inviate[["mail"]] <- list()
  list(
    inviate = inviate,
    mailer = function(to, cc, subject, body) {
      inviate[["mail"]][[length(inviate[["mail"]]) + 1L]] <- list(
        to = to, cc = cc, subject = subject, body = body
      )
      if (to %in% rifiuta) {
        list(ok = FALSE, errors = "TRASPORTO_POSTA_RIFIUTATA")
      } else {
        list(ok = TRUE, errors = character())
      }
    }
  )
}

it_prova <- "it-prova@example.org"

esegui <- function(cartella, posta = NULL, ora = "2026-11-01 06:30", ...) {
  provisioning_report(
    register_url = "registro.example.org", register_token = "gettone",
    graph_token = "gettone", graph_url = "graph.example.org/v1.0",
    ledger_dir = cartella, now = as.POSIXct(ora, tz = "UTC"),
    mailer = posta[["mailer"]], copy_to = it_prova, ...
  )
}


test_that("the first run sends to the referent and to IT, and keeps track", {
  # eval
  doppie()
  cartella <- withr::local_tempdir()
  posta <- posta_finta()

  esito <- esegui(cartella, posta)
  record <- report_record(esito, posta = TRUE)

  # test
  mail <- posta[["inviate"]][["mail"]]
  expect_equal(vapply(mail, `[[`, "", "to"), c(referente, it_prova))
  # IT in copy on the referent's report, and nobody in copy on its own.
  expect_equal(mail[[1L]][["cc"]], it_prova)
  expect_null(mail[[2L]][["cc"]])
  expect_match(mail[[1L]][["subject"]], "^1 da guardare: accessi REDCap")
  expect_match(mail[[2L]][["subject"]], "^1 da guardare: rapporto REDCap")

  invii <- report_ledger_read(cartella, "2026-10")[["invii"]]
  expect_equal(
    vapply(invii, `[[`, "", "destinatario"), c(referente, report_it_key())
  )
  expect_equal(
    invii[[1L]][["senza_primo_accesso"]], "carla.inventata@ubep.unipd.it"
  )
  expect_equal(invii[[1L]][["at"]], "2026-11-01 07:30")

  expect_equal(record[["mese"]], "2026-10")
  expect_true(record[["giorno_di_invio"]])
  expect_equal(record[["referenti"]], 2L)
  expect_equal(record[["mandati"]], 2L)
  expect_equal(record[["gia_mandati"]], 0L)
  expect_equal(record[["falliti"]], 0L)
  expect_equal(record[["in_ordine"]], 0L)
  expect_equal(record[["da_guardare"]], 2L)
  expect_equal(record[["voci_attivati"]], 1L)
  expect_equal(record[["voci_senza_primo_accesso"]], 1L)
  expect_equal(record[["senza_creatore"]], 1L)
  expect_true(record[["mese_completo"]])
  expect_false(record[["in_ritardo"]])
  expect_equal(record[["errori"]], character())
})


test_that("the report asks the log of each active row once, and reads it", {
  # eval
  chiamate <- doppie()
  cartella <- withr::local_tempdir()

  esito <- esegui(cartella)

  # test
  expect_equal(chiamate[["righe"]], c("41", "42", "43"))
  # The double hands back the whole log on every question, and the report
  # still dated each row by its own events: Dario's October row is news,
  # Carla's August one is not.
  expect_equal(esito[["voci_attivati"]], 1L)
})


test_that("the next day sends nothing, and the month stays complete", {
  # eval
  doppie()
  cartella <- withr::local_tempdir()
  esegui(cartella, posta_finta())
  posta <- posta_finta()

  record <- report_record(
    esegui(cartella, posta, ora = "2026-11-02 06:30"), posta = TRUE
  )

  # test
  expect_length(posta[["inviate"]][["mail"]], 0L)
  expect_false(record[["giorno_di_invio"]])
  expect_equal(record[["gia_mandati"]], 2L)
  expect_equal(record[["mandati"]], 0L)
  expect_true(record[["mese_completo"]])
  expect_false(record[["in_ritardo"]])
})


test_that("with the post off the run computes and writes no ledger", {
  # eval
  doppie()
  cartella <- withr::local_tempdir()

  primo <- report_record(esegui(cartella), posta = FALSE)
  secondo <- report_record(
    esegui(cartella, ora = "2026-11-02 06:30"), posta = FALSE
  )

  # test
  expect_equal(list.files(cartella), character())
  expect_false(primo[["posta"]])
  expect_true(primo[["giorno_di_invio"]])
  expect_equal(primo[["mandati"]], 0L)
  expect_equal(primo[["falliti"]], 0L)
  expect_false(primo[["mese_completo"]])
  # Nothing went out, and from the 2nd that is a month late.
  expect_false(primo[["in_ritardo"]])
  expect_true(secondo[["in_ritardo"]])
})


test_that("a redirected run sends to the test address and keeps no ledger", {
  # eval
  doppie()
  cartella <- withr::local_tempdir()
  posta <- posta_finta()

  record <- report_record(
    esegui(cartella, posta, redirect_to = "collaudo@example.org"),
    posta = TRUE
  )

  # test
  mail <- posta[["inviate"]][["mail"]]
  expect_equal(
    vapply(mail, `[[`, "", "to"), rep("collaudo@example.org", 2L)
  )
  expect_null(mail[[1L]][["cc"]])
  expect_match(mail[[1L]][["body"]], "^\\[PROVA\\]")
  expect_match(mail[[1L]][["body"]], referente, fixed = TRUE)
  # Recorded, the real month would read as sent.
  expect_equal(list.files(cartella), character())
  expect_true(record[["posta_dirottata"]])
})


test_that("a run with a forced month leaves the real month to be sent", {
  # eval
  doppie()
  cartella <- withr::local_tempdir()
  collaudo <- posta_finta()

  # A field test at the end of October, forcing October, with the post on
  # and not even redirected.
  forzato <- report_record(
    esegui(cartella, collaudo, ora = "2026-10-20 08:00", month = "2026-10"),
    posta = TRUE
  )
  posta <- posta_finta()
  vero <- report_record(esegui(cartella, posta), posta = TRUE)

  # test
  expect_length(collaudo[["inviate"]][["mail"]], 2L)
  expect_equal(forzato[["mese"]], "2026-10")
  # A forced run speaks about another month, so it cannot say the real one is
  # late; the next run of the timer says the truth.
  expect_false(forzato[["in_ritardo"]])
  # On the 1st of November October's reports leave as if nothing had run.
  expect_length(posta[["inviate"]][["mail"]], 2L)
  expect_equal(vero[["gia_mandati"]], 0L)
  expect_equal(vero[["mandati"]], 2L)
  expect_equal(list.files(cartella), "2026-10.json")
})


test_that("a refused mail is retried the day after, and only that one", {
  # eval
  doppie()
  cartella <- withr::local_tempdir()
  primo <- report_record(
    esegui(cartella, posta_finta(rifiuta = referente)), posta = TRUE
  )
  posta <- posta_finta()
  secondo <- report_record(
    esegui(cartella, posta, ora = "2026-11-02 06:30"), posta = TRUE
  )

  # test
  expect_equal(primo[["mandati"]], 1L)
  expect_equal(primo[["falliti"]], 1L)
  expect_equal(primo[["errori"]], "TRASPORTO_POSTA_RIFIUTATA")
  expect_false(primo[["mese_completo"]])
  expect_equal(vapply(posta[["inviate"]][["mail"]], `[[`, "", "to"), referente)
  expect_equal(secondo[["gia_mandati"]], 1L)
  expect_true(secondo[["mese_completo"]])
})


test_that("an unreadable register sends nothing, and the month is not done", {
  # eval
  doppie(letto = FALSE)
  cartella <- withr::local_tempdir()
  posta <- posta_finta()

  record <- report_record(
    esegui(cartella, posta, ora = "2026-11-02 06:30"), posta = TRUE
  )

  # test
  expect_length(posta[["inviate"]][["mail"]], 0L)
  expect_false(record[["registro_letto"]])
  expect_true(record[["directory_letta"]])
  expect_equal(record[["errori"]], "TRASPORTO_REGISTRO_NON_RAGGIUNGIBILE")
  # A month nobody could count is not a complete one.
  expect_false(record[["mese_completo"]])
  expect_true(record[["in_ritardo"]])
})


test_that("no endpoint for Graph is a directory not read, said as such", {
  # eval
  doppie()
  cartella <- withr::local_tempdir()

  esito <- provisioning_report(
    register_url = "registro.example.org", register_token = "gettone",
    graph_token = "", graph_url = "", ledger_dir = cartella,
    now = as.POSIXct("2026-11-01 06:30", tz = "UTC")
  )
  record <- report_record(esito, posta = FALSE)

  # test
  expect_false(record[["directory_letta"]])
  expect_equal(record[["errori"]], "TRASPORTO_DIRECTORY_SENZA_ENDPOINT")
})


test_that("a row's log that does not answer holds the day's reports", {
  # eval
  doppie(log_letto = FALSE)
  cartella <- withr::local_tempdir()
  posta <- posta_finta()

  record <- report_record(esegui(cartella, posta), posta = TRUE)

  # test
  expect_length(posta[["inviate"]][["mail"]], 0L)
  expect_equal(record[["errori"]], "TRASPORTO_REGISTRO_NON_RAGGIUNGIBILE")
  expect_false(record[["mese_completo"]])
})


test_that("a ledger that does not read sends nothing and is left as it is", {
  # eval
  doppie()
  cartella <- withr::local_tempdir()
  writeLines("{ rotto", file.path(cartella, "2026-10.json"))
  posta <- posta_finta()

  record <- report_record(esegui(cartella, posta), posta = TRUE)

  # test
  expect_length(posta[["inviate"]][["mail"]], 0L)
  expect_equal(readLines(file.path(cartella, "2026-10.json")), "{ rotto")
  expect_true("RAPPORTO_INVII_ILLEGGIBILI" %in% record[["errori"]])
  expect_false(record[["mese_completo"]])
})


test_that("a reused record id is reported to its creator of today", {
  # eval
  # Record 41 was a field test in July, deleted and made again by Anna in
  # August. Its July execution must neither date the request nor make the
  # field-test account a referent.
  dati <- scenario()
  dati[["registro"]] <- dati[["registro"]][1L, ]
  dati[["creazioni"]] <- rbind(
    evento("2026-08-03 10:00", referente, "", record = "41",
           action = "Create record 41"),
    evento("2026-07-01 10:00", "collaudo.prova@ubep.unipd.it", "",
           record = "41", action = "Create record 41")
  )
  dati[["eventi"]] <- rbind(
    evento("2026-08-03 23:03", canale, "applied_seal = 'aaaaaaaaaaaa'"),
    evento("2026-08-03 10:00", referente, "", action = "Create record 41"),
    evento("2026-07-20 12:00", "amministratore.prova@ubep.unipd.it", "",
           action = "Delete record 41"),
    evento("2026-07-01 23:03", canale, "applied_seal = 'eeeeeeeeeeee'"),
    evento("2026-07-01 10:00", "collaudo.prova@ubep.unipd.it", "",
           action = "Create record 41")
  )
  doppie(dati)
  cartella <- withr::local_tempdir()
  posta <- posta_finta()

  esegui(cartella, posta)

  # test
  mail <- posta[["inviate"]][["mail"]]
  expect_equal(vapply(mail, `[[`, "", "to"), referente)
  expect_match(
    mail[[1L]][["body"]], "attivata il 2026-08-03, 90 giorni fa", fixed = TRUE
  )
})


# --- the record -------------------------------------------------------------

test_that("the record carries exactly the columns of its table, in order", {
  # eval
  doppie()
  record <- report_record(esegui(withr::local_tempdir()), posta = FALSE)

  # test
  # The rule on the incomplete record names these columns, and the
  # collection rule drops in silence any it does not know.
  expect_equal(names(record), c(
    "at", "mese", "giorno_di_invio", "registro_letto", "directory_letta",
    "istanze_non_lette", "posta", "posta_dirottata", "referenti", "mandati",
    "gia_mandati", "falliti", "in_ordine", "da_guardare", "voci_attivati",
    "voci_senza_primo_accesso", "voci_senza_accessi", "senza_creatore",
    "mese_completo", "in_ritardo", "errori"
  ))
  expect_equal(record[["at"]], "2026-11-01 06:30")
  # Phase 1 reads no instance and does not measure the third item.
  expect_equal(record[["istanze_non_lette"]], 0L)
  expect_equal(record[["voci_senza_accessi"]], 0L)
  # `errori` stays an array with one code, as in the round's record.
  record[["errori"]] <- "TRASPORTO_POSTA_RIFIUTATA"
  expect_match(
    run_record_json(record), '"errori":["TRASPORTO_POSTA_RIFIUTATA"]',
    fixed = TRUE
  )
})


test_that("late means from the 2nd on, with the month not complete", {
  expect_false(report_late(1L, completo = FALSE, forzato = FALSE))
  expect_true(report_late(2L, completo = FALSE, forzato = FALSE))
  expect_true(report_late(28L, completo = FALSE, forzato = FALSE))
  expect_false(report_late(2L, completo = TRUE, forzato = FALSE))
  expect_false(report_late(2L, completo = FALSE, forzato = TRUE))
})


# --- what the adversarial review found -------------------------------------

test_that("an ambiguous log is told to IT as such, not as a missing seal", {
  # eval
  dati <- scenario()
  dati[["registro"]] <- dati[["registro"]][1L, ]
  dati[["eventi"]] <- rbind(
    evento("2026-10-02 23:03", "altro.account@ubep.unipd.it",
           "applied_seal = 'ffffffffffff'"),
    evento("2026-08-03 23:03", canale, "applied_seal = 'aaaaaaaaaaaa'")
  )
  doppie(dati)
  cartella <- withr::local_tempdir()
  posta <- posta_finta()

  esegui(cartella, posta)

  # test
  mail <- posta[["inviate"]][["mail"]]
  it <- mail[[which(vapply(mail, `[[`, "", "to") == it_prova)]]
  # Two accounts wrote the seal: saying there is none sends IT to look for
  # the wrong thing.
  expect_false(grepl(
    "non porta la scrittura del sigillo", it[["body"]], fixed = TRUE
  ))
  expect_match(it[["body"]], "piu' di un account", fixed = TRUE)
  expect_match(it[["body"]], "more than one account", fixed = TRUE)
})


test_that("a referent is told how many of theirs went to IT unjudged", {
  # eval
  registro <- registro_di(
    richiesta(record_id = "41",
              username = "elena.supposta@ubep.unipd.it",
              first_name = "Elena", last_name = "Supposta"),
    richiesta(record_id = "42", username = "dario.ipotetico@ubep.unipd.it"),
    richiesta(record_id = "43", username = "franco.presunto@ubep.unipd.it")
  )
  righe <- report_rows(
    registro, rep(referente, 3L),
    list("2026-08-03 23:03", "2026-08-03 23:03", character()), novembre()
  )
  rubrica <- rubrica_mensile(
    conto(userPrincipalName = "elena.supposta@ubep.unipd.it",
          accountEnabled = FALSE)
  )

  rapporto <- report_assemble(righe, rubrica, novembre())
  messaggio <- report_message(rapporto[["referenti"]][[referente]], novembre())
  testo <- parti(messaggio)

  # test
  # Elena's account is disabled and Franco's row has no date: neither was
  # judged, and an all-clear that kept quiet about them would say too much.
  # The verdict and the number in the subject stay what was measured.
  expect_equal(rapporto[["referenti"]][[referente]][["non_giudicati"]], 2L)
  expect_match(messaggio[["subject"]], "^Tutto in ordine")
  expect_true(
    "Persone non giudicabili, segnalate a IT: 2." %in% testo[["it"]]
  )
  expect_true(
    "People that could not be judged, reported to IT: 2." %in% testo[["en"]]
  )
})


test_that("a person not judged is counted in a report to review too", {
  # eval
  messaggio <- report_message(
    c(rapporto_di(persone = list(persona())), list(non_giudicati = 1L)),
    novembre()
  )
  testo <- parti(messaggio)

  # test
  expect_match(messaggio[["subject"]], "^1 da guardare")
  expect_true(
    "   Persone non giudicabili, segnalate a IT: 1." %in% testo[["it"]]
  )
})


test_that("an account made after the activation dates the first-access item", {
  # eval
  # Activated on 3 August for one person; on 25 October the username was
  # corrected to Dario Nuovo, whose account the round created that day.
  registro <- registro_di(
    richiesta(record_id = "41", username = "dario.nuovo@ubep.unipd.it",
              first_name = "Dario", last_name = "Nuovo")
  )
  righe <- report_rows(
    registro, referente, list(c("2026-08-03 23:03", "2026-10-25 10:03")),
    novembre()
  )
  rubrica <- rubrica_mensile(
    conto(userPrincipalName = "dario.nuovo@ubep.unipd.it",
          createdDateTime = "2026-10-25T08:00:00Z",
          lastPasswordChangeDateTime = "2026-10-25T08:00:00Z")
  )

  rapporto <- report_assemble(righe, rubrica, novembre())

  # test
  # Dario has had the access for seven days.
  expect_length(
    rapporto[["referenti"]][[referente]][["senza_primo_accesso"]], 0L
  )
})


test_that("a username changed by a modification restarts the thirty days", {
  # eval
  # Newest first. Executed on 3 August for Carla; on 25 October the referent
  # wrote another username, the round resolved it and executed the row again.
  # Dario's account is old and was never used.
  eventi <- rbind(
    evento("2026-10-25 23:03", canale, "applied_seal = 'bbbbbbbbbbbb'"),
    evento("2026-10-25 23:02", canale, "identity = 'existing'"),
    evento("2026-10-25 10:00", referente,
           "username = 'dario.vecchio@ubep.unipd.it'"),
    evento("2026-08-03 23:03", canale, "applied_seal = 'aaaaaaaaaaaa'"),
    evento("2026-08-03 23:02", canale,
           "username = 'carla.inventata@ubep.unipd.it', identity = 'created'"),
    evento("2026-08-03 10:00", referente, "record_id = '41'",
           action = "Create record 41")
  )
  registro <- registro_di(
    richiesta(record_id = "41", username = "dario.vecchio@ubep.unipd.it",
              first_name = "Dario", last_name = "Vecchio")
  )
  rubrica <- rubrica_mensile(
    conto(userPrincipalName = "dario.vecchio@ubep.unipd.it",
          createdDateTime = "2024-05-01T08:00:00Z",
          lastPasswordChangeDateTime = "2024-05-01T08:00:00Z")
  )

  righe <- report_rows(
    registro, referente, list(report_executions(eventi, "41")), novembre(),
    since = list(report_person_since(eventi, "41"))
  )
  rapporto <- report_assemble(righe, rubrica, novembre())

  # test
  expect_equal(report_person_since(eventi, "41"), "2026-10-25 23:03")
  # The request is still the one activated in August, for the A item.
  expect_equal(righe[["attivata_il"]], "2026-08-03 23:03")
  expect_length(
    rapporto[["referenti"]][[referente]][["senza_primo_accesso"]], 0L
  )
})


test_that("the person's date is the first seal when the username never moved", {
  # eval
  eventi <- rbind(
    evento("2026-10-12 06:03", canale, "applied_seal = 'bbbbbbbbbbbb'"),
    evento("2026-10-11 15:20", referente, "role_name = 'data_entry'"),
    evento("2026-08-03 23:03", canale, "applied_seal = 'aaaaaaaaaaaa'"),
    evento("2026-08-03 23:02", canale,
           "username = 'carla.inventata@ubep.unipd.it'")
  )
  # A username written and not executed yet: no date for that person.
  in_attesa <- rbind(
    evento("2026-10-25 10:00", referente,
           "username = 'dario.vecchio@ubep.unipd.it'"),
    eventi
  )

  # test
  expect_equal(report_person_since(eventi, "41"), "2026-08-03 23:03")
  expect_equal(report_person_since(in_attesa, "41"), character())
})
