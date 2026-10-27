register_row <- function(...) {
  defaults <- list(
    record_id = "1",
    server = "edc10",
    project_id = "9003",
    username = "mario.rossi@ubep.unipd.it",
    first_name = "Mario",
    last_name = "Rossi",
    contact_email = "mario.rossi@example.org",
    distinct_username = "",
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
    "is not one of the six verdicts"
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


test_that("scrivere owned_by non muove il sigillo", {
  expect_identical(
    request_seal(register_row()),
    request_seal(register_row(owned_by = "bruno.verdi@ubep.unipd.it"))
  )
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


# A row the round sealed before `distinct_username` existed, with the value
# `request_seal()` gave it then: computed at `aeab3b6`, on the dictionary of
# twenty-one fields. A literal, so that it cannot follow the code it checks.
riga_sigillata_prima <- function(...) {
  utils::modifyList(
    list(
      record_id = "7", server = "edc10", project_id = "9003",
      username = "mario.rossi@ubep.unipd.it", identity = "existing",
      first_name = "Mario", last_name = "Rossi",
      contact_email = "mario.rossi@example.org", role_name = "data entry",
      dag_name = "centro-01", expiration = "2027-01-31",
      requested_by = "anna.bianchi@ubep.unipd.it", request_status = "active"
    ),
    list(...)
  )
}
sigillo_di_prima <- "dfe7cce0f4c7"


test_that("il campo della risposta vuoto non muove il sigillo di prima", {
  # eval
  senza <- as.data.frame(riga_sigillata_prima(), stringsAsFactors = FALSE)
  vuoto <- as.data.frame(
    riga_sigillata_prima(distinct_username = ""), stringsAsFactors = FALSE
  )
  spazi <- as.data.frame(
    riga_sigillata_prima(distinct_username = "  "), stringsAsFactors = FALSE
  )
  mancante <- as.data.frame(
    riga_sigillata_prima(distinct_username = NA_character_),
    stringsAsFactors = FALSE
  )

  # test
  # The field reaches every row of the live register empty on the day the
  # dictionary is imported. Had it moved the seal, every row the round ever
  # sealed would read as changed with nobody on record for it, and every one
  # would be held.
  expect_true("distinct_username" %in% register_intent_fields())
  expect_identical(request_seal(senza), sigillo_di_prima)
  expect_identical(request_seal(vuoto), sigillo_di_prima)
  expect_identical(request_seal(spazi), sigillo_di_prima)
  expect_identical(request_seal(mancante), sigillo_di_prima)
})


test_that("il campo della risposta pieno muove il sigillo", {
  # eval
  risposta <- as.data.frame(
    riga_sigillata_prima(distinct_username = "mario.rossi.2@ubep.unipd.it"),
    stringsAsFactors = FALSE
  )
  altra <- as.data.frame(
    riga_sigillata_prima(distinct_username = "mario.rossi.3@ubep.unipd.it"),
    stringsAsFactors = FALSE
  )

  # test
  # Written, it is an intent field like the others: who writes or empties it
  # changes the row.
  expect_false(identical(request_seal(risposta), sigillo_di_prima))
  expect_false(identical(request_seal(risposta), request_seal(altra)))
})


test_that("lo stesso valore in campi diversi da' sigilli diversi", {
  # eval
  # A second late field, which the dictionary does not have yet: the case
  # the name in front of the value exists for.
  local_mocked_bindings(
    register_intent_fields = function() {
      c(
        "record_id", "server", "project_id", "username", "first_name",
        "last_name", "contact_email", "distinct_username", "role_name",
        "dag_name", "expiration", "request_status", "second_answer"
      )
    },
    register_late_seal_fields = function() {
      c("distinct_username", "second_answer")
    }
  )
  primo <- as.data.frame(
    riga_sigillata_prima(distinct_username = "x", second_answer = ""),
    stringsAsFactors = FALSE
  )
  secondo <- as.data.frame(
    riga_sigillata_prima(distinct_username = "", second_answer = "x"),
    stringsAsFactors = FALSE
  )
  nessuno <- as.data.frame(
    riga_sigillata_prima(distinct_username = "", second_answer = ""),
    stringsAsFactors = FALSE
  )

  # test
  # Appended as the bare value, both rows would join into the same string.
  expect_false(identical(request_seal(primo), request_seal(secondo)))
  expect_identical(request_seal(nessuno), sigillo_di_prima)
})


test_that("ogni campo d'intenzione e' fra quelli sigillati da sempre o fra i tardivi", { # nolint: line_length_linter.
  # eval
  # The fields the seal covered when the first seal was written, and every
  # live seal is a hash of their values in this order.
  da_sempre <- c(
    "record_id", "server", "project_id", "username", "first_name",
    "last_name", "contact_email", "role_name", "dag_name", "expiration",
    "request_status"
  )

  # test
  # An intent field added later and left out of the late list would enter
  # the seal empty, and move every live seal with it: every executed row
  # would be held on the first round after the dictionary is imported.
  expect_setequal(
    register_intent_fields(), c(da_sempre, register_late_seal_fields())
  )
  expect_length(intersect(da_sempre, register_late_seal_fields()), 0L)
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


# Who REDCap authenticated when the row was made, as `log_creators()` reads it
# from the creation log: the one person a change by somebody else waits for.
creatrice <- "anna.bianchi@ubep.unipd.it"


test_that("an approval that does not carry the current seal does not count", {
  # eval
  detto <- seal_approved(
    register_row(approved_seal = "000000000000"),
    eventi_finti(list(
      username = creatrice, details = "approved_seal = '000000000000'"
    )),
    creatrice
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
  detto <- seal_approved(
    riga,
    eventi_finti(
      list(
        username = "bruno.verdi@ubep.unipd.it",
        details = "approved_seal = 'abc'"
      ),
      list(
        username = "bruno.verdi@ubep.unipd.it",
        details = "role_name = 'read only'"
      )
    ),
    creatrice
  )

  # test
  # Otherwise the protection is a formality: whoever edits another referent's
  # row would tick the box on the way out, and the round would apply a change
  # nobody but its author ever saw.
  expect_false(detto)
})


test_that("un terzo che approva col sigillo giusto non sblocca la riga", {
  # eval
  riga <- register_row()
  riga[["approved_seal"]] <- request_seal(riga)
  detto <- seal_approved(
    riga,
    eventi_finti(
      list(
        username = "cinzia.rossi@ubep.unipd.it",
        details = "approved_seal = 'abc'"
      ),
      list(
        username = "bruno.verdi@ubep.unipd.it",
        details = "role_name = 'read only'"
      )
    ),
    creatrice
  )

  # test
  # Somebody other than the author is not enough. The request is the
  # creator's, and the creator answers for it: the scope gate checks the
  # creator's rights on the project every round, and nobody else's. An
  # approval from a third referent would grant on the word of somebody whose
  # rights on that project nobody has looked at.
  expect_false(detto)
})


test_that("chi ha creato la riga la sblocca col sigillo giusto", {
  # eval
  riga <- register_row()
  riga[["approved_seal"]] <- request_seal(riga)
  detto <- seal_approved(
    riga,
    eventi_finti(
      list(username = creatrice, details = "approved_seal = 'abc'"),
      list(
        username = "bruno.verdi@ubep.unipd.it",
        details = "role_name = 'read only'"
      )
    ),
    creatrice
  )

  # test
  # The other side of the tests above, and it has to be here or an
  # implementation that answered FALSE to everything would pass them all. A
  # protection that never lets anything through is not a protection, it is an
  # outage.
  expect_true(detto)
})


test_that("senza il creatore nessuna approvazione vale", {
  # eval
  riga <- register_row()
  riga[["approved_seal"]] <- request_seal(riga)
  detto <- seal_approved(
    riga,
    eventi_finti(list(username = creatrice, details = "approved_seal = 'abc'")),
    ""
  )

  # test
  # The creation log could not be read, or no longer names the row. "I could
  # not establish who made this" is not "whoever approved it made it".
  expect_false(detto)
})


test_that("seal_approved non concede quando il log non nomina chi ha modificato", { # nolint: line_length_linter.
  # eval
  # The approval alone, as a window of a day would have returned it: the edit
  # it approves is older than the window.
  riga <- register_row()
  riga[["approved_seal"]] <- request_seal(riga)
  eventi <- eventi_finti(list(
    timestamp = "2026-08-13 23:00",
    username = "bruno.verdi@ubep.unipd.it",
    details = paste0("approved_seal = '", request_seal(riga), "'")
  ))

  # test
  # An author nobody can name is not a sign that anybody may approve.
  expect_equal(log_change_authors(eventi, "1"), character())
  expect_true(change_needs_approval(log_change_authors(eventi, "1"), creatrice))
  expect_false(seal_approved(riga, eventi, creatrice))
})


# The round's write when it applied the row, in an earlier pass: the seals
# door's event, which carries the seal and its state and nothing else.
applicata <- list(
  username = "svc-canale-ubep", action = "Update record (API) 1",
  details = "applied_seal = '000000000000', seal_state = 'intact'"
)


test_that("un'approvazione piu' vecchia dell'ultima esecuzione non vale", {
  # eval
  riga <- register_row()
  riga[["approved_seal"]] <- request_seal(riga)
  # Newest first: the creator's approval was carried out by the round, and
  # Bruno changed the row afterwards.
  detto <- seal_approved(
    riga,
    eventi_finti(
      list(
        username = "bruno.verdi@ubep.unipd.it",
        details = "role_name = 'read only'"
      ),
      applicata,
      list(username = creatrice, details = "approved_seal = 'abc'")
    ),
    creatrice
  )

  # test
  # An approval is spent by the execution it allowed. `approved_seal` is
  # never blanked, so the value alone would approve again any later change
  # that brings the row back to it.
  expect_false(detto)
})


test_that("un'approvazione piu' vecchia della modifica di un altro non vale", {
  # eval
  riga <- register_row()
  riga[["approved_seal"]] <- request_seal(riga)
  sotto <- function(chi) {
    seal_approved(
      riga,
      eventi_finti(
        list(username = chi, details = "role_name = 'read only'"),
        list(username = creatrice, details = "approved_seal = 'abc'"),
        applicata
      ),
      creatrice
    )
  }

  # test
  # Written before the change, the approval cannot say the creator saw it:
  # it is a seal computed in advance. A change nobody signed is not the
  # creator's either.
  expect_false(sotto("bruno.verdi@ubep.unipd.it"))
  expect_false(sotto(""))
  # The creator's own later edit is no reason to refuse it: the value check
  # is what stops an approval of a version the creator then changed.
  expect_true(sotto(creatrice))
})


test_that("conta chi ha cambiato la riga dopo l'ultima esecuzione, e nessun altro", { # nolint: line_length_linter.
  # eval
  # Newest first. Bruno changed the row before the round applied it, and that
  # change was applied; after it, Cinzia and then Anna.
  detto <- log_change_authors(
    eventi_finti(
      list(username = creatrice, details = "expiration = '2027-01-31'"),
      list(
        username = "svc-canale-ubep", action = "Update record (API) 1",
        details = "username = 'mario.rossi@ubep.unipd.it'"
      ),
      list(
        username = "cinzia.rossi@ubep.unipd.it",
        details = "role_name = 'read only'"
      ),
      applicata,
      list(
        username = "bruno.verdi@ubep.unipd.it",
        details = "dag_name = 'centro-02'"
      ),
      list(
        username = creatrice, action = "Create record 1",
        details = "record_id = '1', requested_by = 'anna.bianchi@ubep.unipd.it'"
      )
    ),
    "1"
  )

  # test
  # What was applied was already somebody's responsibility. What stands
  # between the last execution and now is the change the round is about to
  # carry out, and the channel's own writes are not a change.
  expect_equal(detto, c(creatrice, "cinzia.rossi@ubep.unipd.it"))
})


test_that("una modifica di un altro sotto l'ultima esecuzione conta, se nessuno l'ha approvata", { # nolint: line_length_linter.
  # eval
  # Newest first. Bruno's edit is below the round's last seal: the round read
  # the row before it, and wrote the seal after it.
  eventi <- eventi_finti(
    list(username = creatrice, details = "expiration = '2027-01-31'"),
    applicata,
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    ),
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', role_name = 'data entry'"
    )
  )
  detto <- log_pending_authors(eventi, "1", creatrice)

  # test
  # The last execution covers what the round read, and the round applies a
  # change by somebody other than the creator only once the creator has
  # approved it. Below the seal and with no approval above it, Bruno's edit
  # was never carried out with the creator's leave.
  expect_equal(log_uncovered_authors(eventi, "1", creatrice),
               "bruno.verdi@ubep.unipd.it")
  expect_equal(detto, c(creatrice, "bruno.verdi@ubep.unipd.it"))
  expect_true(change_needs_approval(detto, creatrice))
})


test_that("una modifica di un altro approvata e poi eseguita non conta piu'", {
  # eval
  approvata <- function(sigillo) {
    eventi_finti(
      list(username = creatrice, details = "expiration = '2027-01-31'"),
      applicata,
      list(
        username = creatrice,
        details = paste0("approved_seal = '", sigillo, "'")
      ),
      list(
        username = "bruno.verdi@ubep.unipd.it",
        details = "role_name = 'read only'"
      )
    )
  }

  # test
  # The creator approved the version the round then sealed: that execution
  # carried Bruno's edit out with her leave.
  expect_equal(
    log_uncovered_authors(approvata("000000000000"), "1", creatrice),
    character()
  )
  expect_equal(
    log_pending_authors(approvata("000000000000"), "1", creatrice), creatrice
  )
  # An approval of some other version does not cover it.
  expect_equal(
    log_uncovered_authors(approvata("111111111111"), "1", creatrice),
    "bruno.verdi@ubep.unipd.it"
  )
  # Nor does anything when the creator is not known.
  expect_true(
    is.na(log_uncovered_authors(approvata("000000000000"), "1", ""))
  )
})


test_that("con due esecuzioni il confine e' la piu' recente", {
  # eval
  # Newest first. Bruno changed the row, Anna approved it, the round applied
  # it; then Anna changed the expiration.
  eventi <- eventi_finti(
    list(username = creatrice, details = "expiration = '2027-01-31'"),
    applicata,
    list(username = creatrice, details = "approved_seal = '000000000000'"),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "dag_name = 'centro-02'"
    ),
    applicata
  )

  # test
  # Every other log in these tests holds one execution, so none of them
  # tells the newest from the oldest. Counted from the oldest, Bruno's change
  # -- approved and carried out -- would come back as an author, and the
  # creator's own edit would wait for an approval.
  detto <- log_pending_authors(eventi, "1", creatrice)
  expect_equal(log_change_authors(eventi, "1"), creatrice)
  expect_equal(detto, creatrice)
  expect_false(change_needs_approval(detto, creatrice))
})


test_that("senza la scrittura del sigillo conta tutta la storia della riga", {
  # eval
  detto <- log_change_authors(
    eventi_finti(
      list(username = creatrice, details = "role_name = 'read only'"),
      list(
        username = creatrice, action = "Create record 1",
        details = "record_id = '1', requested_by = 'anna.bianchi@ubep.unipd.it'"
      )
    ),
    "1"
  )

  # test
  # Where the row's log no longer carries the round's last execution, the
  # change could be anywhere in what is left, so all of it counts: a wider
  # set of authors can only ask for an approval more often, never less.
  expect_equal(detto, creatrice)
})


test_that("due utenze che scrivono i campi del canale rendono ignoto l'autore", { # nolint: line_length_linter.
  # eval
  detto <- log_change_authors(
    eventi_finti(
      list(
        username = "bruno.verdi@ubep.unipd.it",
        details = "role_name = 'read only', outcome = 'applied'"
      ),
      list(username = creatrice, details = "expiration = '2027-01-31'"),
      applicata
    ),
    "1"
  )

  # test
  # The account that holds the round's token is one. A second account writing
  # what only the channel writes is something nobody planned -- a value that
  # reads as a field assignment, an import right granted after all -- and
  # taking it for the channel would drop its author from the change.
  expect_true(is.na(detto))
  expect_true(change_needs_approval(detto, creatrice))
})


test_that("una modifica d'intenzione senza autore rende ignoto l'autore", {
  # eval
  detto <- log_change_authors(
    eventi_finti(
      list(username = "", details = "role_name = 'read only'"),
      list(username = creatrice, details = "expiration = '2027-01-31'"),
      applicata
    ),
    "1"
  )

  # test
  expect_true(is.na(detto))
})


test_that("una scrittura poi sovrascritta non conta", {
  # eval
  # Newest first. Bruno set the role, Anna set it again, and the row now
  # holds Anna's value.
  eventi <- eventi_finti(
    list(username = creatrice, details = "role_name = 'data entry'"),
    list(
      username = "bruno.verdi@ubep.unipd.it", details = "role_name = 'admin'"
    ),
    applicata,
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', role_name = 'read only'"
    )
  )

  # test
  # What the round would carry out is Anna's value: Bruno's write is no longer
  # in the row, so it is not part of the change.
  expect_equal(
    log_change_authors(
      eventi, "1", current = register_row(role_name = "data entry")
    ),
    creatrice
  )
  expect_equal(log_change_authors(eventi, "1"), creatrice)
})


test_that("un campo tornato al valore eseguito non conta", {
  # eval
  # Newest first. Bruno moved the role away from what the round carried out
  # and then back to it.
  eventi <- eventi_finti(
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    ),
    list(
      username = "bruno.verdi@ubep.unipd.it", details = "role_name = 'admin'"
    ),
    applicata,
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', role_name = 'read only'"
    )
  )

  # test
  # The row asks for what was carried out already: nothing to carry out, and
  # nobody to ask. Without the row in hand the last write still counts.
  expect_equal(
    log_change_authors(
      eventi, "1", current = register_row(role_name = "read only")
    ),
    character()
  )
  expect_equal(log_change_authors(eventi, "1"), "bruno.verdi@ubep.unipd.it")
})


test_that("su una riga mai eseguita conta l'ultimo autore di ogni campo scritto", { # nolint: line_length_linter.
  # eval
  # Newest first, and no execution: Anna created the row, Cinzia changed the
  # role, Bruno emptied the group.
  eventi <- eventi_finti(
    list(username = "bruno.verdi@ubep.unipd.it", details = "dag_name = ''"),
    list(
      username = "cinzia.rossi@ubep.unipd.it",
      details = "role_name = 'data entry'"
    ),
    list(
      username = creatrice, action = "Create record 1",
      details = paste0(
        "record_id = '1', role_name = 'read only', dag_name = 'centro-02'"
      )
    )
  )

  # test
  # Every field written is part of what the round would carry out, and it
  # answers to whoever wrote it last: Bruno for the emptied group, Cinzia for
  # the role, Anna for `record_id`, which nobody wrote after her.
  expect_equal(
    log_change_authors(eventi, "1", current = register_row(dag_name = "")),
    c("bruno.verdi@ubep.unipd.it", "cinzia.rossi@ubep.unipd.it", creatrice)
  )
})


test_that("su una riga mai eseguita chi svuota un campo conta", {
  # eval
  # Newest first, and no execution: Anna created the row in a group, Bruno
  # emptied it.
  eventi <- eventi_finti(
    list(username = "bruno.verdi@ubep.unipd.it", details = "dag_name = ''"),
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', dag_name = 'centro-01'"
    )
  )

  # test
  # An empty group is a user in no group: it decides what is granted, and on
  # a row never carried out there is no value to compare it with. Anna stays
  # for `record_id`.
  expect_equal(
    log_change_authors(eventi, "1", current = register_row(dag_name = "")),
    c("bruno.verdi@ubep.unipd.it", creatrice)
  )
})


