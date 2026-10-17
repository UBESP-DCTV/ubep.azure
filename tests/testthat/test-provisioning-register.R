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


# The round's write when it applied the row, in an earlier pass.
applicata <- list(
  username = "svc-canale-ubep", action = "Update record (API) 1",
  details = paste0(
    "outcome = 'applied', applied_seal = '000000000000', ",
    "seal_state = 'intact'"
  )
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


test_that("una owned_by scritta da un'altra utenza rende ignoto il proprietario", { # nolint: line_length_linter.
  eventi <- eventi_finti(
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "owned_by = 'cinzia.rossi@ubep.unipd.it'"
    ),
    applicata
  )
  expect_true(is.na(log_owner(eventi, "1", creatrice, canale)))
  # Without the account the ambiguity is read first, and it still holds.
  expect_true(is.na(log_owner(eventi, "1", creatrice)))
})


test_that("una scrittura del canale senza autore rende ignoto il proprietario", { # nolint: line_length_linter.
  for (chi in list("", NA_character_)) {
    eventi <- eventi_finti(
      list(username = chi, details = "owned_by = 'cinzia.rossi@ubep.unipd.it'"),
      applicata
    )
    expect_equal(log_channel_accounts(eventi, "1", canale), c(canale, chi))
    expect_true(is.na(log_owner(eventi, "1", creatrice, canale)))
  }
})


# revisione 1
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
  expect_equal(
    log_channel_accounts(eventi, "1", canale),
    c(canale, "bruno.verdi@ubep.unipd.it")
  )
  expect_true(is.na(log_owner(eventi, "1", creatrice, canale)))
  expect_true(is.na(
    log_pending_authors(eventi, "1", creatrice, channel_account = canale)
  ))
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


eseguita <- function(sigillo) {
  list(
    username = "svc-canale-ubep", action = "Update record (API) 1",
    details = paste0(
      "outcome = 'applied', applied_seal = '", sigillo,
      "', seal_state = 'approved'"
    )
  )
}

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

# revisione 2
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
  # Newest first. Anna filed the row and approved its seal; before the round
  # ever wrote on it, Bruno imported owned_by alone.
  eventi <- eventi_finti(
    list(
      username = creatrice,
      details = paste0("approved_seal = '", riga[["approved_seal"]], "'")
    ),
    list(
      username = "bruno.verdi@ubep.unipd.it",
      details = "owned_by = 'bruno.verdi@ubep.unipd.it'"
    ),
    list(
      username = creatrice, action = "Create record 1",
      details = "record_id = '1', role_name = 'data entry'"
    )
  )
  # Without the account Bruno passes for the channel and Anna's approval
  # stands; with it the log is ambiguous and the approval does not.
  expect_true(seal_approved(riga, eventi, creatrice))
  expect_false(seal_approved(riga, eventi, creatrice, channel_account = canale))
  expect_false(
    log_approval_stands(eventi, "1", creatrice, channel_account = canale)
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
