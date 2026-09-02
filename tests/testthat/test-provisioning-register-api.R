# httr2::req_body_form() percent-encodes every pre-encoded scalar at build
# time and marks the result AsIs, so that url_query_build() does not encode
# it a second time when the request is later rendered onto the wire (see
# httr2:::format_query_param(): `if (inherits(x, "AsIs")) unclass(x)`). A
# captured request therefore carries encoded, `AsIs`-classed values, and what
# these tests assert about is the value a form field will carry on the wire
# -- not httr2's own bookkeeping for getting it there -- so every read of a
# captured form field goes through this one place: drop the class, undo the
# encoding.
form_field_value <- function(value) {
  utils::URLdecode(as.character(value))
}


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
  expect_equal(
    form_field_value(captured[["body"]][["data"]][["token"]]), "t0ken"
  )
  expect_equal(
    form_field_value(captured[["body"]][["data"]][["content"]]), "record"
  )
  expect_equal(
    form_field_value(captured[["body"]][["data"]][["rawOrLabel"]]), "raw"
  )
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


test_that("the import body carries the outcome fields and nothing else", {
  # eval
  payload <- outcome_payload(
    "1", "applied",
    detail = "", at = "2026-08-14 03:00",
    applied_as = "role_name=data entry; dag_name=; expiration=2027-01-01"
  )
  intent <- cbind(payload, request_status = "revoked")

  # test
  # Decision 12 of the contract, enforced at the door instead of scanned after
  # the fact: the register holds intent and observation, and the job writes
  # only the second. Without the refusal a bug could switch off legitimate
  # requests, and nobody could tell "a person removed it" from "a bug removed
  # it".
  expect_error(
    register_import("registro.example.org", "t0ken", intent),
    "record_id, outcome"
  )
})


test_that("the import asks REDCap to overwrite the outcome fields", {
  # eval
  captured <- NULL
  payload <- rbind(
    outcome_payload("1", "applied", at = "2026-08-14 03:00"),
    outcome_payload("2", "data_error", detail = "DATO_UTENTE_NON_VALIDO",
                    at = "2026-08-14 03:00")
  )
  result <- httr2::with_mocked_responses(
    function(req) {
      captured <<- req
      httr2::response(status_code = 200L, body = charToRaw('{"count":2}'))
    },
    register_import("registro.example.org", "t0ken", payload)
  )
  sent <- captured[["body"]][["data"]]

  # test
  # `overwrite` can only blank the fields the body carries, and the body
  # carries five. With `normal` an empty applied_as would leave the previous
  # one in place, so a transport error would inherit the read-back of an
  # earlier success and read as a run that worked.
  expect_true(result[["ok"]])
  expect_equal(result[["scritte"]], 2L)
  expect_equal(form_field_value(sent[["action"]]), "import")
  expect_equal(form_field_value(sent[["overwriteBehavior"]]), "overwrite")
  expect_equal(form_field_value(sent[["forceAutoNumber"]]), "false")
  expect_false(
    grepl("request_status", form_field_value(sent[["data"]]), fixed = TRUE)
  )
  expect_true(
    grepl('"record_id":"1"', form_field_value(sent[["data"]]), fixed = TRUE)
  )
})


test_that("a write that lands on fewer records than it sent is not a success", {
  # eval
  payload <- rbind(
    outcome_payload("1", "applied", at = "2026-08-14 03:00"),
    outcome_payload("2", "applied", at = "2026-08-14 03:00")
  )
  result <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(status_code = 200L, body = charToRaw('{"count":1}'))
    },
    register_import("registro.example.org", "t0ken", payload)
  )

  # test
  # REDCap answers with what it took, and taking one of two is a partial write.
  # Reported rather than trusted, because the rows that did not land keep an
  # outcome from a previous run and would read as current.
  expect_false(result[["ok"]])
  expect_equal(result[["errors"]], "TRASPORTO_REGISTRO_SCRITTURA_PARZIALE")
  expect_equal(result[["scritte"]], 1L)
})