test_that("un campo senza valore eseguito nel log conta se scritto dopo il sigillo", { # nolint: line_length_linter.
  # eval
  # Newest first. The creation wrote only the record id, so the role the
  # round carried out is not in the log; Bruno emptied it afterwards.
  eventi <- eventi_finti(
    list(username = "bruno.verdi@ubep.unipd.it", details = "role_name = ''"),
    applicata,
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1'"
    )
  )

  # test
  # An unknown value carried out is not taken for an empty one: the field
  # counts because somebody wrote it since the execution.
  expect_equal(
    log_change_authors(eventi, "1", current = register_row(role_name = "")),
    "bruno.verdi@ubep.unipd.it"
  )
})


# The log cuts a value at its first apostrophe: compared with the log alone,
# `D'Angelo` and `D'Amico` would both read `D`, and Bruno's change would pass
# for no change.
test_that("un valore con l'apostrofo si confronta col registro e l'autore conta", { # nolint: line_length_linter.
  # eval
  eventi <- eventi_finti(
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "last_name = 'D'Angelo'"
    ),
    applicata,
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', last_name = 'D'Amico'"
    )
  )

  # test
  # The log cuts both values at the apostrophe, `D`, and would call them
  # equal. The current value comes from the register, which holds it whole.
  expect_equal(
    log_change_authors(
      eventi, "1", current = register_row(last_name = "D'Angelo")
    ),
    "bruno.verdi@ubep.unipd.it"
  )
})


