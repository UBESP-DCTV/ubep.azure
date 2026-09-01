register_row <- function(...) {
  defaults <- list(
    record_id = "1",
    server = "edc10",
    project_id = "9003",
    username = "mario.rossi@ubep.unipd.it",
    first_name = "Mario",
    last_name = "Rossi",
    contact_email = "mario.rossi@example.org",
    role_name = "data entry",
    dag_name = "centro-01",
    # Not a literal date. `validate_request()` refuses a last day in the past,
    # so a hard-coded one turns the whole file red on a calendar day, for a
    # reason that has nothing to do with the code. A test must go red when the
    # thing it watches breaks, and at no other time.
    expiration = as.character(Sys.Date() + 30L),
    requested_by = "anna.bianchi@ubep.unipd.it",
    request_status = "active"
  )
  overrides <- list(...)
  defaults[names(overrides)] <- overrides
  as.data.frame(defaults, stringsAsFactors = FALSE)
}


test_that("request_from_row keeps the field names the pure layer speaks", {
  # eval
  request <- request_from_row(register_row())

  # test
  expect_equal(request[["username"]], "mario.rossi@ubep.unipd.it")
  expect_equal(request[["project_id"]], "9003")
  expect_equal(request[["role_name"]], "data entry")
  expect_equal(request[["dag_name"]], "centro-01")
  expect_equal(request[["contact_email"]], "mario.rossi@example.org")
  expect_equal(request[["server"]], "edc10")
})


test_that("request_from_row drops what is blank, never keeps an empty string", {
  # eval
  no_dag <- request_from_row(register_row(dag_name = ""))
  no_expiry <- request_from_row(register_row(expiration = NA_character_))
  padded <- request_from_row(register_row(role_name = "  data entry  "))

  # test
  # A dropped field and an empty string are not the same thing downstream:
  # provisioning_diff() reads an absent field as "not set", while "" would be a
  # value nobody asked for — and a DAG nobody asked for is an update, never a
  # noop.
  expect_null(no_dag[["dag_name"]])
  expect_false("dag_name" %in% names(no_dag))
  expect_null(no_expiry[["expiration"]])
  expect_equal(padded[["role_name"]], "data entry")
})


test_that("request_from_row carries no field the register does not send", {
  # eval
  request <- request_from_row(register_row())

  # test
  expect_setequal(
    names(request),
    c(
      "server", "username", "project_id", "role_name", "dag_name",
      "expiration", "contact_email"
    )
  )
})


test_that("register_to_desired splits by requested state", {
  # eval
  register <- rbind(
    register_row(record_id = "1"),
    register_row(
      record_id = "2", project_id = "9004", request_status = "revoked"
    )
  )
  split <- register_to_desired(register)

  # test
  expect_length(split[["desired"]], 1L)
  expect_length(split[["revoked"]], 1L)
  expect_equal(split[["desired"]][[1]][["record_id"]], "1")
  expect_equal(split[["revoked"]][[1]][["record_id"]], "2")
  expect_length(split[["errors"]], 0L)
})


test_that("a row without a username is not a pair, nor an error", {
  # eval
  register <- rbind(
    register_row(record_id = "1"),
    register_row(record_id = "2", username = "")
  )
  split <- register_to_desired(register)

  # test
  # The key is incomplete, so the row is not yet a pair: it stays out of the
  # desired state without any special case, which is the whole point of keying
  # on the username. It is waiting for the identity layer, not misfiled.
  expect_length(split[["desired"]], 1L)
  expect_length(split[["errors"]], 0L)
})


test_that("the oldest row of a repeated pair keeps its mandate", {
  # eval
  register <- rbind(
    register_row(record_id = "1", role_name = "data entry"),
    register_row(record_id = "2", role_name = "read only")
  )
  split <- register_to_desired(register)

  # test
  # The register still refuses to guess, but the guess it refused to make was
  # never between two equals: the first row is the one that may already hold a
  # granted access, and the second is the one that disobeyed "change the
  # existing request, do not file a second one". Failing closed on both put the
  # older row's access beyond reach of a revocation, which is the one thing a
  # register of mandates must never do.
  expect_length(split[["desired"]], 1L)
  expect_equal(split[["desired"]][[1]][["record_id"]], "1")
  expect_setequal(names(split[["errors"]]), "2")
  expect_equal(split[["errors"]][["2"]], "DATO_COPPIA_DUPLICATA")
})


