test_that("the audit reports drift per server", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  result <- httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 200L, body = charToRaw(body)),
    provisioning_audit(
      servers = c("a.example.org", "b.example.org"),
      secrets = c(a.example.org = "s1", b.example.org = "s2"),
      desired = list()
    )
  )

  # test
  expect_setequal(
    unique(result[["server"]]), c("a.example.org", "b.example.org")
  )
  expect_true(all(result[["gate"]] %in% c("collaudata", "non_collaudata")))
})


test_that("an unreachable server does not stop the audit", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  result <- httr2::with_mocked_responses(
    function(req) {
      if (grepl("down", req[["url"]], fixed = TRUE)) stop("unreachable")
      httr2::response(status_code = 200L, body = charToRaw(body))
    },
    provisioning_audit(
      servers = c("up.example.org", "down.example.org"),
      secrets = c(up.example.org = "s1", down.example.org = "s2"),
      desired = list()
    )
  )

  # test
  # One server being down must not hide the state of the others: the audit
  # reports the failure as a row rather than raising.
  expect_true("down.example.org" %in% result[["server"]])
  expect_true("up.example.org" %in% result[["server"]])
  expect_true(
    any(result[["errors"]] == "TRASPORTO_NON_RAGGIUNGIBILE", na.rm = TRUE)
  )
})


test_that("the audit reports the set of majors in the fleet", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  result <- httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 200L, body = charToRaw(body)),
    provisioning_audit(
      servers = "a.example.org",
      secrets = c(a.example.org = "s1"),
      desired = list()
    )
  )

  # test
  expect_true("redcap_major" %in% names(result))
  expect_equal(unique(result[["redcap_major"]]), 17L)
})


test_that("the audit surfaces access nobody asked for", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  result <- httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 200L, body = charToRaw(body)),
    provisioning_audit(
      servers = "a.example.org",
      secrets = c(a.example.org = "s1"),
      desired = list()
    )
  )

  # test
  # Nothing is wanted and three rights exist: the first of the three drifts the
  # audit exists to make visible.
  expect_equal(nrow(result), 3L)
  expect_true(all(result[["action"]] == "revocato"))
})


test_that("a request wanted and present is a noop, and stays one", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  desired <- list(list(
    server = "a.example.org",
    username = "ciccio.pasticcio@example.org", project_id = 16L,
    role_name = "data entry", dag_name = "centro-01",
    expiration = "2026-12-31"
  ))
  result <- httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 200L, body = charToRaw(body)),
    provisioning_audit(
      servers = "a.example.org",
      secrets = c(a.example.org = "s1"),
      desired = desired
    )
  )
  wanted_user <- "ciccio.pasticcio@example.org"
  matched <- result[result[["username"]] == wanted_user, ]

  # test
  # Invariant 4 seen from the audit: what is already right must read as noop,
  # or every run would propose to rewrite the whole fleet.
  expect_equal(nrow(matched), 1L)
  expect_equal(matched[["action"]], "noop")
})


test_that("desired rows are matched to their own server", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  desired <- list(list(
    server = "b.example.org",
    username = "ciccio.pasticcio@example.org", project_id = 16L,
    role_name = "data entry", dag_name = "centro-01",
    expiration = "2026-12-31"
  ))
  result <- httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 200L, body = charToRaw(body)),
    provisioning_audit(
      servers = "a.example.org",
      secrets = c(a.example.org = "s1"),
      desired = desired
    )
  )

  # test
  # The same username may exist on several instances with different rights.
  # A request meant for another server must not silence a drift here.
  expect_true(all(result[["action"]] == "revocato"))
})