test_that("un valore eseguito con l'apostrofo e' ignoto, e il campo scritto dopo conta", { # nolint: line_length_linter.
  # eval
  # Carried out as `D'Amico`, which the log reads `D`; Bruno then writes
  # exactly `D`.
  eventi <- eventi_finti(
    list(username = "bruno.verdi@ubep.unipd.it", details = "last_name = 'D'"),
    applicata,
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', last_name = 'D'Amico', role_name = 'x'"
    )
  )

  # test
  # Compared with what the log reads, Bruno's value would equal the one
  # carried out and his change would vanish. Where the value ends cannot be
  # told, so it is unknown, and a field written since counts.
  for (account in list(NULL, "svc-canale-ubep")) {
    expect_equal(
      log_change_authors(
        eventi, "1", channel_account = account,
        current = register_row(last_name = "D")
      ),
      "bruno.verdi@ubep.unipd.it"
    )
  }
})


test_that("le autrici in attesa leggono la riga attuale", {
  # eval
  # Newest first. Bruno moved the role away from what the round carried out
  # and then back to it.
  eventi <- eventi_finti(
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    ),
    list(
      username = "bruno.verdi@ubep.unipd.it", details = "role_name = 'admin'"
    ),
    applicata,
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', role_name = 'read only'"
    )
  )

  # test
  expect_equal(
    log_pending_authors(
      eventi, "1", creatrice,
      current = register_row(role_name = "read only")
    ),
    character()
  )
})


test_that("solo una modifica tutta del creatore non chiede approvazione", {
  # eval, test
  # The one place the rule lives. A revocation follows it too, until it is
  # decided whether a referent with rights on the project may withdraw
  # somebody else's request without the creator.
  expect_false(change_needs_approval(creatrice, creatrice))
  expect_true(change_needs_approval("bruno.verdi@ubep.unipd.it", creatrice))
  expect_true(
    change_needs_approval(c(creatrice, "bruno.verdi@ubep.unipd.it"), creatrice)
  )
  expect_true(change_needs_approval(character(), creatrice))
  expect_true(change_needs_approval(NA_character_, creatrice))
  expect_true(change_needs_approval(creatrice, ""))
})


test_that("una richiesta mai eseguita aspetta solo se qualcun altro l'ha cambiata", { # nolint: line_length_linter.
  # eval, test
  # With no seal there is no evidence that the row moved, so a log that
  # names nobody says nobody changed it. What it does name is judged as on
  # an applied row.
  expect_false(change_needs_approval(character(), creatrice, sealed = FALSE))
  expect_false(change_needs_approval(creatrice, creatrice, sealed = FALSE))
  expect_true(change_needs_approval(
    c(creatrice, "bruno.verdi@ubep.unipd.it"), creatrice, sealed = FALSE
  ))
  expect_true(change_needs_approval(NA_character_, creatrice, sealed = FALSE))
  expect_true(change_needs_approval(character(), "", sealed = FALSE))
})


test_that("una revoca di chi gestisce il progetto non chiede approvazione", {
  # eval, test
  # Decided on 2026-10-15: taking an access away grants nothing, and whoever
  # holds User Rights on the project could have done it by hand.
  bruno <- "bruno.verdi@ubep.unipd.it"
  expect_false(change_needs_approval(
    bruno, creatrice, revocation = TRUE, managers = bruno
  ))
  expect_false(change_needs_approval(
    c(creatrice, bruno), creatrice, revocation = TRUE, managers = bruno
  ))
  # Every hand other than the creator's has to manage the project.
  expect_true(change_needs_approval(
    c(bruno, "cinzia.rossi@ubep.unipd.it"), creatrice,
    revocation = TRUE, managers = bruno
  ))
  # Managing the project frees a revocation, and nothing else.
  expect_true(change_needs_approval(bruno, creatrice, managers = bruno))
  expect_true(change_needs_approval(bruno, creatrice, revocation = TRUE))
  # What the log cannot say stays unknown, revocation or not.
  expect_true(change_needs_approval(
    NA_character_, creatrice, revocation = TRUE, managers = bruno
  ))
  expect_true(change_needs_approval(
    bruno, "", revocation = TRUE, managers = bruno
  ))
})


test_that("la revoca e' solo quella che chi non ha creato la riga ha scritto", {
  # eval
  bruno <- "bruno.verdi@ubep.unipd.it"
  solo_stato <- eventi_finti(
    list(username = bruno, details = "request_status = 'revoked'"),
    applicata
  )
  anche_ruolo <- eventi_finti(
    list(
      username = bruno,
      details = "request_status = 'revoked', role_name = 'read only'"
    ),
    applicata
  )
  riattivata <- eventi_finti(
    list(username = bruno, details = "request_status = 'active'"),
    applicata
  )
  # The creator's own edits are the creator's to make, and do not count here.
  con_creatrice <- eventi_finti(
    list(username = bruno, details = "request_status = 'revoked'"),
    list(username = creatrice, details = "role_name = 'read only'"),
    applicata
  )
  # Below the newest execution, and covered by the creator's approval of what
  # it carried out: not part of this change.
  prima <- eventi_finti(
    list(username = bruno, details = "request_status = 'revoked'"),
    applicata,
    list(username = creatrice, details = "approved_seal = '000000000000'"),
    list(username = bruno, details = "role_name = 'read only'")
  )
  # The same change with no approval above it was never carried out: an edit
  # made while a round ran, which waits for the creator as before.
  scoperta <- eventi_finti(
    list(username = bruno, details = "request_status = 'revoked'"),
    applicata,
    list(username = bruno, details = "role_name = 'read only'")
  )

  # test
  expect_true(log_revocation_only(solo_stato, "1", creatrice))
  expect_false(log_revocation_only(anche_ruolo, "1", creatrice))
  expect_false(log_revocation_only(riattivata, "1", creatrice))
  expect_true(log_revocation_only(con_creatrice, "1", creatrice))
  expect_true(log_revocation_only(prima, "1", creatrice))
  expect_false(log_revocation_only(scoperta, "1", creatrice))
  # Nobody but the creator wrote anything: there is no revocation by somebody
  # else to free.
  expect_false(log_revocation_only(
    eventi_finti(
      list(username = creatrice, details = "request_status = 'revoked'"),
      applicata
    ),
    "1", creatrice
  ))
  expect_false(log_revocation_only(solo_stato, "1", ""))
})


test_that("l'approvazione di IT vale come quella di chi ha creato la riga", {
  # eval
  it <- "it.redcap@ubep.unipd.it"
  riga <- register_row()
  riga[["approved_seal"]] <- request_seal(riga)
  eventi <- eventi_finti(
    list(username = it, details = "approved_seal = 'abc'"),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    )
  )
  prima_della_modifica <- eventi_finti(
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    ),
    list(username = it, details = "approved_seal = 'abc'")
  )

  # test
  # Decided on 2026-10-15, so that a request whose creator has left is not
  # stuck for ever, and keeps its creator on record.
  expect_true(seal_approved(riga, eventi, creatrice, approvers = it))
  # Only the accounts the machine names: without the list nobody else counts.
  expect_false(seal_approved(riga, eventi, creatrice))
  # The same conditions as any other approval: newer than what it approves.
  expect_false(
    seal_approved(riga, prima_della_modifica, creatrice, approvers = it)
  )
})


test_that("l'elenco di IT non dipende dalle maiuscole", {
  # eval
  riga <- register_row()
  riga[["approved_seal"]] <- request_seal(riga)
  eventi <- eventi_finti(
    list(username = "it.redcap@ubep.unipd.it", details = "approved_seal = 'a'"),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    )
  )

  # test
  # The list is typed by hand on the machine; REDCap logs the username as it
  # stores it. A capital letter must not make IT's approval silently void.
  expect_true(seal_approved(
    riga, eventi, creatrice, approvers = "IT.Redcap@ubep.unipd.it"
  ))
})


test_that("il canale e' chi ha scritto i campi che scrive solo lui", {
  # eval
  # Newest first. The channel's username rewrite carries `username` alone,
  # since REDCap logs only the fields an import changed: the event that names
  # the channel is the older one, the round that applied the row.
  detto <- log_channel_accounts(
    eventi_finti(
      list(
        username = "svc-canale-ubep", action = "Update record (API) 1",
        details = "username = 'mario.rossi@ubep.unipd.it'"
      ),
      list(
        username = "bruno.verdi@ubep.unipd.it",
        details = "role_name = 'read only', username = ''"
      ),
      list(
        username = "svc-canale-ubep", action = "Update record (API) 1",
        details = paste0(
          "outcome = 'applied', outcome_at = '2026-08-12 03:00', ",
          "applied_seal = '000000000000', seal_state = 'intact'"
        )
      ),
      list(
        username = "anna.bianchi@ubep.unipd.it", action = "Create record 1",
        details = "record_id = '1', requested_by = 'anna.bianchi@ubep.unipd.it'"
      )
    ),
    "1"
  )

  # test
  # No configuration names the channel's account, and none is needed: the
  # outcome fields are `@READONLY` on the form and the import right is granted
  # to nobody, so whoever wrote them is the account that holds the token.
  # `requested_by` is the one read-only field a person does write, through
  # `@USERNAME` when the row is created, and it does not count.
  expect_equal(detto, "svc-canale-ubep")
})


test_that("la riscrittura dello username da parte del canale non rende valida l'autoapprovazione", { # nolint: line_length_linter.
  # eval
  riga <- register_row()
  riga[["approved_seal"]] <- request_seal(riga)
  # Newest first. Bruno changes the role and blanks the username, the round
  # writes back the username it resolves, Bruno approves.
  eventi <- eventi_finti(
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = paste0("approved_seal = '", request_seal(riga), "'")
    ),
    list(
      username = "svc-canale-ubep", action = "Update record (API) 1",
      details = "username = 'mario.rossi@ubep.unipd.it'"
    ),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only', username = ''"
    ),
    list(
      username = "svc-canale-ubep", action = "Update record (API) 1",
      details = "outcome = 'applied', applied_seal = '000000000000'"
    )
  )

  # test
  # `username` is an intent field, so the channel's rewrite is the newest
  # write of one. Read as a change, it would make the channel the author of
  # the edit, and anybody but the channel -- Bruno included -- its approver.
  expect_false(seal_approved(riga, eventi, creatrice))
})