test_that("a revocation is not blocked by a request filed after it", {
  # eval
  register <- rbind(
    register_row(record_id = "1", request_status = "revoked"),
    register_row(record_id = "2")
  )
  split <- register_to_desired(register)

  # test
  # The case the old rule got wrong, and the reason this one exists: an access
  # granted by row 1 could not be taken away once row 2 existed, because a
  # marked row never reaches the plan at all. Absence of a mandate with the
  # right still standing is the failure this whole register is built against.
  expect_length(split[["revoked"]], 1L)
  expect_equal(split[["revoked"]][[1]][["record_id"]], "1")
  expect_length(split[["desired"]], 0L)
  expect_equal(split[["errors"]][["2"]], "DATO_COPPIA_DUPLICATA")
})


test_that("one pair never lands in both desired and revoked", {
  # eval
  # Two rows, same pair, disagreeing about what should happen to it. This is
  # the combination that made `request_status` in the key unsafe: the round
  # builds its apply batches before its revoke batches and reads the real
  # state before either, so a pair in both lists is granted and then removed
  # in the same pass, silently, every four hours.
  register <- rbind(
    register_row(record_id = "1"),
    register_row(record_id = "2", request_status = "revoked")
  )
  split <- register_to_desired(register)

  # test
  key <- function(e) paste(e[["server"]], e[["project_id"]], e[["username"]])
  expect_length(
    intersect(
      vapply(split[["desired"]], key, character(1)),
      vapply(split[["revoked"]], key, character(1))
    ),
    0L
  )
})


test_that("age is the record id, not the order the rows arrive in", {
  # eval
  # The API does not promise an order, and a register read newest-first would
  # otherwise reverse who keeps the mandate.
  register <- rbind(
    register_row(record_id = "2", role_name = "read only"),
    register_row(record_id = "1", role_name = "data entry")
  )
  split <- register_to_desired(register)

  # test
  expect_length(split[["desired"]], 1L)
  expect_equal(split[["desired"]][[1]][["record_id"]], "1")
  expect_setequal(names(split[["errors"]]), "2")
})


test_that("record ids that are not numbers still order deterministically", {
  # eval
  # Auto-numbering makes them integers today, and nothing in the contract says
  # they must stay that way. A non-numeric id must not crash the comparison
  # nor make the winner depend on the read order.
  register <- rbind(
    register_row(record_id = "b"),
    register_row(record_id = "a")
  )
  split <- register_to_desired(register)

  # test
  expect_length(split[["desired"]], 1L)
  expect_equal(split[["desired"]][[1]][["record_id"]], "a")
  expect_setequal(names(split[["errors"]]), "b")
})


test_that("three rows on one pair leave the oldest and mark the two after it", {
  # eval
  register <- rbind(
    register_row(record_id = "7"),
    register_row(record_id = "10"),
    register_row(record_id = "9")
  )
  split <- register_to_desired(register)

  # test
  # Ten beside nine and seven is the case a string comparison gets wrong:
  # "10" sorts before "7".
  expect_length(split[["desired"]], 1L)
  expect_equal(split[["desired"]][[1]][["record_id"]], "7")
  expect_setequal(names(split[["errors"]]), c("9", "10"))
})


test_that("the same person in two different projects is not a duplicate", {
  # eval
  register <- rbind(
    register_row(record_id = "1", project_id = "9003"),
    register_row(record_id = "2", project_id = "9004")
  )
  split <- register_to_desired(register)

  # test
  expect_length(split[["desired"]], 2L)
  expect_length(split[["errors"]], 0L)
})


test_that("the key does not collapse two different pairs", {
  # eval
  register <- rbind(
    register_row(
      record_id = "1", project_id = "900", username = "3a@ubep.unipd.it"
    ),
    register_row(
      record_id = "2", project_id = "9003", username = "a@ubep.unipd.it"
    )
  )
  split <- register_to_desired(register)

  # test
  # Joined without a separator these two pairs read as the same string. The
  # separator is not decoration, and this is the test that says so.
  expect_length(split[["desired"]], 2L)
  expect_length(split[["errors"]], 0L)
})


