test_that("module_state posts to the module endpoint and parses the answer", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  captured <- NULL
  result <- httr2::with_mocked_responses(
    function(req) {
      captured <<- req
      httr2::response(status_code = 200L, body = charToRaw(body))
    },
    module_state(
      server = "redcap.example.org",
      secret = "s3cret",
      pairs = list(
        list(username = "mario.rossi@ubep.unipd.it", project_id = 27L)
      )
    )
  )

  # test
  expect_true(result[["ok"]])
  expect_match(captured[["url"]], "prefix=ubep_provisioning", fixed = TRUE)
  expect_match(captured[["url"]], "page=api", fixed = TRUE)
  expect_match(captured[["url"]], "NOAUTH", fixed = TRUE)
  expect_equal(captured[["method"]], "POST")
  expect_equal(captured[["headers"]][["X-UBEP-Secret"]], "s3cret")
})


test_that("the request travels in the body and not in the URL", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  captured <- NULL
  httr2::with_mocked_responses(
    function(req) {
      captured <<- req
      httr2::response(status_code = 200L, body = charToRaw(body))
    },
    module_state(
      "redcap.example.org", "s3cret",
      pairs = list(
        list(username = "mario.rossi@ubep.unipd.it", project_id = 27L)
      )
    )
  )
  sent <- captured[["body"]][["data"]]

  # test
  # Half the reason the contract is a POST: in a GET the UPN would land in the
  # access log of every instance, and of every proxy in between, on every run
  # of the job. Neither the identity nor the secret may appear in the URL.
  expect_false(grepl("mario.rossi", captured[["url"]], fixed = TRUE))
  expect_false(grepl("s3cret", captured[["url"]], fixed = TRUE))
  expect_equal(sent[["operation"]], "state")
  expect_equal(
    sent[["requests"]][[1]][["username"]], "mario.rossi@ubep.unipd.it"
  )
  expect_equal(sent[["requests"]][[1]][["project_id"]], 27L)
})


test_that("an empty pair list asks for the whole instance", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  captured <- NULL
  httr2::with_mocked_responses(
    function(req) {
      captured <<- req
      httr2::response(status_code = 200L, body = charToRaw(body))
    },
    module_state("redcap.example.org", "s3cret")
  )
  sent <- captured[["body"]][["data"]]

  # test
  # The audit mode. `requests` must serialize as an empty array, which is what
  # the module reads as "the whole instance".
  expect_length(sent[["requests"]], 0L)
})


test_that("an instance mounted in a subdirectory is reachable", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  captured <- NULL
  httr2::with_mocked_responses(
    function(req) {
      captured <<- req
      httr2::response(status_code = 200L, body = charToRaw(body))
    },
    module_state("redcap.example.org/redcap", "s3cret")
  )

  # test
  # The fleet is not uniform: measured on 2026-08-01, twelve instances serve
  # REDCap from the root and two serve it under /redcap/. Without a way to say
  # so, those two answer 404 and the audit calls them unreachable — "server
  # down or network" for a server that is up and merely mounted elsewhere.
  expect_match(
    captured[["url"]],
    "https://redcap.example.org/redcap/api/?",
    fixed = TRUE
  )
})


test_that("the base is normalised and never downgraded to plain HTTP", {
  # eval
  seen <- character()
  mock <- function(req) {
    seen <<- c(seen, req[["url"]])
    httr2::response(status_code = 200L, body = charToRaw("{}"))
  }
  httr2::with_mocked_responses(mock, {
    module_state("a.example.org", "s")
    module_state("b.example.org/", "s")
    module_state("https://c.example.org/redcap/", "s")
    module_state("http://d.example.org", "s")
  })

  # test
  # The spec allows TLS only, so a base handed over as http is corrected
  # rather than honoured.
  expect_true(all(startsWith(seen, "https://")))
  expect_true(startsWith(seen[[1]], "https://a.example.org/api/?"))
  expect_true(startsWith(seen[[2]], "https://b.example.org/api/?"))
  expect_true(startsWith(seen[[3]], "https://c.example.org/redcap/api/?"))
  expect_true(startsWith(seen[[4]], "https://d.example.org/api/?"))
})


