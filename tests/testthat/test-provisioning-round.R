state_reply <- function(..., carries_rights = TRUE) {
  rows <- list(...)
  results <- lapply(rows, function(row) {
    entry <- list(
      username = row[["username"]] %||% "mario.rossi@ubep.unipd.it",
      project_id = row[["project_id"]] %||% 9003L,
      role_name = row[["role_name"]] %||% NULL,
      dag_name = row[["dag_name"]] %||% NULL,
      expiration = row[["expiration"]] %||% NULL
    )
    if (carries_rights) {
      entry[["user_rights"]] <- row[["user_rights"]] %||% 1L
    }
    entry
  })

  list(ok = TRUE, errors = character(), payload = list(results = results))
}


entry_of <- function(...) {
  values <- list(...)
  defaults <- list(
    record_id = "1", server = "edc10", project_id = "9003",
    username = "mario.rossi@ubep.unipd.it", role_name = "data entry"
  )
  defaults[names(values)] <- values
  defaults
}


test_that("one read answers both questions the round has to ask", {
  # eval
  pairs <- round_state_pairs(
    list(entry_of(username = "mario.rossi@ubep.unipd.it")),
    data.frame(
      server = "edc10", project_id = "9003",
      username = "anna.bianchi@ubep.unipd.it", stringsAsFactors = FALSE
    )
  )

  # test
  # The grantee's row is what the diff needs; the requester's row is what the
  # gate needs. Asking for both in one call is not an optimization: it is what
  # makes the gate and the diff see the same instant of reality.
  expect_length(pairs, 2L)
  expect_equal(pairs[[1]][["username"]], "mario.rossi@ubep.unipd.it")
  expect_equal(pairs[[2]][["username"]], "anna.bianchi@ubep.unipd.it")
  expect_type(pairs[[1]][["project_id"]], "integer")
})


test_that("a pair asked for twice is asked for once", {
  # eval
  pairs <- round_state_pairs(
    list(entry_of(username = "anna.bianchi@ubep.unipd.it")),
    data.frame(
      server = "edc10", project_id = "9003",
      username = "anna.bianchi@ubep.unipd.it", stringsAsFactors = FALSE
    )
  )

  # test
  # A referent who files a request for themselves is the ordinary case, not an
  # edge one.
  expect_length(pairs, 1L)
})


test_that("a scope pair whose project_id will not parse asks quietly", {
  # eval
  # scope_pairs() (R/provisioning_scope.R) filters register rows for
  # non-emptiness only, never for numeric-ness, so a row with a malformed
  # project_id reaches `asks` even though the same row is already refused
  # elsewhere as DATO_PROGETTO_INESISTENTE by register_to_desired(). That
  # duplication is what makes the NA this produces harmless rather than
  # unnoticed, but it must stay silent: a coercion warning here would show up
  # in a cron log and in test output on every run that carries one bad row.
  asks <- data.frame(
    server = "edc10", project_id = "9003abc",
    username = "anna.bianchi@ubep.unipd.it", stringsAsFactors = FALSE
  )

  # test
  expect_no_warning(pairs <- round_state_pairs(list(), asks))
  expect_true(is.na(pairs[[1]][["project_id"]]))
})


test_that("an instance that answers without the permission has not answered", {
  # eval
  old <- round_scope_readable(state_reply(list(), carries_rights = FALSE))
  new <- round_scope_readable(state_reply(list()))
  empty <- round_scope_readable(state_reply())

  # test
  # A module too old to report the permission produced an absence of the
  # answer, not a verdict, and the gate interrogates answers and never
  # absences. Zero rows is a different thing and must not be confused with it:
  # the instance did answer, and "nothing there" is what it said — a requester
  # with no rights row is out of scope, which is a data error and belongs to
  # whoever filed the request.
  expect_false(old)
  expect_true(new)
  expect_true(empty)
})


test_that("the rights frame carries no permission column when nobody reported one", { # nolint: line_length_linter.
  # eval
  readable <- round_rights("edc10", state_reply(list(user_rights = 0L)))
  unreadable <- round_rights(
    "edc10", state_reply(list(), carries_rights = FALSE)
  )

  # test
  # scope_errors() reads an absent column as "could not be read" and refuses
  # every row. Inventing a column of NAs here would reach the same refusal by a
  # different route and would make the two cases indistinguishable upstream,
  # where they have to be told apart.
  expect_equal(readable[["user_rights"]], 0L)
  expect_equal(readable[["project_id"]], "9003")
  expect_false("user_rights" %in% names(unreadable))
})