test_that("register_to_desired reports the data errors of validation", {
  # eval
  register <- rbind(
    register_row(record_id = "1"),
    register_row(
      record_id = "2", project_id = "9004", expiration = "2020-01-01"
    )
  )
  split <- register_to_desired(register)

  # test
  expect_length(split[["desired"]], 1L)
  expect_equal(split[["errors"]][["2"]], "DATO_SCADENZA_NON_VALIDA")
})


test_that("the last day of access is converted once, at the border", {
  # eval
  last_day <- Sys.Date() + 30L
  split <- register_to_desired(
    register_row(expiration = as.character(last_day))
  )

  # test
  # REDCap denies access when expiration <= TODAY, so the day it holds is
  # already out: a request that says "until the 31st" has to be stored as the
  # 1st. It is a one day error, which is to say the kind nobody sees until it
  # concerns the last day of a study.
  expect_equal(
    split[["desired"]][[1]][["expiration"]],
    as.character(last_day + 1L)
  )
})


test_that("outcome_payload carries the outcome and nothing else", {
  # eval
  payload <- outcome_payload(
    record_id = "1",
    outcome = "applied",
    detail = "",
    at = "2026-08-07 10:15",
    applied_as = "role_name=data entry; dag_name=centro-01"
  )

  # test
  # The body is where a bug could rewrite what people asked for. Keeping the
  # columns exact is the structural defense, the same shape as the planner that
  # computes without naming the write functions: it is checked, not promised.
  expect_setequal(
    names(payload),
    c("record_id", "outcome", "outcome_detail", "outcome_at", "applied_as")
  )
  expect_equal(nrow(payload), 1L)
})


test_that("the vocabulary has a word for a row that is held back", {
  # test
  # A row modified after it was applied is neither an error nor still to do.
  # `pending` would say nobody has looked at it, and the two `_error` words
  # would attribute a fault to somebody: the referent who filed it, or us.
  # Nothing went wrong -- the round looked, found the row changed, and stopped
  # on purpose. Only a word of its own can say that to the counter the round's
  # record carries, and to the person reading the outcome in the form.
  expect_true("held" %in% outcome_vocabulary())
})


test_that("outcome_payload refuses an outcome outside the vocabulary", {
  # test
  expect_error(outcome_payload(record_id = "1", outcome = "ok"))
})


test_that("outcome_payload ignores a request field handed to it by mistake", {
  # eval
  payload <- outcome_payload(record_id = "1", outcome = "pending")

  # test
  expect_false("role_name" %in% names(payload))
  expect_false("request_status" %in% names(payload))
  expect_false("username" %in% names(payload))
})


test_that("identity_payload fixes the three columns the job owns", {
  # eval
  body <- identity_payload("7", "mario.rossi@ubep.unipd.it", "existing")

  # test
  # The columns are fixed here and not assembled by the caller, so that a bug
  # cannot rewrite intent. It is decision 12 of the contract applied a second
  # time, to the second family of fields the round owns.
  expect_equal(names(body), c("record_id", "username", "identity"))
  expect_equal(nrow(body), 1L)
  expect_equal(body[["identity"]], "existing")
})


test_that("identity_payload refuses a word outside the vocabulary", {
  # test
  # Matched on a phrase the message owns rather than on the field name: with
  # the field name alone this assertion also passes on "could not find
  # function identity_payload", which is to say before the function exists.
  expect_error(
    identity_payload("7", "", "resolved"),
    "is not one of the five verdicts"
  )
})


test_that("identity_payload takes the empty verdict, which is not a missing", {
  # eval
  body <- identity_payload("7", "", "")

  # test
  # `""` is not an absent value here: it is the verdict "not resolved", which
  # is what a row stopped by a data error carries. It has to be writable, or a
  # row that stops would keep the username it earned back when it still
  # resolved -- and that username is exactly the thing that has become false.
  expect_equal(body[["identity"]], "")
  expect_equal(body[["username"]], "")
})