test_that("an empty payload writes nothing and calls nobody", {
  # eval
  called <- FALSE
  result <- httr2::with_mocked_responses(
    function(req) {
      called <<- TRUE
      httr2::response(status_code = 200L, body = charToRaw('{"count":0}'))
    },
    register_import(
      "registro.example.org", "t0ken",
      outcome_payload("1", "applied")[0, , drop = FALSE]
    )
  )

  # test
  # A quiet round is the normal case once the register is in exercise, and a
  # quiet round must not touch the register at all: an import of zero records
  # is a request REDCap has to answer, and answering it is the only thing it
  # could go wrong at.
  expect_true(result[["ok"]])
  expect_equal(result[["scritte"]], 0L)
  expect_false(called)
})


test_that("the identity import refuses a body carrying anything else", {
  # eval
  outcome <- outcome_payload("1", "applied", at = "2026-08-14 03:00")
  wider <- identity_payload("1", "", "ambiguous")
  wider[["contact_email"]] <- "mario.rossi@example.org"

  # test
  # Two doors, and neither takes the other's body. The register holds three
  # families of field -- what a person asked for, what the round resolved, what
  # happened -- and the separation is structural rather than a promise kept by
  # whoever assembles the body.
  expect_error(
    register_identity_import("registro.example.org", "t0ken", outcome),
    "record_id, username, identity"
  )
  expect_error(
    register_identity_import("registro.example.org", "t0ken", wider),
    "record_id, username, identity"
  )
  expect_error(
    register_import("registro.example.org", "t0ken", wider),
    "record_id, outcome"
  )
})


test_that("the identity import overwrites, so a false username is cleared", {
  # eval
  captured <- NULL
  payload <- rbind(
    identity_payload("1", "", "ambiguous"),
    identity_payload("2", "mario.rossi.2@ubep.unipd.it", "collision")
  )
  result <- httr2::with_mocked_responses(
    function(req) {
      captured <<- req
      httr2::response(status_code = 200L, body = charToRaw('{"count":2}'))
    },
    register_identity_import("registro.example.org", "t0ken", payload)
  )
  sent <- captured[["body"]][["data"]]

  # test
  # The reason `overwrite` is right here is not the one it is right for the
  # outcomes. The body carries the totality of what the round owns, so
  # overwriting can only blank the round's own fields -- and the blanking is
  # needed: a row that was `existing` and becomes `ambiguous`, which is the
  # renamed-login case, has to lose the username that became false rather than
  # keep it.
  expect_true(result[["ok"]])
  expect_equal(result[["scritte"]], 2L)
  expect_equal(form_field_value(sent[["overwriteBehavior"]]), "overwrite")
  expect_true(grepl(
    '"username":""', form_field_value(sent[["data"]]), fixed = TRUE
  ))
  expect_false(grepl(
    "contact_email", form_field_value(sent[["data"]]), fixed = TRUE
  ))
})


test_that("an identity write that lands on fewer records is not a success", {
  # eval
  payload <- rbind(
    identity_payload("1", "mario.rossi@ubep.unipd.it", "existing"),
    identity_payload("2", "", "absent")
  )
  result <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(status_code = 200L, body = charToRaw('{"count":1}'))
    },
    register_identity_import("registro.example.org", "t0ken", payload)
  )

  # test
  expect_false(result[["ok"]])
  expect_equal(result[["errors"]], "TRASPORTO_REGISTRO_SCRITTURA_PARZIALE")
})


test_that("an empty identity body calls nobody", {
  # eval
  called <- FALSE
  result <- httr2::with_mocked_responses(
    function(req) {
      called <<- TRUE
      httr2::response(status_code = 200L, body = charToRaw('{"count":0}'))
    },
    register_identity_import(
      "registro.example.org", "t0ken",
      identity_payload("1", "", "")[0L, , drop = FALSE]
    )
  )

  # test
  # The ordinary quiet round: nothing resolved differently, so nothing is
  # written. A call with an empty body would be a write REDCap logs as a write.
  expect_false(called)
  expect_true(result[["ok"]])
  expect_equal(result[["scritte"]], 0L)
})