test_that("the creator is who REDCap authenticated, not who the row names", {
  # eval
  # The forgery, written out: an import that hands `requested_by` a name that
  # is not the importer's. Measured on 2026-09-02 on edc10, this is exactly
  # what the Data Import Tool writes -- `@USERNAME` is an action tag, it
  # governs the form REDCap draws and an import draws none.
  detto <- log_creators(
    eventi_finti(list(
      username = "anna.bianchi@ubep.unipd.it",
      action = "Create record (import) 7",
      details = paste0(
        "record_id = '7', requested_by = 'mario.rossi@ubep.unipd.it', ",
        "server = 'edc05'"
      ),
      record = "7"
    )),
    "7"
  )

  # test
  # The two names are both in the event and only one of them is a fact. The
  # `username` column is who REDCap had authenticated when the row appeared,
  # and no value in the payload can move it; `requested_by` inside `details`
  # is the string the importer chose. A reader that took the second would
  # authorize Mario for what Anna did.
  expect_equal(detto, "anna.bianchi@ubep.unipd.it")
})


test_that("a row the log does not name is attributed to nobody", {
  # eval
  detto <- log_creators(eventi_finti(), "7")

  # test
  # REDCap purges its log on a schedule an instance sets, so a row filed long
  # enough ago can outlive the event that made it. That is not "nobody filed
  # it" and must not read as a name either: the empty string is the third
  # answer, and the caller is the one that decides a row it cannot attribute
  # waits rather than being refused against whoever filed it.
  expect_equal(detto, "")
})


test_that("an id used twice is answered for by the creation that stands", {
  # eval
  # Newest first, which is the order REDCap answers in.
  detto <- log_creators(
    eventi_finti(
      list(username = "bruno.verdi@ubep.unipd.it",
           action = "Create record 7", record = "7"),
      list(username = "anna.bianchi@ubep.unipd.it",
           action = "Create record 7", record = "7")
    ),
    "7"
  )

  # test
  # An id carries two creations when a record was deleted and made again, and
  # the row standing now is the one made last. Answering with the older event
  # would gate today's request on the rights of whoever filed a row that no
  # longer exists.
  expect_equal(detto, "bruno.verdi@ubep.unipd.it")
})


test_that("an edit does not pass for a creation if REDCap ignored the filter", {
  # eval
  # The order is REDCap's, newest first: the edit is more recent than the
  # creation. This is the log a caller would get if `logtype` had not been
  # honoured -- an unknown parameter is ignored rather than refused, so the
  # answer would come back complete and look exactly like a valid one.
  detto <- log_creators(
    eventi_finti(
      list(username = "bruno.verdi@ubep.unipd.it", action = "Update record 7",
           record = "7"),
      list(username = "anna.bianchi@ubep.unipd.it", action = "Create record 7",
           record = "7")
    ),
    "7"
  )

  # test
  # The filter is asked of REDCap and must not be trusted blind: a parameter
  # that is silently ignored is the family of failure this project keeps
  # meeting, and here it would hand the gate the name of whoever last touched
  # the row instead of whoever opened it. The guard reads the prose of
  # `action`, which is exactly what the primary mechanism refuses to do -- and
  # that is sound only because it fails CLOSED: if REDCap ever rewords the
  # string, no creation matches, the answer is empty, and the row is held
  # rather than judged on the wrong person.
  expect_equal(detto, "anna.bianchi@ubep.unipd.it")
})


# The account the round's token belongs to, as the runner configures it.
canale <- "svc-canale-ubep"

# The channel's write of the row's owner, as the owner door leaves it.
passaggio <- function(chi, ...) {
  list(
    username = canale, action = "Update record (API) 1",
    details = paste0("owned_by = '", chi, "'"), ...
  )
}


test_that("senza scritture del canale la riga e' del creatore", {
  eventi <- eventi_finti(applicata)
  expect_equal(log_owner(eventi, "1", creatrice, canale), creatrice)
  expect_equal(log_owner(eventi, "1", "", canale), "")
})


test_that("il proprietario e' l'ultima owned_by scritta dal canale", {
  eventi <- eventi_finti(
    passaggio("bruno.verdi@ubep.unipd.it"), applicata, passaggio(creatrice)
  )
  expect_equal(
    log_owner(eventi, "1", creatrice, canale), "bruno.verdi@ubep.unipd.it"
  )
  # Typed by hand on the machine: a capital letter does not void it.
  expect_equal(
    log_owner(eventi, "1", creatrice, "SVC-Canale-Ubep"),
    "bruno.verdi@ubep.unipd.it"
  )
})


test_that("senza l'account del canale nessuna owned_by si crede", {
  eventi <- eventi_finti(passaggio("bruno.verdi@ubep.unipd.it"), applicata)
  expect_equal(log_owner(eventi, "1", creatrice), creatrice)
})


test_that("una owned_by scritta da un'altra utenza si ignora", {
  altra <- list(
    username = "bruno.verdi@ubep.unipd.it",
    details = "owned_by = 'cinzia.rossi@ubep.unipd.it'"
  )
  # With the account configured the channel is that account and nobody else:
  # another account's write names no owner and does not hide the channel's.
  expect_equal(
    log_owner(eventi_finti(altra, applicata), "1", creatrice, canale),
    creatrice
  )
  expect_equal(
    log_owner(
      eventi_finti(altra, passaggio("davide.neri@ubep.unipd.it"), applicata),
      "1", creatrice, canale
    ),
    "davide.neri@ubep.unipd.it"
  )
  # Without the account the channel is guessed from what it writes, and two
  # accounts writing its fields leave the owner unknown.
  expect_true(is.na(log_owner(eventi_finti(altra, applicata), "1", creatrice)))
})


test_that("una owned_by senza autore sopra quella del canale rende ignoto il proprietario", { # nolint: line_length_linter.
  bruno <- "bruno.verdi@ubep.unipd.it"
  for (chi in list("", NA_character_)) {
    vuota <- list(
      username = chi, details = "owned_by = 'cinzia.rossi@ubep.unipd.it'"
    )
    # It names nobody, and it is not another account: it could be the
    # channel's. It is the one write of `owned_by` the channel's account does
    # not settle.
    expect_equal(
      log_channel_accounts(eventi_finti(vuota, applicata), "1", canale), canale
    )
    expect_true(is.na(
      log_owner(eventi_finti(vuota, applicata), "1", creatrice, canale)
    ))
    expect_true(is.na(log_owner(
      eventi_finti(vuota, passaggio(bruno), applicata), "1", creatrice, canale
    )))
    # Below the channel's newest write it changes nothing.
    expect_equal(
      log_owner(
        eventi_finti(passaggio(bruno), vuota, applicata), "1", creatrice, canale
      ),
      bruno
    )
    # Nor does a blank author of another field of the channel.
    expect_equal(
      log_owner(
        eventi_finti(list(username = chi, details = "outcome = 'held'"),
                     applicata),
        "1", creatrice, canale
      ),
      creatrice
    )
  }
})


# Writing a channel field does not make an account the channel: recognized by
# what it writes, an import of owned_by would hand the row to whoever made it.
test_that("chi importa owned_by su una riga nuova non passa per il canale", {
  # Anna filed the row; before the round ever wrote on it, Bruno imported
  # owned_by alone. He is the only account that wrote a channel field.
  eventi <- eventi_finti(
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "owned_by = 'bruno.verdi@ubep.unipd.it'"
    ),
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', role_name = 'data entry'"
    )
  )
  # Recognized by what it writes, the channel would be Bruno.
  expect_equal(log_channel_accounts(eventi, "1"), "bruno.verdi@ubep.unipd.it")
  # Named by the configuration, the channel is the round's account even
  # where it has not written yet; Bruno's import is ignored, and the row
  # stays with Anna.
  expect_equal(log_channel_accounts(eventi, "1", canale), canale)
  expect_equal(log_owner(eventi, "1", creatrice, canale), creatrice)
  expect_equal(
    log_pending_authors(eventi, "1", creatrice, channel_account = canale),
    creatrice
  )
})


test_that("la vita di prima di un id riusato non lascia il proprietario", {
  eventi <- eventi_finti(
    applicata,
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1'"
    ),
    passaggio("collaudo.prova@ubep.unipd.it"),
    list(
      username = "collaudo.prova@ubep.unipd.it", action = "Create record 1",
      details = "record_id = '1'"
    )
  )
  expect_equal(log_owner(eventi, "1", creatrice, canale), creatrice)
})


test_that("un evento di un'altra riga non nomina il proprietario", {
  eventi <- eventi_finti(
    passaggio("bruno.verdi@ubep.unipd.it", record = "2"), applicata
  )
  expect_equal(log_owner(eventi, "1", creatrice, canale), creatrice)
})


test_that("il proprietario alla data legge solo cio' che viene prima", {
  eventi <- eventi_finti(
    passaggio("bruno.verdi@ubep.unipd.it", timestamp = "2026-11-01 00:00"),
    passaggio("cinzia.rossi@ubep.unipd.it", timestamp = "2026-10-31 23:59"),
    applicata
  )
  expect_equal(
    log_owner(eventi, "1", creatrice, canale, before = "2026-11-01 00:00"),
    "cinzia.rossi@ubep.unipd.it"
  )
  expect_equal(
    log_owner(eventi, "1", creatrice, canale, before = "2026-10-31 23:59"),
    creatrice
  )
  storto <- eventi_finti(passaggio(creatrice, timestamp = "ieri"), applicata)
  expect_true(is.na(
    log_owner(storto, "1", creatrice, canale, before = "2026-11-01 00:00")
  ))
  # With seconds, a write of that same minute would read as before it.
  expect_error(
    log_owner(eventi, "1", creatrice, canale, before = "2026-11-01 00:00:00")
  )
})


test_that("la owned_by del canale si legge intera, anche con l'apostrofo", {
  # The log writes the value between apostrophes and does not escape one
  # inside it, and a UPN can hold one: read up to the first apostrophe, the
  # owner would be `luca.d`, and the round would write that back as stable.
  chi <- "luca.d'amico@ubep.unipd.it"
  expect_equal(
    log_owner(eventi_finti(passaggio(chi), applicata), "1", creatrice, canale),
    chi
  )
  # A write by the channel that leaves the field blank still names nobody,
  # and the one below it is read.
  expect_equal(
    log_owner(
      eventi_finti(passaggio(""), passaggio(chi), applicata),
      "1", creatrice, canale
    ),
    chi
  )
})


test_that("una owned_by del canale scritta con altri campi non stabilisce il proprietario", { # nolint: line_length_linter.
  # The owner door writes `owned_by` alone, so an event of the channel that
  # carries other fields is not one the round wrote through it, and where
  # one value ends and the next begins cannot be told apart from an
  # apostrophe inside a name.
  for (details in c(
    "owned_by = 'bruno.verdi@ubep.unipd.it', seal_state = 'intact'",
    "seal_state = 'intact', owned_by = 'bruno.verdi@ubep.unipd.it'"
  )) {
    eventi <- eventi_finti(
      list(
        username = canale, action = "Update record (API) 1", details = details
      ),
      applicata
    )
    expect_true(
      is.na(log_owner(eventi, "1", creatrice, canale)), info = details
    )
  }
})


