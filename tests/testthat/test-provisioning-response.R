test_that("a well formed response is accepted", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-response.json")
  )
  parsed <- parse_module_response(body, status = 200L)

  # test
  expect_true(parsed[["ok"]])
  expect_equal(parsed[["errors"]], character())
  expect_equal(parsed[["payload"]][["contract_version"]], 1L)
  expect_equal(parsed[["payload"]][["version_gate"]], "collaudata")
})


test_that("a disabled module is recognized despite HTTP 200", {
  # eval
  # This is verbatim what REDCap answers for a module that is not enabled,
  # observed while dismantling the spike: status 200, plain text, no JSON.
  body <- paste(
    "The module with prefix 'ubep_provisioning' is currently disabled",
    "systemwide."
  )
  parsed <- parse_module_response(body, status = 200L)

  # test
  expect_false(parsed[["ok"]])
  expect_equal(parsed[["errors"]], "TRASPORTO_MODULO_ASSENTE")
})


test_that("a mismatched contract version is a transport error", {
  # eval
  body <- '{"contract_version": 99, "version_gate": "collaudata"}'
  parsed <- parse_module_response(body, status = 200L)

  # test
  expect_false(parsed[["ok"]])
  expect_equal(parsed[["errors"]], "TRASPORTO_CONTRATTO_DISALLINEATO")
})


test_that("a rejected secret is reported as such", {
  # eval
  body <- paste0(
    '{"contract_version": 1, "errors": [',
    '{"code": "TRASPORTO_SEGRETO_RIFIUTATO", "message": "secret rejected"}]}'
  )
  parsed <- parse_module_response(body, status = 403L)

  # test
  expect_false(parsed[["ok"]])
  expect_equal(parsed[["errors"]], "TRASPORTO_SEGRETO_RIFIUTATO")
})


test_that("an instance below the floor stays pending, not refused", {
  # eval
  body <- readr::read_file(
    testthat::test_path("fixtures", "state-below-floor.json")
  )
  parsed <- parse_module_response(body, status = 200L)

  # test
  expect_false(parsed[["ok"]])
  expect_equal(parsed[["errors"]], "TRASPORTO_VERSIONE_SOTTO_MINIMO")
  # a transport code, never a data one: the request is queued, not wrong
  expect_false(any(grepl("^DATO_", parsed[["errors"]])))
})


test_that("a body that is valid JSON but not an object is not a response", {
  # eval
  # jsonlite happily turns a bare literal into a scalar, so shape checking
  # cannot stop at "did it parse".
  bare_number <- parse_module_response("200", status = 200L)
  empty_body <- parse_module_response("", status = 200L)

  # test
  expect_false(bare_number[["ok"]])
  expect_equal(bare_number[["errors"]], "TRASPORTO_MODULO_ASSENTE")
  expect_false(empty_body[["ok"]])
  expect_equal(empty_body[["errors"]], "TRASPORTO_MODULO_ASSENTE")
})


test_that("a non-200 status with nothing reported is an internal error", {
  # eval
  # The module always names what went wrong. A status that says failure while
  # the body names no cause is the module misbehaving, not the request.
  parsed <- parse_module_response('{"contract_version": 1}', status = 500L)

  # test
  expect_false(parsed[["ok"]])
  expect_equal(parsed[["errors"]], "INTERNO")
})


test_that("a read accepts either contract version", {
  # eval
  one <- parse_module_response(
    '{"contract_version": 1, "version_gate": "collaudata"}',
    status = 200L
  )
  two <- parse_module_response(
    '{"contract_version": 2, "version_gate": "collaudata"}',
    status = 200L
  )

  # test
  # The audit exists to say what state the fleet is in, and a partial
  # deployment would blind it precisely on the instances left behind, which
  # are the only ones worth knowing about.
  expect_true(one[["ok"]])
  expect_true(two[["ok"]])
})


test_that("a write accepts only the contract that can enforce the handshake", {
  # eval
  one <- parse_module_response(
    '{"contract_version": 1, "version_gate": "collaudata"}',
    status = 200L, accepted = 2L
  )
  two <- parse_module_response(
    '{"contract_version": 2, "version_gate": "collaudata"}',
    status = 200L, accepted = 2L
  )

  # test
  expect_false(one[["ok"]])
  expect_equal(one[["errors"]], "TRASPORTO_CONTRATTO_DISALLINEATO")
  expect_true(two[["ok"]])
})


test_that("an uninterpretable contract version is a mismatch, not a crash", {
  # eval
  # as.integer("abc") is NA with a warning, and NA %in% accepted is FALSE, so
  # the branch is right by accident; asserted here so it stays right on
  # purpose.
  parsed <- parse_module_response(
    '{"contract_version": "abc"}', status = 200L
  )

  # test
  expect_false(parsed[["ok"]])
  expect_equal(parsed[["errors"]], "TRASPORTO_CONTRATTO_DISALLINEATO")
})


test_that("a coerced-looking contract version is still a mismatch", {
  # eval
  # `as.integer()` collapses a one-element list to a scalar, so a JSON array
  # `[2]` would read as 2 even though a well-formed declaration is never a
  # list. Coercion hides the shape violation instead of rejecting it.
  singleton_array <- parse_module_response(
    '{"contract_version": [2]}', status = 200L, accepted = 2L
  )
  # `as.integer()` truncates without warning, so 2.9 would read as 2 - a
  # different number pretending to be the one that was declared accepted.
  fractional <- parse_module_response(
    '{"contract_version": 2.9}', status = 200L, accepted = 2L
  )
  # `as.integer()` also coerces a numeric string silently, so "2" would read
  # as 2 - the module is expected to declare a number, not a string shaped
  # like one.
  numeric_string <- parse_module_response(
    '{"contract_version": "2"}', status = 200L, accepted = 2L
  )

  # test
  expect_false(singleton_array[["ok"]])
  expect_equal(singleton_array[["errors"]], "TRASPORTO_CONTRATTO_DISALLINEATO")
  expect_false(fractional[["ok"]])
  expect_equal(fractional[["errors"]], "TRASPORTO_CONTRATTO_DISALLINEATO")
  expect_false(numeric_string[["ok"]])
  expect_equal(numeric_string[["errors"]], "TRASPORTO_CONTRATTO_DISALLINEATO")
})