test_that("a null permission travels as NA and never as a zero", {
  # eval
  # Built inline rather than through the helper: `%||%` would substitute the
  # default and the fixture would quietly stop carrying the null this test is
  # about. A JSON null arrives as a NULL element whose key is still there,
  # which is exactly what a role deleted underneath a row looks like.
  rights <- round_rights("edc10", list(
    ok = TRUE, errors = character(),
    payload = list(results = list(list(
      username = "mario.rossi@ubep.unipd.it",
      project_id = 9003L,
      user_rights = NULL
    )))
  ))

  # test
  # A role deleted underneath a row reads as null. Zero would mean "measured,
  # and it does not grant"; NA means "not measured", and only one of the two is
  # true.
  expect_true(is.na(rights[["user_rights"]]))
})


test_that("a real row nobody asked about never reaches the diff", {
  # eval
  results <- list(
    list(username = "mario.rossi@ubep.unipd.it", project_id = 9003L),
    list(username = "anna.bianchi@ubep.unipd.it", project_id = 9003L)
  )
  actual <- round_actual(results, list(entry_of()))

  # test
  # This is the mass-revocation trap, and it is close: the state read carries
  # the requesters' own rows, because the gate needed them. provisioning_diff()
  # classifies as `revocato` every pair present in reality and absent from the
  # desired state, so handing it the unfiltered reply would have the channel
  # propose revoking the referents. Absence means nothing (decision 5), and
  # this filter is what makes that structural rather than remembered.
  expect_length(actual, 1L)
  expect_equal(actual[[1]][["username"]], "mario.rossi@ubep.unipd.it")
})


test_that("the schema gate stops on what changes the reading and not on the rest", { # nolint: line_length_linter.
  # eval
  blocking <- round_schema_verdict(c(
    "DIZIONARIO_READONLY_CADUTO:outcome", "DIZIONARIO_CAMPO_IN_PIU:note"
  ))
  tolerated <- round_schema_verdict(c(
    "DIZIONARIO_CAMPO_IN_PIU:note", "DIZIONARIO_SCELTE_NON_CONFRONTATE:server"
  ))
  clean <- round_schema_verdict(character(0))

  # test
  # A field the round ignores cannot corrupt what it reads; a `@READONLY` that
  # fell means a requester may have typed `applied` into the outcome, and the
  # register would be carrying a success nobody produced. The instance list may
  # legitimately be missing, so the choices it could not compare are reported
  # and do not stop anything.
  expect_true(blocking[["blocks"]])
  expect_equal(blocking[["blocking"]], "DIZIONARIO_READONLY_CADUTO:outcome")
  expect_equal(blocking[["tolerated"]], "DIZIONARIO_CAMPO_IN_PIU:note")
  expect_false(tolerated[["blocks"]])
  expect_false(clean[["blocks"]])
})


test_that("a batch never spans two projects", {
  # eval
  batches <- round_batches(list(
    entry_of(record_id = "1", project_id = "9003"),
    entry_of(record_id = "2", project_id = "9004"),
    entry_of(record_id = "3", project_id = "9003"),
    entry_of(record_id = "4", server = "edc12", project_id = "9003")
  ))
  projects <- vapply(batches, function(b) b[["project_id"]], integer(1))

  # test
  # api.php refuses a write that touches more than one project, and refuses it
  # outright before touching anything: PROJECT_ID is a per-process define(), so
  # a write spanning two projects could give the log partition to only one of
  # them. A job that grouped by instance would take that refusal on its first
  # mixed batch, and the diagnosis would start from the wrong place.
  expect_length(batches, 3L)
  expect_equal(sort(projects), c(9003L, 9003L, 9004L))
  expect_equal(batches[[1]][["record_ids"]], c("1", "3"))
})


test_that("a batch sends the five fields the module reads and nothing else", {
  # eval
  batch <- round_batches(list(entry_of(dag_name = NULL)))[[1]]
  request <- batch[["requests"]][[1]]

  # test
  # The module rebuilds the request from five keys and ignores the rest, so
  # sending record_id would be harmless and would still put the register's
  # internal numbering into the instance's log. A field nobody asked for is
  # dropped rather than sent empty: an absent DAG and a DAG set to "" are not
  # the same request.
  expect_equal(
    sort(names(request)),
    c("project_id", "role_name", "username")
  )
  expect_type(request[["project_id"]], "integer")
})


