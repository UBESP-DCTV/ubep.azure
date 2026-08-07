register_row <- function(...) {
  defaults <- list(
    record_id = "1",
    server = "edc10",
    project_id = "27",
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
  expect_equal(request[["project_id"]], "27")
  expect_equal(request[["role_name"]], "data entry")
  expect_equal(request[["dag_name"]], "centro-01")
  expect_equal(request[["contact_email"]], "mario.rossi@example.org")
  expect_equal(request[["server"]], "edc10")
})


test_that("request_from_row drops what is blank instead of carrying an empty string", {
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
    register_row(record_id = "2", project_id = "28", request_status = "revoked")
  )
  split <- register_to_desired(register)

  # test
  expect_length(split[["desired"]], 1L)
  expect_length(split[["revoked"]], 1L)
  expect_equal(split[["desired"]][[1]][["record_id"]], "1")
  expect_equal(split[["revoked"]][[1]][["record_id"]], "2")
  expect_length(split[["errors"]], 0L)
})


test_that("a row without a username is not a pair, and is not an error either", {
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


test_that("a pair present in two rows fails closed on both", {
  # eval
  register <- rbind(
    register_row(record_id = "1", role_name = "data entry"),
    register_row(record_id = "2", role_name = "read only")
  )
  split <- register_to_desired(register)

  # test
  # Guessing which row wins is what a ledger does; a register refuses. Both
  # rows carry the error, because either one of them is the mistake and there
  # is no way to tell which.
  expect_length(split[["desired"]], 0L)
  expect_setequal(names(split[["errors"]]), c("1", "2"))
  expect_equal(split[["errors"]][["1"]], "DATO_COPPIA_DUPLICATA")
  expect_equal(split[["errors"]][["2"]], "DATO_COPPIA_DUPLICATA")
})


test_that("the same person in two different projects is not a duplicate", {
  # eval
  register <- rbind(
    register_row(record_id = "1", project_id = "27"),
    register_row(record_id = "2", project_id = "28")
  )
  split <- register_to_desired(register)

  # test
  expect_length(split[["desired"]], 2L)
  expect_length(split[["errors"]], 0L)
})


test_that("the key does not collapse two different pairs", {
  # eval
  register <- rbind(
    register_row(record_id = "1", project_id = "2", username = "7a@ubep.unipd.it"),
    register_row(record_id = "2", project_id = "27", username = "a@ubep.unipd.it")
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
    register_row(record_id = "2", project_id = "28", expiration = "2020-01-01")
  )
  split <- register_to_desired(register)

  # test
  expect_length(split[["desired"]], 1L)
  expect_equal(split[["errors"]][["2"]], "DATO_SCADENZA_NON_VALIDA")
})


test_that("the last day of access is converted once, at the border", {
  # eval
  last_day <- Sys.Date() + 30L
  split <- register_to_desired(register_row(expiration = as.character(last_day)))

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
  # columns exact is the structural defence, the same shape as the planner that
  # computes without naming the write functions: it is checked, not promised.
  expect_setequal(
    names(payload),
    c("record_id", "outcome", "outcome_detail", "outcome_at", "applied_as")
  )
  expect_equal(nrow(payload), 1L)
})


test_that("outcome_payload refuses an outcome outside the vocabulary", {
  # eval / test
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
