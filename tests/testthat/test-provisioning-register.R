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