eseguita <- function(sigillo) {
  list(
    username = "svc-canale-ubep", action = "Update record (API) 1",
    details = paste0(
      "applied_seal = '", sigillo, "', seal_state = 'approved'"
    )
  )
}


# The two writes of `owned_by` that leave the owner unknown: one with no
# author, one of the channel with another field beside it, as an import made
# by hand with the channel's token would leave it.
owned_by_storte <- list(
  senza_autore = list(
    username = "", details = "owned_by = 'bruno.verdi@ubep.unipd.it'"
  ),
  con_altri_campi = list(
    username = canale, action = "Update record (API) 1",
    details = "owned_by = 'bruno.verdi@ubep.unipd.it', seal_state = 'intact'"
  )
)

test_that("una owned_by del canale scritta da sola sopra una storta stabilisce il proprietario", { # nolint: line_length_linter.
  # The log never forgets the bad write, but the owner is read from the
  # newest write the channel made through the owner door: one written above
  # it, by hand with the channel's token, is read first and the bad one is
  # never reached. The way out the SOP did not describe (open point n. 4).
  for (nome in names(owned_by_storte)) {
    storta <- owned_by_storte[[nome]]
    expect_true(
      is.na(log_owner(eventi_finti(storta, applicata), "1", creatrice, canale)),
      info = nome
    )
    eventi <- eventi_finti(passaggio(creatrice), storta, applicata)
    expect_equal(
      log_owner(eventi, "1", creatrice, canale), creatrice, info = nome
    )
    # A write that leaves the field blank names nobody, and does not hide it.
    expect_true(
      is.na(log_owner(
        eventi_finti(passaggio(""), storta, applicata), "1", creatrice, canale
      )),
      info = nome
    )
  }
})


test_that("una owned_by storta sotto il penultimo sigillo ferma la riga, per disegno", { # nolint: line_length_linter.
  # Newest first. A bad write of `owned_by` landed while a round ran, after
  # it read the log and before it wrote its seal 111111111111; the round had
  # no owner to write, so nothing of the channel stands between the two.
  # The next round found the owner unknown, and IT wrote `owned_by` alone with
  # the channel's token, above the seal. Anna then changed the role, the
  # round carried it out under 222222222222, and now she changes the
  # expiration. The owner of today is Anna; the owner of the stretch between
  # the two seals is read below 111111111111, where the bad write is the
  # newest, and no write that can still come lands there.
  #
  # Accepted on 2026-10-27: the case is rare, and the round does not guess
  # an owner the log cannot establish. The row stays held, every change of
  # it with an unknown author, for as long as the log holds the bad write.
  # The way out is to delete the row and have a referent create it again.
  for (nome in names(owned_by_storte)) {
    eventi <- eventi_finti(
      list(username = creatrice, details = "expiration = '2027-01-31'"),
      eseguita("222222222222"),
      list(username = creatrice, details = "role_name = 'read only'"),
      passaggio(creatrice),
      eseguita("111111111111"),
      owned_by_storte[[nome]],
      list(
        username = creatrice, action = "Create record 1",
        details = "record_id = '1', role_name = 'data entry'"
      )
    )
    expect_equal(log_owner(eventi, "1", creatrice, canale), creatrice)
    # The owner of the stretch below 111111111111 stays unknown, and so the
    # author of Anna's own change does too: it waits, and no later write
    # reaches the stretch to release it.
    expect_true(
      is.na(log_pending_authors(
        eventi, "1", creatrice, channel_account = canale
      )),
      info = nome
    )
  }
})


# Newest first, below what each test adds on top: Bruno changed the role,
# Anna approved 111111111111, the round passed the row to Bruno and then
# sealed it, owned_by below the seal as the round writes them.
passata <- function(...) {
  eventi_finti(
    ...,
    eseguita("111111111111"),
    passaggio("bruno.verdi@ubep.unipd.it"),
    list(username = creatrice, details = "approved_seal = '111111111111'"),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    ),
    applicata
  )
}

riga_passata <- function(...) {
  register_row(
    role_name = "read only", expiration = "2027-01-31",
    applied_seal = "111111111111", ...
  )
}

test_that("dopo il passaggio la modifica dell'ultimo non chiede approvazione", {
  eventi <- passata(list(
    username = "bruno.verdi@ubep.unipd.it",
    details = "expiration = '2027-01-31'"
  ))
  expect_false(seal_needs_approval(
    riga_passata(), eventi, creatrice, channel_account = canale
  ))
})

test_that("dopo il passaggio la modifica del creatore aspetta l'ultimo", {
  riga <- riga_passata()
  riga[["approved_seal"]] <- request_seal(riga)
  sopra <- function(chi) {
    passata(
      list(username = chi, details = "approved_seal = 'x'"),
      list(username = creatrice, details = "expiration = '2027-01-31'")
    )
  }
  expect_true(seal_needs_approval(
    riga, sopra(creatrice), creatrice, channel_account = canale
  ))
  expect_false(seal_approved(
    riga, sopra(creatrice), creatrice, channel_account = canale
  ))
  expect_true(seal_approved(
    riga, sopra("bruno.verdi@ubep.unipd.it"), creatrice,
    channel_account = canale
  ))
  expect_true(seal_approved(
    riga, sopra("it.prova@ubep.unipd.it"), creatrice,
    approvers = "it.prova@ubep.unipd.it", channel_account = canale
  ))
  # Without the configured account no owned_by is believed: Anna owns it.
  expect_false(seal_needs_approval(riga, sopra(creatrice), creatrice))
})

# A stretch of the row's life is judged with the owner who had it then, not
# with the creator: read with the creator, an approval given by the owner of
# that stretch looks like a stranger's.
test_that("il tratto prima di un passaggio si legge col proprietario di allora", { # nolint: line_length_linter.
  # Newest first. Bruno owns the row since the execution sealed
  # 111111111111; Cinzia changed it, Bruno approved 222222222222, the round
  # passed the row to Cinzia and sealed it, owned_by below the seal.
  eventi <- eventi_finti(
    eseguita("222222222222"),
    passaggio("cinzia.rossi@ubep.unipd.it"),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "approved_seal = '222222222222'"
    ),
    list(
      username = "cinzia.rossi@ubep.unipd.it",
      details = "dag_name = 'centro-02'"
    ),
    eseguita("111111111111"),
    passaggio("bruno.verdi@ubep.unipd.it"),
    list(username = creatrice, details = "approved_seal = '111111111111'"),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    ),
    applicata
  )
  # Read with the creator, Bruno's approval would be a stranger's and
  # Cinzia's change would come back uncovered, holding the row again.
  expect_equal(
    log_uncovered_authors(eventi, "1", creatrice, channel_account = canale),
    character()
  )
  expect_equal(
    log_uncovered_authors(passata(), "1", creatrice, channel_account = canale),
    character()
  )
})

test_that("dopo il passaggio la revoca del creatore e' una revoca d'altri", {
  eventi <- passata(
    list(username = creatrice, details = "request_status = 'revoked'")
  )
  expect_true(
    log_revocation_only(eventi, "1", creatrice, channel_account = canale)
  )
})

test_that("seal_approved inoltra l'account del canale al log", {
  riga <- register_row()
  riga[["approved_seal"]] <- request_seal(riga)
  approva <- function(chi) {
    list(
      username = chi,
      details = paste0("approved_seal = '", riga[["approved_seal"]], "'")
    )
  }
  # Newest first. The round passed the row to Bruno, who approves its seal.
  eventi <- eventi_finti(
    approva("bruno.verdi@ubep.unipd.it"),
    passaggio("bruno.verdi@ubep.unipd.it"), applicata
  )
  # Only with the account is the passage believed and Bruno the owner.
  expect_true(seal_approved(riga, eventi, creatrice, channel_account = canale))
  expect_false(seal_approved(riga, eventi, creatrice))

  # Anna filed the row and approved its seal; before the round ever wrote on
  # it, Bruno imported owned_by alone. With the account his import is
  # ignored and Anna's approval stands.
  importata <- eventi_finti(
    approva(creatrice),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "owned_by = 'bruno.verdi@ubep.unipd.it'"
    ),
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', role_name = 'data entry'"
    )
  )
  expect_true(
    seal_approved(riga, importata, creatrice, channel_account = canale)
  )
  expect_true(
    log_approval_stands(importata, "1", creatrice, channel_account = canale)
  )
})

# correzione 1
test_that("chi esce scrivendo durante il giro che passa la riga resta autore", {
  # Newest first. Bruno owns the row since 111111111111; Cinzia changed the
  # group, Bruno approved 222222222222, then wrote the group himself while
  # the round ran, and the round passed the row to Cinzia and sealed it.
  eventi <- eventi_finti(
    eseguita("222222222222"),
    passaggio("cinzia.rossi@ubep.unipd.it"),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "dag_name = 'centro-99'"
    ),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "approved_seal = '222222222222'"
    ),
    list(
      username = "cinzia.rossi@ubep.unipd.it",
      details = "dag_name = 'centro-02'"
    ),
    eseguita("111111111111"),
    passaggio("bruno.verdi@ubep.unipd.it"),
    list(username = creatrice, details = "approved_seal = '111111111111'"),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    ),
    applicata
  )
  riga <- register_row(
    role_name = "read only", dag_name = "centro-99",
    applied_seal = "222222222222"
  )
  # Below the seal, his write reads as the value carried out: only the
  # stretch can name it, and only with the owner of today.
  expect_equal(
    log_pending_authors(
      eventi, "1", creatrice, channel_account = canale, current = riga
    ),
    "bruno.verdi@ubep.unipd.it"
  )
  expect_true(
    seal_needs_approval(riga, eventi, creatrice, channel_account = canale)
  )
  # An approval of the seal carried out does not release the version that
  # holds Bruno's group, even from Cinzia; her approval of this one does.
  vecchia <- riga
  vecchia[["approved_seal"]] <- "222222222222"
  sua <- rbind(
    eventi_finti(list(
      username = "cinzia.rossi@ubep.unipd.it",
      details = "approved_seal = '222222222222'"
    )),
    eventi
  )
  expect_false(seal_approved(vecchia, sua, creatrice, channel_account = canale))
  nuova <- riga
  nuova[["approved_seal"]] <- request_seal(nuova)
  sua <- rbind(
    eventi_finti(list(
      username = "cinzia.rossi@ubep.unipd.it",
      details = paste0("approved_seal = '", nuova[["approved_seal"]], "'")
    )),
    eventi
  )
  expect_true(seal_approved(nuova, sua, creatrice, channel_account = canale))
})