test_that("the secret never appears in an error message", {
  # eval
  body <- paste0(
    '{"contract_version": 1, "errors": [',
    '{"code": "TRASPORTO_SEGRETO_RIFIUTATO", "message": "secret rejected"}]}'
  )
  result <- httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 403L, body = charToRaw(body)),
    module_state("redcap.example.org", "s3cret")
  )

  # test
  expect_false(result[["ok"]])
  expect_false(any(grepl("s3cret", unlist(result), fixed = TRUE)))
})


test_that("an unreachable server is a transport error, not a crash", {
  # eval
  result <- httr2::with_mocked_responses(
    function(req) stop("Could not resolve host"),
    module_state("redcap.example.org", "s3cret")
  )

  # test
  expect_false(result[["ok"]])
  expect_equal(result[["errors"]], "TRASPORTO_NON_RAGGIUNGIBILE")
})


test_that("an unknown fingerprint downgrades the effective gate", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  result <- httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 200L, body = charToRaw(body)),
    module_state(
      "redcap.example.org", "s3cret",
      registry = data.frame(
        redcap_major = 17L, fingerprint = "not-the-one",
        stringsAsFactors = FALSE
      )
    )
  )

  # test
  expect_equal(result[["gate"]], "non_collaudata")
})


test_that("a disabled module does not produce a gate", {
  # eval
  result <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(
        status_code = 200L,
        body = charToRaw("The module with prefix is currently disabled.")
      )
    },
    module_state("redcap.example.org", "s3cret")
  )

  # test
  # No payload means no major and no fingerprint, so any gate value here would
  # be invented. NA says "not established", which is what the audit reports.
  expect_false(result[["ok"]])
  expect_equal(result[["errors"]], "TRASPORTO_MODULO_ASSENTE")
  expect_true(is.na(result[["gate"]]))
})


test_that("module_apply sends the operation and defaults to a dry run", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  captured <- NULL
  httr2::with_mocked_responses(
    function(req) {
      captured <<- req
      httr2::response(status_code = 200L, body = charToRaw(body))
    },
    module_apply(
      "redcap.example.org", "s3cret",
      requests = list(list(
        username = "mario.rossi@ubep.unipd.it", project_id = 27L,
        role_name = "data entry", dag_name = "centro-01",
        expiration = "2027-01-01"
      ))
    )
  )
  sent <- captured[["body"]][["data"]]

  # test
  expect_equal(sent[["operation"]], "apply")
  expect_true(sent[["dry_run"]])
  expect_equal(sent[["requests"]][[1]][["role_name"]], "data entry")
})


test_that("a write must be asked for explicitly", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  sent <- NULL
  httr2::with_mocked_responses(
    function(req) {
      sent <<- req[["body"]][["data"]]
      httr2::response(status_code = 200L, body = charToRaw(body))
    },
    module_apply(
      "redcap.example.org", "s3cret", requests = list(), dry_run = FALSE
    )
  )

  # test
  # The module writes only on an explicit boolean false, so the client has to
  # send one rather than omitting the field.
  expect_false(sent[["dry_run"]])
  expect_type(sent[["dry_run"]], "logical")
})


test_that("module_revoke carries only the pair", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  sent <- NULL
  httr2::with_mocked_responses(
    function(req) {
      sent <<- req[["body"]][["data"]]
      httr2::response(status_code = 200L, body = charToRaw(body))
    },
    module_revoke(
      "redcap.example.org", "s3cret",
      requests = list(list(
        username = "mario.rossi@ubep.unipd.it", project_id = 27L,
        role_name = "data entry"
      ))
    )
  )

  # test
  # Revocation is about a pair, not about rights: sending a role would suggest
  # the call cares which one, and it does not.
  expect_equal(sent[["operation"]], "revoke")
  expect_null(sent[["requests"]][[1]][["role_name"]])
  expect_equal(sent[["requests"]][[1]][["project_id"]], 27L)
})


test_that("all three operations share one base normalisation", {
  # eval
  seen <- character()
  mock <- function(req) {
    seen <<- c(seen, req[["url"]])
    httr2::response(status_code = 200L, body = charToRaw("{}"))
  }
  httr2::with_mocked_responses(mock, {
    module_state("host.example.org/redcap", "s")
    module_apply("host.example.org/redcap", "s", requests = list())
    module_revoke("host.example.org/redcap", "s", requests = list())
  })

  # test
  expect_length(unique(seen), 1L)
  expect_true(startsWith(seen[[1]], "https://host.example.org/redcap/api/?"))
})
