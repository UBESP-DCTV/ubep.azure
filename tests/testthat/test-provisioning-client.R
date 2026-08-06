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


test_that("the base is normalized and never downgraded to plain HTTP", {
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
  # rather than honored.
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


test_that("all three operations share one base normalization", {
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


test_that("a write against a contract 1 module is refused", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  result <- httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 200L, body = charToRaw(body)),
    module_apply(
      "redcap.example.org", "s3cret",
      requests = list(list(
        username = "mario.rossi@ubep.unipd.it", project_id = 27L
      )),
      dry_run = FALSE
    )
  )

  # test
  # A module that predates the handshake cannot enforce it, so a write must
  # fail closed against it. The same module answers reads normally.
  expect_false(result[["ok"]])
  expect_equal(result[["errors"]], "TRASPORTO_CONTRATTO_DISALLINEATO")
})


test_that("a read against a contract 1 module still answers", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  result <- httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 200L, body = charToRaw(body)),
    module_state(
      "redcap.example.org", "s3cret",
      pairs = list(
        list(username = "mario.rossi@ubep.unipd.it", project_id = 27L)
      )
    )
  )

  # test
  expect_true(result[["ok"]])
})


test_that("a dry run is a read for contract purposes", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  result <- httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 200L, body = charToRaw(body)),
    module_apply(
      "redcap.example.org", "s3cret",
      requests = list(list(
        username = "mario.rossi@ubep.unipd.it", project_id = 27L
      ))
    )
  )

  # test
  # Rollout point 1 is "dry_run only, over everything": a simulation that
  # refused to answer on the instances still to be upgraded would cancel the
  # step that exists to look before touching.
  expect_true(result[["ok"]])
})


test_that("the declared fingerprints travel as an array, never as a scalar", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response-v2.json")
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
        username = "mario.rossi@ubep.unipd.it", project_id = 27L
      )),
      dry_run = FALSE,
      declare = "16faf46d5ab1"
    )
  )
  # The mock intercepts the request before req_body_apply() builds the wire
  # body, so captured$body$data is still the R list: re-serializing it here
  # with our own jsonlite::toJSON() would test that re-serialization, not
  # what httr2::req_body_json(auto_unbox = TRUE) actually sends. req_dry_run()
  # renders the real bytes offline, without performing the request.
  sent <- paste(
    capture.output(httr2::req_dry_run(captured, quiet = FALSE)),
    collapse = "\n"
  )

  # test
  # The registry holds a single row today, so the declaration is a character
  # vector of length one, and auto_unbox turns those into scalars. The module
  # would then receive "16faf46d5ab1" instead of ["16faf46d5ab1"], and
  # in_array() with a non-array haystack is a fatal TypeError in PHP 8: HTTP
  # 500, no JSON, and a client that recognizes a response by its shape
  # reporting the module as absent.
  # req_dry_run() pretty-prints the body (one key per line, two-space
  # indent), so the match tolerates whitespace around the bracketed value
  # instead of requiring it adjacent, which a fixed-string match against the
  # hand-serialized body did not need to.
  expect_match(
    sent, '"tested_fingerprints":\\s*\\[\\s*"16faf46d5ab1"\\s*\\]'
  )
  # The direct cause, asserted next to its consequence: auto_unbox unboxes a
  # length-one atomic vector and leaves a list alone, so the type of what
  # `module_call()` puts in the body is what decides array versus scalar.
  expect_type(captured[["body"]][["data"]][["tested_fingerprints"]], "list")
})


test_that("an empty declaration still travels as an array", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response-v2.json")
  )
  captured <- NULL
  httr2::with_mocked_responses(
    function(req) {
      captured <<- req
      httr2::response(status_code = 200L, body = charToRaw(body))
    },
    module_state("redcap.example.org", "s3cret", declare = character())
  )

  # test
  # expect_length(NULL, 0L) passes, so length alone is not a guard: the
  # branch this test fears -- "if the list is empty, omit the field" --
  # would leave it green. Assert instead that the field *exists* and that it
  # is a list, which is what decides array versus scalar.
  expect_true(
    "tested_fingerprints" %in% names(captured[["body"]][["data"]])
  )
  expect_type(captured[["body"]][["data"]][["tested_fingerprints"]], "list")
  expect_length(captured[["body"]][["data"]][["tested_fingerprints"]], 0L)
})