test_that("il tratto distingue il proprietario di allora da quello di oggi", {
  # Newest first. Bruno owns the row since 111111111111; Cinzia changed the
  # group and Davide the role, Bruno approved 222222222222 over both, and the
  # round passed the row to Davide and sealed it. Read with Davide, today's
  # owner, Bruno's approval would cover nothing and Cinzia would come back.
  eventi <- eventi_finti(
    eseguita("222222222222"),
    passaggio("davide.neri@ubep.unipd.it"),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "approved_seal = '222222222222'"
    ),
    list(
      username = "davide.neri@ubep.unipd.it",
      details = "role_name = 'data entry'"
    ),
    list(
      username = "cinzia.rossi@ubep.unipd.it",
      details = "dag_name = 'centro-02'"
    ),
    eseguita("111111111111"),
    passaggio("bruno.verdi@ubep.unipd.it"),
    list(username = creatrice, details = "approved_seal = '111111111111'"),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    ),
    applicata
  )
  expect_equal(
    log_uncovered_authors(eventi, "1", creatrice, channel_account = canale),
    character()
  )
})

test_that("la modifica approvata ed eseguita passa la riga a chi l'ha scritta", { # nolint: line_length_linter.
  chi <- function(..., account = canale) {
    log_next_owner(
      eventi_finti(..., applicata), "1", creatrice,
      approvers = "it.prova@ubep.unipd.it", channel_account = account
    )
  }
  bruno <- "bruno.verdi@ubep.unipd.it"
  cinzia <- "cinzia.rossi@ubep.unipd.it"
  it <- "it.prova@ubep.unipd.it"
  ok <- list(username = creatrice, details = "approved_seal = 'x'")
  expect_equal(
    chi(ok, list(username = bruno, details = "role_name = 'a'")), bruno
  )
  # Without the configured account nobody passes the row.
  expect_equal(
    chi(ok, list(username = bruno, details = "role_name = 'a'"),
        account = NULL),
    creatrice
  )
  expect_equal(
    chi(list(username = creatrice, details = "role_name = 'a'")), creatrice
  )
  expect_equal(chi(ok, list(username = it, details = "dag_name = 'b'")), it)
  expect_equal(
    chi(ok, list(username = cinzia, details = "dag_name = 'b'"),
        list(username = bruno, details = "role_name = 'a'")),
    cinzia
  )
  expect_equal(
    chi(list(username = creatrice, details = "dag_name = 'b'"), ok,
        list(username = bruno, details = "role_name = 'a'")),
    creatrice
  )
})

test_that("una revoca, libera o approvata, non passa la riga", {
  revoca <- list(
    username = "bruno.verdi@ubep.unipd.it",
    details = "request_status = 'revoked'"
  )
  ok <- list(username = creatrice, details = "approved_seal = 'x'")
  expect_equal(
    log_next_owner(
      eventi_finti(revoca, applicata), "1", creatrice, channel_account = canale
    ),
    creatrice
  )
  expect_equal(
    log_next_owner(
      eventi_finti(ok, revoca, applicata), "1", creatrice,
      channel_account = canale
    ),
    creatrice
  )
})

test_that("chi ha scritto solo la revoca non prende la riga di un altro", {
  revoca <- list(
    username = "bruno.verdi@ubep.unipd.it",
    details = "request_status = 'revoked'"
  )
  cinzia <- list(
    username = "cinzia.rossi@ubep.unipd.it", details = "dag_name = 'b'"
  )
  ok <- list(username = creatrice, details = "approved_seal = 'x'")
  # Bruno writes last, but only the withdrawal: the row goes to Cinzia.
  expect_equal(
    log_next_owner(
      eventi_finti(ok, revoca, cinzia, applicata), "1", creatrice,
      channel_account = canale
    ),
    "cinzia.rossi@ubep.unipd.it"
  )
  # Bruno also changed the role in the same stretch: not a withdrawal alone.
  expect_equal(
    log_next_owner(
      eventi_finti(
        ok, revoca, cinzia,
        list(
          username = "bruno.verdi@ubep.unipd.it", details = "role_name = 'a'"
        ),
        applicata
      ),
      "1", creatrice, channel_account = canale
    ),
    "bruno.verdi@ubep.unipd.it"
  )
})

test_that("una modifica scoperta sotto il sigillo non e' una revoca", {
  revoca <- list(
    username = "bruno.verdi@ubep.unipd.it",
    details = "request_status = 'revoked'"
  )
  ok <- list(username = creatrice, details = "approved_seal = 'x'")
  chi <- function(sotto) {
    log_next_owner(
      eventi_finti(
        ok, revoca, applicata,
        list(username = sotto, details = "role_name = 'a'")
      ),
      "1", creatrice, channel_account = canale
    )
  }
  # Cinzia's change below the seal is in the version carried out; Bruno only
  # withdrew above it.
  expect_equal(
    chi("cinzia.rossi@ubep.unipd.it"), "cinzia.rossi@ubep.unipd.it"
  )
  # Bruno's own change below the seal makes him more than a withdrawal.
  expect_equal(chi("bruno.verdi@ubep.unipd.it"), "bruno.verdi@ubep.unipd.it")
})

test_that("dopo un passaggio la riga passa ancora a chi scrive per ultimo", {
  eventi <- passata(
    list(
      username = "bruno.verdi@ubep.unipd.it", details = "approved_seal = 'x'"
    ),
    list(username = "cinzia.rossi@ubep.unipd.it", details = "dag_name = 'b'")
  )
  expect_equal(
    log_next_owner(eventi, "1", creatrice, channel_account = canale),
    "cinzia.rossi@ubep.unipd.it"
  )
})

test_that("un log che non dice gli autori non stabilisce il proprietario", {
  eventi <- eventi_finti(
    list(username = "", details = "role_name = 'a'"), applicata
  )
  # The owner is known: it is the authors the log cannot name.
  expect_equal(log_owner(eventi, "1", creatrice, canale), creatrice)
  expect_true(
    is.na(log_next_owner(eventi, "1", creatrice, channel_account = canale))
  )
})

test_that("con l'account configurato un altro che scrive i campi del canale e' solo un autore", { # nolint: line_length_linter.
  bruno <- "bruno.verdi@ubep.unipd.it"
  eventi <- eventi_finti(
    list(
      username = bruno, details = "role_name = 'read only', outcome = 'applied'"
    ),
    list(username = creatrice, details = "expiration = '2027-01-31'"),
    applicata
  )
  # Without the account two accounts write the channel's fields and nobody
  # can be named; with it, Bruno's change of the role is his, as any other.
  expect_true(is.na(log_change_authors(eventi, "1")))
  expect_equal(
    log_change_authors(eventi, "1", channel_account = canale),
    c(bruno, creatrice)
  )
})

test_that("un referente che importa outcome e owned_by su una riga eseguita non la ferma", { # nolint: line_length_linter.
  bruno <- "bruno.verdi@ubep.unipd.it"
  # Newest first. A referent imports a CSV that carries the channel's
  # columns, with values of its own, over a row the round applied.
  eventi <- eventi_finti(
    list(
      username = bruno, timestamp = "2026-10-02 09:00",
      details = paste0("outcome = 'held', owned_by = '", bruno, "'")
    ),
    applicata
  )
  # The owner stays, nobody changed what the row asks for, and the
  # execution keeps its date.
  expect_equal(log_owner(eventi, "1", creatrice, canale), creatrice)
  expect_equal(
    log_pending_authors(eventi, "1", creatrice, channel_account = canale),
    character()
  )
  expect_equal(
    log_next_owner(eventi, "1", creatrice, channel_account = canale), creatrice
  )
  expect_equal(report_executions(eventi, "1", canale), "2026-09-01 02:45")
  # Without the account the channel cannot be told apart from the referent.
  expect_true(is.na(log_owner(eventi, "1", creatrice)))
})

test_that("con due account configurati le scritture del vecchio restano del canale", { # nolint: line_length_linter.
  vecchio <- "svc-canale-vecchio"
  bruno <- "bruno.verdi@ubep.unipd.it"
  dal_vecchio <- function(evento) {
    utils::modifyList(evento, list(username = vecchio))
  }
  # Newest first. The token's old account passed the row to Bruno and sealed
  # it, then wrote back the username on a round that held the row.
  eventi <- eventi_finti(
    dal_vecchio(list(
      action = "Update record (API) 1",
      details = "username = 'mario.rossi@ubep.unipd.it'"
    )),
    dal_vecchio(applicata),
    dal_vecchio(passaggio(bruno))
  )
  entrambi <- c(canale, " SVC-Canale-Vecchio ")
  expect_setequal(
    log_channel_accounts(eventi, "1", entrambi), c(canale, vecchio)
  )
  expect_equal(log_owner(eventi, "1", creatrice, entrambi), bruno)
  expect_equal(
    log_change_authors(eventi, "1", channel_account = entrambi), character()
  )
  # With the new account alone, the old one is another account: its passage
  # is ignored, and its write of an intent field is a change of its own.
  expect_equal(log_owner(eventi, "1", creatrice, canale), creatrice)
  expect_equal(
    log_change_authors(eventi, "1", channel_account = canale), vecchio
  )
})

test_that("l'account del canale non ammette un elenco vuoto o voci vuote", {
  eventi <- eventi_finti(applicata)
  for (account in list(character(), "", c(canale, ""), c(canale, "  "),
                       c(canale, NA), 1L)) {
    expect_error(
      log_channel_accounts(eventi, "1", account), "channel_account",
      info = format(account)
    )
  }
})

# A seal written by another account is not an execution: with the account
# configured, the last execution is the channel's newest write of the seal.
sigillo_di <- function(chi, details = "applied_seal = 'ffffffffffff'") {
  list(username = chi, details = details)
}

test_that("un sigillo scritto da un altro account non nasconde la sua modifica", { # nolint: line_length_linter.
  bruno <- "bruno.verdi@ubep.unipd.it"
  # Newest first. Bruno writes the role and a seal of his own, in one event
  # or in two.
  insieme <- eventi_finti(
    sigillo_di(
      bruno, "role_name = 'read only', applied_seal = 'ffffffffffff'"
    ),
    applicata
  )
  separati <- eventi_finti(
    sigillo_di(bruno),
    list(username = bruno, details = "role_name = 'read only'"),
    applicata
  )
  for (eventi in list(insieme, separati)) {
    expect_equal(
      log_change_authors(eventi, "1", channel_account = canale), bruno
    )
    expect_equal(
      log_pending_authors(eventi, "1", creatrice, channel_account = canale),
      bruno
    )
    expect_equal(
      log_uncovered_authors(eventi, "1", creatrice, channel_account = canale),
      character()
    )
  }
  # Without the account Bruno is a second writer of the channel's fields.
  expect_true(is.na(log_change_authors(insieme, "1")))
})