test_that("the event log is asked for as a log and comes back as a frame", {
  # eval
  captured <- NULL
  body <- paste0(
    '[{"timestamp":"2026-09-01 02:45",',
    '"username":"anna.bianchi@ubep.unipd.it",',
    '"action":"Update record (API) 42",',
    '"details":"role_name = data entry","record":"42"}]'
  )
  result <- httr2::with_mocked_responses(
    function(req) {
      captured <<- req
      httr2::response(status_code = 200L, body = charToRaw(body))
    },
    register_log("registro.example.org", "t0ken", since = "2026-09-01 00:00")
  )

  # test
  # The log is the only source that says who touched a row, and it says it
  # about whoever was authenticated rather than about a field somebody typed
  # -- which is the whole reason row protection can trust it and cannot trust
  # `requested_by` alone.
  expect_true(result[["ok"]])
  expect_equal(
    form_field_value(captured[["body"]][["data"]][["content"]]), "log"
  )
  expect_equal(
    form_field_value(captured[["body"]][["data"]][["beginTime"]]),
    "2026-09-01 00:00"
  )
  expect_equal(result[["log"]][["record"]], "42")
  expect_equal(
    result[["log"]][["username"]], "anna.bianchi@ubep.unipd.it"
  )
})


test_that("an empty event log is a frame with no rows, not an absence", {
  # eval
  result <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(status_code = 200L, body = charToRaw("[]"))
    },
    register_log("registro.example.org", "t0ken", since = "2026-09-01 00:00")
  )

  # test
  # "Nobody touched anything in the window" and "the log could not be read"
  # decide opposite things: the first lets a row through unapproved, the
  # second must not. They have to be two shapes, not one empty one.
  expect_true(result[["ok"]])
  expect_equal(nrow(result[["log"]]), 0L)
})


test_that("the log window is asked for in the instance's clock, not in UTC", {
  # eval
  detto <- log_since("2026-09-01 21:03", hours = 0L)

  # test
  # Measured on 2026-09-01: a round that ran at 21:03 UTC appears in the log
  # at 23:03. Handing the round's own stamp straight through would ask for a
  # window shifted by two hours in summer and one in winter -- a discrepancy
  # that is not a constant, so it cannot be corrected by a constant either.
  expect_equal(detto, "2026-09-01 23:03")
})


test_that("the log window reaches back far enough to be wrong about the hour", {
  # eval
  detto <- log_since("2026-09-01 21:03", hours = 24L)

  # test
  # The margin is what makes the conversion above a convenience rather than a
  # load-bearing assumption: an hour out in either direction still leaves the
  # window covering every round since yesterday. A log window is cheap to
  # widen, and the filtering that decides anything is done on the rows.
  expect_equal(detto, "2026-08-31 23:03")
})


test_that("the creation log is asked for as creations only, without a window", {
  # eval
  captured <- NULL
  body <- paste0(
    '[{"timestamp":"2026-03-26 23:21",',
    '"username":"anna.bianchi@ubep.unipd.it",',
    '"action":"Create record (import) 20",',
    '"details":"record_id = \'20\', server = \'edc05\'","record":"20"}]'
  )
  result <- httr2::with_mocked_responses(
    function(req) {
      captured <<- req
      httr2::response(status_code = 200L, body = charToRaw(body))
    },
    register_log("registro.example.org", "t0ken", logtype = "record_add")
  )

  # test
  # Two properties, and the round needs both. `logtype` makes REDCap classify
  # the event instead of this package reading the prose of `action`: measured
  # on 2026-09-02, a creation reads `Create record 7` from the form and
  # `Create record (import) 20` from an import, and a reader that matched the
  # string would have to keep up with REDCap's wording for ever.
  #
  # And no window at all, which is what makes one call per round enough. A
  # record is created once, so the answer holds one row per record that ever
  # existed -- it grows with the register and not with the traffic, while a
  # window would lose the creation of every row filed before yesterday.
  expect_true(result[["ok"]])
  expect_equal(
    form_field_value(captured[["body"]][["data"]][["content"]]), "log"
  )
  expect_equal(
    form_field_value(captured[["body"]][["data"]][["logtype"]]), "record_add"
  )
  expect_null(captured[["body"]][["data"]][["beginTime"]])
  expect_equal(result[["log"]][["record"]], "20")
})