test_that("the read-back reads as a sentence and says absent when nothing is there", { # nolint: line_length_linter.
  # eval
  present <- round_applied_as(list(
    role_name = "data entry", dag_name = NULL, expiration = "2027-01-01"
  ))
  gone <- round_applied_as(NULL)

  # test
  # applied_as carries what was read back, not a return code: an outcome that
  # only said "no error" would be the same thing as the four spike cases that
  # reported true while doing something else. After a revocation the read-back
  # finding nothing is the success, and it has to be sayable.
  expect_equal(
    present, "role_name=data entry; dag_name=; expiration=2027-01-01"
  )
  expect_equal(gone, "absent")
})


test_that("the prefix of the code decides who the outcome belongs to", {
  # eval
  clean_run <- round_outcome_kind(character(0), dry_run = FALSE)
  simulation <- round_outcome_kind(character(0), dry_run = TRUE)
  theirs <- round_outcome_kind("DATO_RUOLO_INESISTENTE", dry_run = FALSE)
  ours <- round_outcome_kind("INTERNO", dry_run = FALSE)
  mixed <- round_outcome_kind(
    c("DATO_RUOLO_INESISTENTE", "INTERNO"), dry_run = FALSE
  )

  # test
  # Mixed codes fail towards "ours": a transport error leaves the row in the
  # desired state and the next round retries it, while a data error closes it
  # against whoever filed it. Closing a row on a fault that is half ours is the
  # expensive direction.
  expect_equal(clean_run, "applied")
  expect_equal(simulation, "simulated")
  expect_equal(theirs, "data_error")
  expect_equal(ours, "transport_error")
  expect_equal(mixed, "transport_error")
})


test_that("an outcome that did not change is not written again", {
  # eval
  register <- data.frame(
    record_id = c("1", "2"),
    outcome = c("applied", "applied"),
    outcome_detail = c("", ""),
    outcome_at = c("2026-08-13 03:00", "2026-08-13 03:00"),
    applied_as = c("role_name=data entry; dag_name=; expiration=", ""),
    stringsAsFactors = FALSE
  )
  payload <- rbind(
    outcome_payload(
      "1", "applied", at = "2026-08-14 03:00",
      applied_as = "role_name=data entry; dag_name=; expiration="
    ),
    outcome_payload(
      "2", "transport_error",
      detail = "TRASPORTO_NON_RAGGIUNGIBILE", at = "2026-08-14 03:00"
    )
  )
  changed <- round_changed(register, payload)

  # test
  # outcome_at is deliberately outside the comparison: it changes every run by
  # construction, so including it would make every row differ and the filter
  # would filter nothing. Without the filter each quiet night rewrites every
  # row, and the alert on the outcome field becomes background noise — which
  # is the thing people stop reading.
  expect_equal(changed[["record_id"]], "2")
})


# The shape provisioning_reconcile() returns, reduced to the fields a record
# reads. Built here instead of by running a round: this is the pure layer's
# test, and a real round would drag the register and two instances into it.
esito_finto <- function(esiti = NULL,
                        fermato = FALSE,
                        scritte = 0L,
                        istanze = NULL,
                        errori = character()) {
  if (is.null(esiti)) {
    esiti <- outcome_payload("", "pending")[0, , drop = FALSE]
  }
  if (is.null(istanze)) {
    istanze <- data.frame(
      server = character(), raggiunta = logical(),
      ambito_leggibile = logical(), errori = character(),
      stringsAsFactors = FALSE
    )
  }
  list(
    at = "2026-08-14 20:40",
    fermato = fermato,
    schema = list(
      blocks = FALSE, blocking = character(), tolerated = character()
    ),
    istanze = istanze, esiti = esiti, scritte = scritte, errori = errori
  )
}


test_that("the record counts each outcome under its own name", {
  # eval
  esiti <- do.call(rbind, list(
    outcome_payload("1", "applied", at = "2026-08-14 20:40"),
    outcome_payload("2", "transport_error", at = "2026-08-14 20:40"),
    outcome_payload("3", "data_error", at = "2026-08-14 20:40"),
    outcome_payload("4", "transport_error", at = "2026-08-14 20:40"),
    outcome_payload("5", "simulated", at = "2026-08-14 20:40")
  ))

  record <- round_record(esito_finto(esiti = esiti, scritte = 5L), TRUE)

  # test
  # One counter per word of the closed vocabulary, named after the word. A
  # single "errori" total would let a night of data errors and a night of
  # transport errors look alike, and those two go to different people.
  expect_equal(record[["esiti_applied"]], 1L)
  expect_equal(record[["esiti_transport_error"]], 2L)
  expect_equal(record[["esiti_data_error"]], 1L)
  expect_equal(record[["esiti_simulated"]], 1L)
  expect_equal(record[["esiti_pending"]], 0L)
  expect_equal(record[["righe"]], 5L)
})


