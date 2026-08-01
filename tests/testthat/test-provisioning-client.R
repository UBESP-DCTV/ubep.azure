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
  expect_equal(sent[["requests"]][[1]][["username"]], "mario.rossi@ubep.unipd.it")
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
  # The audit mode. `requests` must serialise as an empty array, which is what
  # the module reads as "the whole instance".
  expect_length(sent[["requests"]], 0L)
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