test_that("a collision carries its proposal rather than an empty username", {
  # eval
  body <- identity_payload("7", "mario.rossi.2@ubep.unipd.it", "collision")

  # test
  # Decision 5 was revised on 2026-08-15: its first draft blanked the username
  # on all three unresolved verdicts, as a second belt beyond the gate.
  # Decision 11 takes that reason away -- on a collision there **is** a
  # determined value to show, and it is the one a person has to act on. Keeping
  # it out of the register would have left it living only inside an e-mail.
  #
  # So the invariant is conditional, and it is the same condition the gate
  # checks: a username is authoritative if and only if `identity` is
  # `existing` or `created`.
  expect_equal(body[["username"]], "mario.rossi.2@ubep.unipd.it")
  expect_equal(body[["identity"]], "collision")
})


test_that("il sigillo ignora i campi che scrive il giro", {
  # eval
  prima <- request_seal(register_row())
  dopo <- request_seal(register_row(
    identity = "existing",
    outcome = "applied",
    outcome_detail = "",
    outcome_at = "2026-09-01 12:04",
    applied_as = "role_name=data entry; dag_name=; expiration="
  ))

  # test
  # The seal is what the round writes beside a row once it has applied it, and
  # what the next round compares the row against. If it moved when the round
  # wrote the outcome, every applied row would look modified one round later:
  # the mechanism would accuse itself, on every row, for ever.
  expect_equal(prima, dopo)
})


test_that("il sigillo non si muove quando qualcuno approva la modifica", {
  # eval
  prima <- request_seal(register_row())
  dopo <- request_seal(register_row(approved_seal = "9f3c1a7b04de"))

  # test
  # The approval carries the seal it approves, so if writing it moved the seal
  # the value would never match the row it was written for: the comparison
  # would chase itself and no change could ever be approved. The field is
  # therefore outside the seal -- and it is the first one that has to be,
  # while still being writable by a person, which is why "written by the
  # channel" and "outside the seal" stopped being the same list.
  expect_equal(prima, dopo)
})


test_that("il sigillo cambia se cambia cio' che e' stato chiesto", {
  # eval
  base <- register_row()
  ruolo <- request_seal(register_row(role_name = "read only"))
  revoca <- request_seal(register_row(request_status = "revoked"))
  gruppo <- request_seal(register_row(dag_name = ""))

  # test
  # One assertion per field would be a test per column and would still miss the
  # next one added. These three are the ones that change what is granted, to
  # whom, and whether it is granted at all.
  expect_false(identical(request_seal(base), ruolo))
  expect_false(identical(request_seal(base), revoca))
  expect_false(identical(request_seal(base), gruppo))
})


eventi_finti <- function(...) {
  righe <- list(...)
  if (length(righe) == 0L) {
    return(log_frame(list()))
  }
  log_frame(lapply(righe, function(r) {
    utils::modifyList(
      list(
        timestamp = "2026-09-01 02:45", username = "", action = "Update record",
        details = "", record = "1"
      ),
      r
    )
  }))
}


test_that("an approval that does not carry the current seal does not count", {
  # eval
  detto <- seal_approved(
    register_row(approved_seal = "000000000000"), eventi_finti()
  )

  # test
  # The approval names the version of the row it approves. A value that is not
  # this row's seal approves some other version -- an earlier change, or a
  # string somebody typed -- and letting it through would make one approval
  # stand for every change that came after it.
  expect_false(detto)
})


test_that("chi ha modificato la riga non puo' approvare la propria modifica", {
  # eval
  riga <- register_row()
  riga[["approved_seal"]] <- request_seal(riga)
  # Most recent first, which is the order REDCap answers in.
  detto <- seal_approved(riga, eventi_finti(
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "approved_seal = 'abc'"
    ),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    )
  ))

  # test
  # Otherwise the protection is a formality: whoever edits another referent's
  # row would tick the box on the way out, and the round would apply a change
  # nobody but its author ever saw. The seal detects the change; only the log
  # can say the approval came from somebody else, because it names whoever was
  # authenticated rather than a value somebody typed.
  expect_false(detto)
})


test_that("un terzo che approva col sigillo giusto sblocca la riga", {
  # eval
  riga <- register_row()
  riga[["approved_seal"]] <- request_seal(riga)
  detto <- seal_approved(riga, eventi_finti(
    list(
      username = "cinzia.rossi@ubep.unipd.it",
      details = "approved_seal = 'abc'"
    ),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    )
  ))

  # test
  # The other side of the two tests above, and it has to be here or an
  # implementation that answered FALSE to everything would pass them both. A
  # protection that never lets anything through is not a protection, it is an
  # outage.
  expect_true(detto)
})