test_that("un sigillo scritto da un altro account non spende un'approvazione", {
  bruno <- "bruno.verdi@ubep.unipd.it"
  # Newest first. Bruno changed the role, Anna approved, and Bruno then
  # wrote a seal: it is no execution, and Anna's approval still stands.
  eventi <- eventi_finti(
    sigillo_di(bruno),
    list(username = creatrice, details = "approved_seal = 'x'"),
    list(username = bruno, details = "role_name = 'read only'"),
    applicata
  )
  expect_true(
    log_approval_stands(eventi, "1", creatrice, channel_account = canale)
  )
})

test_that("un sigillo scritto da un altro account non toglie il passaggio a chi ha cambiato", { # nolint: line_length_linter.
  bruno <- "bruno.verdi@ubep.unipd.it"
  ok <- list(username = creatrice, details = "approved_seal = 'x'")
  eventi <- eventi_finti(
    ok,
    sigillo_di(
      bruno, "role_name = 'read only', applied_seal = 'ffffffffffff'"
    ),
    applicata
  )
  expect_equal(
    log_next_owner(eventi, "1", creatrice, channel_account = canale), bruno
  )
})

test_that("un sigillo scritto da un altro account non nasconde la sua revoca", {
  bruno <- "bruno.verdi@ubep.unipd.it"
  eventi <- eventi_finti(
    sigillo_di(
      bruno, "request_status = 'revoked', applied_seal = 'ffffffffffff'"
    ),
    applicata
  )
  expect_true(
    log_revocation_only(eventi, "1", creatrice, channel_account = canale)
  )
})

test_that("il sigillo creduto e' l'ultimo scritto dal canale", {
  bruno <- "bruno.verdi@ubep.unipd.it"
  eventi <- eventi_finti(sigillo_di(bruno), applicata)
  expect_equal(log_channel_seal(eventi, "1", canale), "000000000000")
  expect_equal(
    log_channel_seal(eventi, "1", c("SVC-Canale-Ubep", "svc-vecchio")),
    "000000000000"
  )
  # Never sealed by the channel: a row never carried out.
  expect_equal(
    log_channel_seal(eventi_finti(sigillo_di(bruno)), "1", canale), ""
  )
  expect_error(log_channel_seal(eventi, "1", NULL))
})

test_that("il canale configurato e' assente solo da un registro gia' sigillato", { # nolint: line_length_linter.
  bruno <- "bruno.verdi@ubep.unipd.it"
  sigillato <- eventi_finti(
    list(username = bruno, details = "role_name = 'read only'"), applicata
  )
  expect_false(log_channel_absent(sigillato, canale))
  expect_false(
    log_channel_absent(sigillato, c("svc-nuovo", "SVC-Canale-Ubep"))
  )
  expect_true(log_channel_absent(sigillato, "svc-nuovo"))
  # Nothing sealed yet: no channel to have seen.
  nuovo <- eventi_finti(list(username = bruno, details = "role_name = 'x'"))
  expect_false(log_channel_absent(nuovo, "svc-nuovo"))
  expect_error(log_channel_absent(sigillato, NULL))
})

test_that("un'esecuzione ha la forma della porta dei sigilli, non un valore che la cita", { # nolint: line_length_linter.
  bruno <- "bruno.verdi@ubep.unipd.it"
  # Newest first. An outcome of the channel whose `applied_as` holds the
  # text of a seal, read back from a group name somebody chose; below it,
  # Bruno's change of the role, and the round's real execution.
  citazione <- list(
    username = canale, action = "Update record (API) 1",
    details = paste0(
      "outcome = 'applied', applied_as = 'role_name=data entry; ",
      "dag_name=applied_seal = 'ffffffffffff'; expiration='"
    )
  )
  eventi <- eventi_finti(
    citazione, list(username = bruno, details = "role_name = 'read only'"),
    applicata
  )
  # The outcome executed nothing: the seal believed is the door's, and
  # Bruno's change still stands above the last execution.
  expect_equal(log_channel_seal(eventi, "1", canale), "000000000000")
  expect_equal(log_change_authors(eventi, "1", channel_account = canale), bruno)
  # The door's own forms: the seal with its state, or the seal alone.
  for (porta in c("applied_seal = 'aaaaaaaaaaaa', seal_state = 'approved'",
                  "seal_state = 'intact', applied_seal = 'aaaaaaaaaaaa'",
                  "applied_seal = 'aaaaaaaaaaaa'")) {
    sigillata <- eventi_finti(
      list(username = canale, details = porta), applicata
    )
    expect_equal(
      log_channel_seal(sigillata, "1", canale), "aaaaaaaaaaaa", info = porta
    )
  }
})

# Newest first, below what each test adds on top: the round sealed Anna's own
# change of the role with 222222222222, and Cinzia wrote the role while that
# round ran, so below its seal, with no approval above her write.
scoperta <- function(...) {
  eventi_finti(
    ...,
    eseguita("222222222222"),
    list(
      username = "cinzia.rossi@ubep.unipd.it", details = "role_name = 'admin'"
    ),
    list(username = creatrice, details = "role_name = 'read only'"),
    applicata,
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', role_name = 'data entry'"
    )
  )
}

test_that("una scrittura scoperta che il proprietario riscrive non conta piu'", { # nolint: line_length_linter.
  cinzia <- "cinzia.rossi@ubep.unipd.it"
  # Anna changes the role and puts it back to the value carried out, so the
  # row matches the seal again and no round seals it anew; then she revokes.
  eventi <- scoperta(
    list(username = creatrice, details = "request_status = 'revoked'"),
    list(username = creatrice, details = "role_name = 'read only'"),
    list(username = creatrice, details = "role_name = 'zz'")
  )
  revocata <- register_row(role_name = "read only", request_status = "revoked")
  for (account in list(NULL, canale)) {
    # While her write is still in the row, Cinzia is uncovered.
    expect_equal(
      log_uncovered_authors(
        scoperta(), "1", creatrice, channel_account = account
      ),
      cinzia
    )
    # Written over by Anna, it is no longer part of what the round carries
    # out: read as before, it would stay uncovered for good, and the gate
    # would ask Cinzia's rights for Anna's own revocation.
    expect_equal(
      log_uncovered_authors(eventi, "1", creatrice, channel_account = account),
      character()
    )
    autori <- log_pending_authors(
      eventi, "1", creatrice, channel_account = account, current = revocata
    )
    expect_equal(autori, creatrice)
    expect_false(change_needs_approval(autori, creatrice))
  }
})

test_that("chi riscrive sopra il sigillo il valore di una scrittura scoperta ne e' autore", { # nolint: line_length_linter.
  davide <- "davide.neri@ubep.unipd.it"
  riga <- register_row(role_name = "admin")
  # Above the seal Davide moves the role and brings it to Cinzia's value,
  # over his own move or over Anna's.
  for (prima in c(davide, creatrice)) {
    eventi <- scoperta(
      list(username = davide, details = "role_name = 'admin'"),
      list(username = prima, details = "role_name = 'zz'")
    )
    for (account in list(NULL, canale)) {
      # Cinzia's write is no longer the row's, and the value below the seal
      # is hers, which no execution carried out: it is not the value carried
      # out, so Davide's write counts.
      expect_equal(
        log_uncovered_authors(
          eventi, "1", creatrice, channel_account = account
        ),
        character()
      )
      expect_equal(
        log_pending_authors(
          eventi, "1", creatrice, channel_account = account, current = riga
        ),
        davide
      )
    }
  }
  # Covered by Anna's approval, Cinzia's value was carried out with her
  # leave: a field brought back to it names nobody.
  coperta <- eventi_finti(
    list(username = davide, details = "role_name = 'admin'"),
    list(username = davide, details = "role_name = 'zz'"),
    eseguita("222222222222"),
    list(username = creatrice, details = "approved_seal = '222222222222'"),
    list(
      username = "cinzia.rossi@ubep.unipd.it", details = "role_name = 'admin'"
    ),
    applicata
  )
  expect_equal(
    log_pending_authors(
      coperta, "1", creatrice, channel_account = canale, current = riga
    ),
    character()
  )
})


# A record id used twice, newest first as REDCap answers. Id 1 was a field
# test: created, applied by the round, and changed by Bruno after its seal.
# The register was emptied on 2026-09-01, and the id came back as a request
# Anna filed. `...` is what happened to her row after it was created, newest
# first; `eseguita` says whether the round has applied it.
id_riusato <- function(..., eseguita = TRUE, cancellazione = "",
                       canale_prima = "svc-canale-ubep") {
  nuova <- c(
    list(...),
    if (eseguita) list(applicata),
    list(list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', role_name = 'data entry'"
    ))
  )
  vecchia <- list(
    list(
      username = "amministratore.prova@ubep.unipd.it",
      action = "Delete record 1", details = cancellazione
    ),
    list(
      username = "bruno.verdi@ubep.unipd.it", details = "role_name = 'admin'"
    ),
    list(
      username = canale_prima, action = "Update record (API) 1",
      details = "outcome = 'applied', applied_seal = 'eeeeeeeeeeee'"
    ),
    list(
      username = "collaudo.prova@ubep.unipd.it", action = "Create record 1",
      details = "record_id = '1', role_name = 'read only'"
    )
  )
  do.call(eventi_finti, c(nuova, vecchia))
}


test_that("la vita attuale di una riga comincia dalla sua ultima creazione", {
  # eval
  vita <- log_current_life(id_riusato())
  importata <- log_current_life(eventi_finti(
    list(username = creatrice, details = "role_name = 'read only'"),
    list(username = creatrice, action = "Create record (import) 1"),
    list(username = "collaudo.prova@ubep.unipd.it", action = "Create record 1")
  ))

  # test
  # The creation is the first event of the row that stands now, and stays.
  # What is below it, the deletion included, belonged to another row.
  expect_equal(vita[["action"]], c("Update record (API) 1", "Create record 1"))
  expect_equal(vita[["username"]], c("svc-canale-ubep", creatrice))
  # The same act from an import, measured on 2026-09-02.
  expect_equal(importata[["username"]], c(creatrice, creatrice))
})