test_that("a halted round does not claim to have read the register", {
  # eval
  record <- round_record(
    esito_finto(fermato = TRUE, errori = "DIZIONARIO_DERIVATO"), TRUE
  )

  # test
  # The channel's analogue of `letture_riuscite`. An alarm that fired on the
  # mere existence of a record would be satisfied by a round that stopped on a
  # drifted dictionary and did nothing -- a detector the fault can meet, which
  # is the shape of defect this project has already found three times.
  expect_false(record[["registro_letto"]])
})


test_that("an empty register is still a register that was read", {
  # eval
  record <- round_record(esito_finto(), TRUE)

  # test
  # `righe = 0` with `registro_letto = TRUE` is a quiet night; `righe = 0`
  # with `registro_letto = FALSE` is "I could not ask". Collapsing the two
  # would blind the alarm to the second, which is the one that needs somebody.
  expect_true(record[["registro_letto"]])
  expect_equal(record[["righe"]], 0L)
})


test_that("the record counts the instances that did not answer", {
  # eval
  istanze <- data.frame(
    server = c("edc10", "edc12"), raggiunta = c(TRUE, FALSE),
    ambito_leggibile = c(TRUE, NA),
    errori = c(NA, "TRASPORTO_NON_RAGGIUNGIBILE"),
    stringsAsFactors = FALSE
  )

  record <- round_record(esito_finto(istanze = istanze), TRUE)

  # test
  expect_equal(record[["istanze"]], 2L)
  expect_equal(record[["irraggiungibili"]], 1L)
})


test_that("the record says whether the round was allowed to write", {
  # eval
  simulato <- round_record(esito_finto(), FALSE)
  scritto <- round_record(esito_finto(), TRUE)

  # test
  # Not cosmetic: the same counts mean different things simulated and real,
  # and a reader of the telemetry cannot tell them apart without this.
  expect_false(simulato[["scrittura"]])
  expect_true(scritto[["scrittura"]])
})


test_that("the record's list fields stay arrays when they hold one item", {
  # eval
  record <- round_record(
    esito_finto(fermato = TRUE, errori = "DIZIONARIO_DERIVATO"), TRUE
  )
  record[["schema_differenze"]] <- "server"

  json <- run_record_json(record)

  # test
  # Both columns are `dynamic`. A one-element vector that auto-unboxes to a
  # bare string makes two runs disagree on the shape of the same field, and an
  # alarm query using `array_length()` then fails on the scalar one -- quietly,
  # because a failing scalar comparison in KQL is false and not an error.
  expect_match(json, '"errori":["DIZIONARIO_DERIVATO"]', fixed = TRUE)
  expect_match(json, '"schema_differenze":["server"]', fixed = TRUE)
})


test_that("the record's fields are exactly the rule's columns", {
  # eval
  # The columns of UbepCanale_CL as created on 2026-08-14, minus
  # `TimeGenerated`, which the runner adds at emission time: sixteen here,
  # seventeen in the table.
  #
  # Written out rather than read from Azure -- the suite runs without network
  # and without credentials -- and the point is the order of operations, not
  # the connection. The ingestion API accepts a payload and drops in silence
  # every column the collection rule does not know, so a field added here
  # before the rule knows it does not fail: it arrives empty. This test is what
  # turns that silence into a red, and its message says which one moves first.
  #
  # It also pins the arithmetic that ties the record to the closed vocabulary:
  # adding a sixth outcome gives `round_record()` a sixth counter for free, and
  # that free counter is exactly the one the rule would drop.
  colonne <- c(
    "at", "registro_letto", "fermato", "scrittura", "schema_ferma",
    "schema_differenze", "istanze", "irraggiungibili", "righe", "scritte",
    "errori", "esiti_pending", "esiti_applied", "esiti_data_error",
    "esiti_transport_error", "esiti_simulated"
  )

  record <- round_record(esito_finto(), TRUE)

  # test
  expect_setequal(names(record), colonne)
  expect_length(record, length(colonne))
  expect_setequal(
    grep("^esiti_", names(record), value = TRUE),
    paste0("esiti_", outcome_vocabulary())
  )
})
