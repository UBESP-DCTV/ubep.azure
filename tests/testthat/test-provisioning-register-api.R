test_that("the export posts to the API endpoint with the token in the body", {
  # eval
  captured <- NULL
  body <- paste0(
    '[{"record_id":"1","server":"edc10","project_id":"9003",',
    '"username":"mario.rossi@ubep.unipd.it","request_status":"active"}]'
  )
  result <- httr2::with_mocked_responses(
    function(req) {
      captured <<- req
      httr2::response(status_code = 200L, body = charToRaw(body))
    },
    register_records("registro.example.org", "t0ken")
  )

  # test
  # Same discipline as the module client: nothing that identifies anybody may
  # travel in the URL, because the URL lands in the access log of the instance
  # and of every proxy in between. The token is the sharper case — it is a
  # credential, and a credential in a log is a credential to rotate.
  expect_true(result[["ok"]])
  expect_equal(captured[["method"]], "POST")
  expect_equal(captured[["url"]], "https://registro.example.org/api/")
  expect_false(grepl("t0ken", captured[["url"]], fixed = TRUE))
  expect_equal(captured[["body"]][["data"]][["token"]], "t0ken")
  expect_equal(captured[["body"]][["data"]][["content"]], "record")
  expect_equal(captured[["body"]][["data"]][["rawOrLabel"]], "raw")
  expect_equal(result[["records"]][["server"]], "edc10")
  expect_type(result[["records"]][["project_id"]], "character")
})


test_that("a rejected token is a transport error and never echoes the token", {
  # eval
  result <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(
        status_code = 403L,
        body = charToRaw('{"error":"You do not have permissions t0ken"}')
      )
    },
    register_records("registro.example.org", "t0ken")
  )

  # test
  # The message is the server's prose and is carried for diagnosis, but the
  # token is scrubbed out of it first. REDCap does not echo it today; a client
  # that relied on that would be trusting the other end to keep our secret.
  expect_false(result[["ok"]])
  expect_equal(result[["errors"]], "TRASPORTO_REGISTRO_RIFIUTATO")
  expect_false(any(grepl("t0ken", unlist(result), fixed = TRUE)))
})


test_that("an unreachable register is a transport error, not a crash", {
  # eval
  result <- httr2::with_mocked_responses(
    function(req) stop("Could not resolve host"),
    register_records("registro.example.org", "t0ken")
  )

  # test
  expect_false(result[["ok"]])
  expect_equal(result[["errors"]], "TRASPORTO_REGISTRO_NON_RAGGIUNGIBILE")
})


test_that("a page that is not JSON is recognized by its shape", {
  # eval
  result <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(
        status_code = 200L,
        body = charToRaw("<html><body>Log in</body></html>")
      )
    },
    register_records("registro.example.org", "t0ken")
  )

  # test
  # An instance whose API is switched off answers 200 with a page, exactly as a
  # disabled module answers 200 with a sentence. A client that inferred success
  # from the status would fail inside the JSON parser, reporting an error that
  # does not name the cause.
  expect_false(result[["ok"]])
  expect_equal(result[["errors"]], "TRASPORTO_REGISTRO_RISPOSTA_INATTESA")
})


test_that("an object where an array belongs is not a record set", {
  # eval
  result <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(status_code = 200L, body = charToRaw('{"count":3}'))
    },
    register_records("registro.example.org", "t0ken")
  )

  # test
  # Valid JSON, parses fine, and would become a one-row register made out of a
  # message. The shape check is what stops it.
  expect_false(result[["ok"]])
  expect_equal(result[["errors"]], "TRASPORTO_REGISTRO_RISPOSTA_INATTESA")
})


test_that("an empty register is an empty frame, not an error", {
  # eval
  result <- httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 200L, body = charToRaw("[]")),
    register_records("registro.example.org", "t0ken")
  )

  # test
  # Measured on 2026-08-14: the register holds zero records. A round that
  # treated that as a fault would be red from the day it was installed.
  expect_true(result[["ok"]])
  expect_equal(nrow(result[["records"]]), 0L)
})


test_that("the live dictionary is read into the shape the comparison expects", {
  # eval
  packaged <- register_dictionary(c("edc05", "edc10"))
  blank <- function(values) {
    values <- as.character(values)
    values[is.na(values)] <- ""
    values
  }
  payload <- lapply(seq_len(nrow(packaged)), function(i) {
    list(
      field_name = blank(packaged[["Variable / Field Name"]])[[i]],
      field_type = blank(packaged[["Field Type"]])[[i]],
      select_choices_or_calculations =
        blank(packaged[["Choices, Calculations, OR Slider Labels"]])[[i]],
      field_annotation = blank(packaged[["Field Annotation"]])[[i]]
    )
  })
  body <- as.character(jsonlite::toJSON(payload, auto_unbox = TRUE))

  answer <- httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 200L, body = charToRaw(body)),
    register_metadata("registro.example.org", "t0ken")
  )
  verdict <- compare_dictionary(answer[["dictionary"]], c("edc05", "edc10"))

  # test
  # REDCap has two names for the same schema — the CSV's "Variable / Field
  # Name" and the API's field_name — so a map between them is unavoidable
  # here. This is the test that makes the map verifiable instead of trusted:
  # the packaged dictionary, sent back through the API's own vocabulary, has
  # to compare as conforming. A wrong key produces a difference, loudly.
  expect_true(answer[["ok"]])
  expect_true(verdict[["conforms"]])
  expect_equal(verdict[["differences"]], character(0))
})