test_that("una riga a vita unica si legge come prima", {
  # eval
  # The shape every log in this file had before ids were reused: one
  # creation, at the bottom.
  eventi <- eventi_finti(
    list(username = creatrice, details = "expiration = '2027-01-31'"),
    applicata,
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "role_name = 'read only'"
    ),
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', role_name = 'data entry'"
    )
  )
  creata <- eventi_finti(list(
    username = creatrice, action = "Create record 1",
    details = "record_id = '1', role_name = 'data entry'"
  ))

  # test
  # Nothing is cut, so every reader answers as it did before the cut.
  expect_identical(log_current_life(eventi), eventi)
  expect_identical(log_current_life(creata), creata)
  expect_equal(
    log_pending_authors(eventi, "1", creatrice),
    c(creatrice, "bruno.verdi@ubep.unipd.it")
  )
  # A row only created has its creator for author, and that is no change
  # anybody else made.
  expect_equal(log_pending_authors(creata, "1", creatrice), creatrice)
  expect_false(change_needs_approval(creatrice, creatrice, sealed = FALSE))
})


test_that("un log senza creazione si legge intero, anche con una cancellazione", { # nolint: line_length_linter.
  # eval
  # The wording of a deletion was never measured. An event that reads like
  # one, inside the row that stands now, must not cut it: below it may stand
  # a change by somebody else, and cut there that change would be carried
  # out with nobody asked.
  in_mezzo <- eventi_finti(
    list(username = creatrice, details = "expiration = '2027-01-31'"),
    list(
      username = "amministratore.prova@ubep.unipd.it",
      action = "Delete record 1", details = ""
    ),
    list(
      username = "bruno.verdi@ubep.unipd.it", details = "role_name = 'admin'"
    ),
    applicata,
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', role_name = 'data entry'"
    )
  )
  # And a log that does not hold the creation of the row that stands now,
  # or holds no creation at all, the deletion still there: purged, or
  # worded in a way nobody measured. It is read whole, as before the cut.
  senza_la_nuova <- id_riusato()[-2L, , drop = FALSE]
  senza_creazioni <- id_riusato()[-c(2L, 6L), , drop = FALSE]

  # test
  expect_identical(log_current_life(in_mezzo), in_mezzo)
  expect_true(change_needs_approval(
    log_pending_authors(in_mezzo, "1", creatrice), creatrice
  ))
  expect_identical(log_current_life(senza_la_nuova), senza_la_nuova)
  expect_identical(log_current_life(senza_creazioni), senza_creazioni)
})


test_that("una riga con l'id riusato non eredita gli autori della vita di prima", { # nolint: line_length_linter.
  # eval, test
  # Bruno changed the field test after its seal, and nobody approved it. The
  # round never carried that out, and never will: the row is gone. Read as
  # part of Anna's row, it stood in the stretch below her first execution
  # and held every change she made to her own request. With the deletion
  # logged with or without its details.
  for (cancellazione in c("", "record_id = '1'")) {
    applicata_ora <- id_riusato(cancellazione = cancellazione)
    expect_equal(log_change_authors(applicata_ora, "1"), character())
    expect_equal(
      log_uncovered_authors(applicata_ora, "1", creatrice), character()
    )
    expect_equal(
      log_pending_authors(applicata_ora, "1", creatrice), character()
    )

    # Anna changes her applied request: the change is hers alone.
    cambiata <- id_riusato(
      list(username = creatrice, details = "expiration = '2027-01-31'"),
      cancellazione = cancellazione
    )
    autori <- log_pending_authors(cambiata, "1", creatrice)
    expect_equal(autori, creatrice)
    expect_false(change_needs_approval(autori, creatrice))

    # A manager revokes it: still a revocation and nothing else.
    revocata <- id_riusato(
      list(
        username = "cinzia.rossi@ubep.unipd.it",
        details = "request_status = 'revoked'"
      ),
      cancellazione = cancellazione
    )
    expect_true(log_revocation_only(revocata, "1", creatrice))
  }
})


test_that("una richiesta nuova con l'id riusato e non ancora eseguita non aspetta nessuno", { # nolint: line_length_linter.
  # eval
  nuova <- id_riusato(eseguita = FALSE)

  # test
  # Before the cut: Anna, Bruno and whoever ran the field test, and the first
  # real request after the register was emptied held on its first round.
  autori <- log_pending_authors(nuova, "1", creatrice)
  expect_equal(autori, creatrice)
  expect_false(change_needs_approval(autori, creatrice, sealed = FALSE))
})


test_that("un'altra utenza che serviva la vita di prima non rende ignoto l'autore", { # nolint: line_length_linter.
  # eval
  # The field test ran under a different token, so the channel's fields were
  # written by a second account. Counted on the whole log, two accounts
  # write what only the channel writes, and nobody can be named.
  eventi <- id_riusato(
    list(username = creatrice, details = "expiration = '2027-01-31'"),
    canale_prima = "svc-collaudo-prova"
  )

  # test
  expect_equal(log_channel_accounts(eventi, "1"), "svc-canale-ubep")
  expect_equal(log_pending_authors(eventi, "1", creatrice), creatrice)
})


test_that("una modifica di un altro nella vita attuale ferma ancora la riga", { # nolint: line_length_linter.
  # eval
  bruno <- "bruno.verdi@ubep.unipd.it"
  cambio <- list(username = bruno, details = "role_name = 'admin'")

  # test
  # The cut takes away another row's history and nothing of this one's.
  # After the round applied Anna's row:
  dopo <- id_riusato(cambio)
  expect_equal(log_pending_authors(dopo, "1", creatrice), bruno)
  expect_true(change_needs_approval(
    log_pending_authors(dopo, "1", creatrice), creatrice
  ))

  # while the round was applying it, below its first seal and above the
  # creation, with no approval of Anna's:
  durante <- id_riusato()
  durante <- rbind(durante[1L, ], eventi_finti(cambio), durante[-1L, ])
  expect_equal(log_uncovered_authors(durante, "1", creatrice), bruno)
  expect_true(change_needs_approval(
    log_pending_authors(durante, "1", creatrice), creatrice
  ))

  # and before the round ever applied it.
  prima <- id_riusato(cambio, eseguita = FALSE)
  expect_equal(log_pending_authors(prima, "1", creatrice), c(bruno, creatrice))
  expect_true(change_needs_approval(
    log_pending_authors(prima, "1", creatrice), creatrice, sealed = FALSE
  ))
})


test_that("owner_payload porta il proprietario e nient'altro", {
  corpo <- owner_payload("1", "bruno.verdi@ubep.unipd.it")
  expect_equal(names(corpo), c("record_id", "owned_by"))
  expect_error(owner_payload("1", ""))
  expect_error(owner_payload("1", NA_character_))
})


# The log of a row in collision, newest first: Anna filed it, and the round
# wrote its verdict with the proposal it had made, signed by the account that
# holds its token. `sopra` stands above the round's write, `sotto` between the
# creation and the round's write.
collisione <- function(sopra = list(), sotto = list(),
                       proposta = "mario.rossi.2@ubep.unipd.it") {
  do.call(eventi_finti, c(
    sopra,
    list(list(
      username = "svc-canale-ubep", action = "Update record (API) 1",
      details = paste0(
        "username = '", proposta, "', identity = 'collision'"
      )
    )),
    sotto,
    list(list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', first_name = 'Mario', last_name = 'Rossi'"
    ))
  ))
}


risposta <- function(chi = creatrice,
                     valore = "mario.rossi.2@ubep.unipd.it") {
  list(username = chi, details = paste0("distinct_username = '", valore, "'"))
}


test_that("la risposta di un altro referente su una riga mai eseguita aspetta il proprietario", { # nolint: line_length_linter.
  # eval
  eventi <- collisione(sopra = list(risposta("bruno.verdi@ubep.unipd.it")))
  autori <- log_pending_authors(
    eventi, "1", creatrice, channel_account = "svc-canale-ubep",
    current = register_row(
      username = "mario.rossi.2@ubep.unipd.it",
      distinct_username = "mario.rossi.2@ubep.unipd.it"
    )
  )

  # test
  # The answer is an intent field, and whoever writes it is an author of the
  # row: an account would be made on the word of somebody the row does not
  # answer to. Anna stays an author for the fields she wrote at the creation.
  expect_equal(autori, c("bruno.verdi@ubep.unipd.it", creatrice))
  expect_true(change_needs_approval(autori, creatrice, sealed = FALSE))
})


test_that("una risposta scritta prima della proposta non vale", {
  # eval
  # Filled in when the row was filed, before anybody knew the composed name
  # was taken: whoever knows the convention of the suffixes can guess the
  # proposal without having looked at who holds the name.
  eventi <- collisione(sotto = list(risposta()))

  # test
  expect_false(log_answer_stands(
    eventi, "1", "mario.rossi.2@ubep.unipd.it",
    channel_account = "svc-canale-ubep"
  ))
  expect_false(log_answer_stands(eventi, "1", "mario.rossi.2@ubep.unipd.it"))
})


test_that("una risposta scritta dopo la proposta vale", {
  # eval
  eventi <- collisione(sopra = list(risposta()))

  # test
  # Above the round's write of the proposal, folded as the proposal is folded.
  # Without the configured account the channel is the account that wrote
  # the verdict.
  expect_true(log_answer_stands(
    eventi, "1", " Mario.Rossi.2@ubep.unipd.it",
    channel_account = "svc-canale-ubep"
  ))
  expect_true(log_answer_stands(eventi, "1", "mario.rossi.2@ubep.unipd.it"))
  # A proposal the channel never wrote, or written by somebody else, is no
  # question the answer could have come after.
  expect_false(log_answer_stands(
    eventi, "1", "mario.rossi.3@ubep.unipd.it",
    channel_account = "svc-canale-ubep"
  ))
  expect_false(log_answer_stands(
    eventi, "1", "mario.rossi.2@ubep.unipd.it",
    channel_account = "un-altro-canale"
  ))
  # Nor is a log that holds no answer at all.
  expect_false(log_answer_stands(
    collisione(), "1", "mario.rossi.2@ubep.unipd.it",
    channel_account = "svc-canale-ubep"
  ))
})


test_that("una risposta alla proposta di prima non vale per quella nuova", {
  # eval
  # The referent answered `.2`; then `.2` was taken, and the round wrote `.3`.
  prima <- collisione(
    sopra = list(
      list(
        username = "svc-canale-ubep", action = "Update record (API) 1",
        details = "username = 'mario.rossi.3@ubep.unipd.it'"
      ),
      risposta()
    )
  )
  # And then the referent pasted the new one.
  dopo <- rbind(
    eventi_finti(risposta(valore = "mario.rossi.3@ubep.unipd.it")), prima
  )

  # test
  expect_false(log_answer_stands(
    prima, "1", "mario.rossi.3@ubep.unipd.it",
    channel_account = "svc-canale-ubep"
  ))
  expect_true(log_answer_stands(
    dopo, "1", "mario.rossi.3@ubep.unipd.it",
    channel_account = "svc-canale-ubep"
  ))
})
