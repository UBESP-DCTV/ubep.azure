# httr2::req_body_form() percent-encodes every pre-encoded scalar at build
# time and marks the result AsIs (see the same helper in
# test-provisioning-register-api.R). The register travels form-encoded, so
# every field the register double dispatches on -- `content`, `action`,
# and the `data` payload of an import -- has to be read through this one
# place. The module travels JSON-encoded and is not affected: `operation` and
# `dry_run` on an instance request compare directly.
form_field_value <- function(value) {
  utils::URLdecode(as.character(value))
}


# One mock stands in for both adapters and dispatches on the URL: the register
# speaks to /api/ with a token in the body, the instances to the module
# endpoint. Keeping a single mock is what lets a test assert "no write ever
# left this machine" — two separate doubles could each only speak for
# themselves.
inviate <- list()


canale_mock <- function(registro, istanza) {
  function(req) {
    # A mock lives inside httr2's request loop, so this is the one place the
    # captured wire log has to reach out of its own call frame.
    inviate[[length(inviate) + 1L]] <<- req # nolint: assignment_linter.
    body <- if (grepl("prefix=ubep_provisioning", req[["url"]], fixed = TRUE)) {
      istanza(req[["body"]][["data"]])
    } else {
      registro(req[["body"]][["data"]])
    }
    httr2::response(status_code = 200L, body = charToRaw(body))
  }
}


scritture <- function() {
  Filter(function(req) {
    data <- req[["body"]][["data"]]
    isFALSE(data[["dry_run"]]) &&
      isTRUE(data[["operation"]] %in% c("apply", "revoke"))
  }, inviate)
}


importazioni <- function() {
  Filter(function(req) {
    identical(form_field_value(req[["body"]][["data"]][["action"]]), "import")
  }, inviate)
}


dizionario_json <- function() {
  packaged <- register_dictionary(c("edc10", "edc12"))
  blank <- function(values) {
    values <- as.character(values)
    values[is.na(values)] <- ""
    values
  }
  as.character(jsonlite::toJSON(
    lapply(seq_len(nrow(packaged)), function(i) {
      list(
        field_name = blank(packaged[["Variable / Field Name"]])[[i]],
        field_type = blank(packaged[["Field Type"]])[[i]],
        select_choices_or_calculations =
          blank(packaged[["Choices, Calculations, OR Slider Labels"]])[[i]],
        field_annotation = blank(packaged[["Field Annotation"]])[[i]]
      )
    }),
    auto_unbox = TRUE
  ))
}


registro_doppio <- function(records) {
  function(data) {
    if (identical(form_field_value(data[["content"]]), "metadata")) {
      return(dizionario_json())
    }
    if (identical(form_field_value(data[["action"]]), "import")) {
      sent <- jsonlite::fromJSON(
        form_field_value(data[["data"]]), simplifyVector = FALSE
      )
      return(paste0('{"count":', length(sent), "}"))
    }
    records
  }
}


record_json <- function(...) {
  rows <- list(...)
  as.character(jsonlite::toJSON(lapply(rows, function(row) {
    defaults <- list(
      record_id = "1", server = "edc10", project_id = "9003",
      username = "mario.rossi@ubep.unipd.it",
      contact_email = "mario.rossi@example.org",
      role_name = "data entry", dag_name = "", expiration = "",
      requested_by = "anna.bianchi@ubep.unipd.it",
      request_status = "active",
      outcome = "", outcome_detail = "", outcome_at = "", applied_as = ""
    )
    defaults[names(row)] <- row
    defaults
  }), auto_unbox = TRUE))
}


# The instance answers a `state` with the rows it was configured with, and an
# `apply`/`revoke` with one entry per request it actually received — which is
# what the module does, and what lets the round map an entry back to the
# record that asked for it. A double that echoed a fixed list instead would
# keep passing after that mapping broke.
istanza_doppia <- function(..., contract = 3L) {
  rows <- lapply(list(...), function(row) {
    defaults <- list(
      username = "anna.bianchi@ubep.unipd.it", project_id = 9003L,
      role_name = NULL, dag_name = NULL, expiration = NULL, user_rights = 1L
    )
    defaults[names(row)] <- row
    defaults
  })

  function(data) {
    results <- if (identical(data[["operation"]], "state")) {
      rows
    } else {
      lapply(data[["requests"]] %||% list(), function(request) {
        revoking <- identical(data[["operation"]], "revoke")
        list(
          username = request[["username"]],
          project_id = as.integer(request[["project_id"]]),
          outcome = if (revoking) "revocato" else "creato",
          before = list(role_name = NULL, dag_name = NULL, expiration = NULL),
          after = if (revoking) {
            list(role_name = NULL, dag_name = NULL, expiration = NULL)
          } else {
            list(
              role_name = request[["role_name"]],
              dag_name = request[["dag_name"]],
              expiration = request[["expiration"]]
            )
          },
          errors = list()
        )
      })
    }

    as.character(jsonlite::toJSON(list(
      contract_version = contract,
      redcap_version = "17.3.3", redcap_major = 17L,
      module_version = "0.10.0", version_gate = "collaudata",
      surface_fingerprint = "16faf46d5ab1",
      allowlist_fingerprint = "aabbccddeeff",
      dry_run = data[["dry_run"]],
      results = results, summary = list(), errors = list()
    ), auto_unbox = TRUE, null = "null"))
  }
}


# The only double that changes when it is written to. A write is meant to be
# followed by a read-back, so a fixture whose reality never moves cannot tell
# the difference between "read it back" and "reported what it intended". Used
# below to exercise exactly that discipline: the round has to see the second
# state read differ from the first before it can call anything applied. The
# grown row's expiration is one the apply request never carried -- REDCap can
# accept a value and store another, and a test whose grown row only ever
# echoed back what was asked would pass just as well built from the write
# response's own plan as from a genuine re-read.
istanza_che_scrive <- function() {
  written <- FALSE
  requester <- list(
    username = "anna.bianchi@ubep.unipd.it", project_id = 9003L,
    role_name = NULL, dag_name = NULL, expiration = NULL, user_rights = 1L
  )

  function(data) {
    if (identical(data[["operation"]], "apply") && isFALSE(data[["dry_run"]])) {
      written <<- TRUE
    }
    rows <- list(requester)
    if (written) {
      rows[[2]] <- list(
        username = "mario.rossi@ubep.unipd.it", project_id = 9003L,
        role_name = "data entry", dag_name = NULL, expiration = "2027-01-01",
        user_rights = 0L
      )
    }
    do.call(istanza_doppia, rows)(data)
  }
}


giro <- function(registro, istanza, ...) {
  inviate <<- list() # nolint: assignment_linter.
  httr2::with_mocked_responses(
    canale_mock(registro, istanza),
    provisioning_reconcile(
      register_url = "registro.example.org",
      register_token = "t0ken",
      hosts = c(edc10 = "edc10.example.org", edc12 = "edc12.example.org"),
      secrets = c(edc10 = "s3cret", edc12 = "s3cret"),
      instances = c("edc10", "edc12"),
      at = "2026-08-14 03:00",
      ...
    )
  )
}


test_that("the job never writes on a row the gate did not pass", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(
      list(username = "anna.bianchi@ubep.unipd.it", user_rights = 0L)
    ),
    dry_run = FALSE
  )

  # test
  # The guard this whole cycle owes the design. The requester is a user of the
  # project and cannot manage its users, so they could not have granted this
  # access by hand — and the channel must not become the way they can. Asserted
  # on the wire and not on a branch: nothing that writes left this machine.
  expect_length(scritture(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "DATO_AMBITO_NON_AUTORIZZATO"
  )
})


test_that("a project_id that is not a number is named, not turned into a scope refusal", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(record_json(
      list(record_id = "1", username = "", project_id = "9003abc")
    )),
    istanza_doppia(list())
  )

  # test
  # Without this the row reaches the gate, matches no granted key, and comes
  # back "you may not ask for that project" — a sentence the referent can only
  # act on by requesting a permission they already have. The row is not a pair
  # (no username yet, which is the ordinary state in this version), so nothing
  # upstream validated it.
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "DATO_PROGETTO_INESISTENTE"
  )
})


test_that("a decimal project_id is named, not coerced into a real one", {
  # eval
  esito <- giro(
    registro_doppio(record_json(
      list(record_id = "1", username = "", project_id = "9003.7")
    )),
    istanza_doppia(list())
  )

  # test
  # as.integer("9003.7") is 9003L, not NA, so is.na() alone lets it through
  # as if 9003 had been asked for -- and 9003 exists in the fixture, so the
  # row would reach the gate and come back a scope refusal on a project
  # nobody asked about. The digit check is what still names it a data error.
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "DATO_PROGETTO_INESISTENTE"
  )
})


test_that("an instance that did not answer is not asked the gate's question", {
  # eval
  inviate <<- list()
  esito <- httr2::with_mocked_responses(
    function(req) {
      inviate[[length(inviate) + 1L]] <<- req
      if (grepl("prefix=ubep_provisioning", req[["url"]], fixed = TRUE)) {
        stop("Could not resolve host")
      }
      httr2::response(
        status_code = 200L,
        body = charToRaw(registro_doppio(record_json(list()))(
          req[["body"]][["data"]]
        ))
      )
    },
    provisioning_reconcile(
      "registro.example.org", "t0ken",
      hosts = c(edc10 = "edc10.example.org"),
      secrets = c(edc10 = "s3cret"),
      instances = c("edc10", "edc12"), at = "2026-08-14 03:00"
    )
  )

  # test
  # Writing this as a data error would tell a referent "you are not authorized"
  # when the truth is "I could not ask". The row stays in the desired state and
  # the next round picks it up, which is what a transport error means.
  expect_equal(esito[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_NON_RAGGIUNGIBILE"
  )
})


test_that("a module too old to report the permission puts the row back in the queue", { # nolint: line_length_linter.
  # eval
  vecchia <- function(data) {
    body <- istanza_doppia(list())(data)
    parsed <- jsonlite::fromJSON(body, simplifyVector = FALSE)
    parsed[["results"]] <- lapply(parsed[["results"]], function(row) {
      row[["user_rights"]] <- NULL
      row
    })
    as.character(jsonlite::toJSON(parsed, auto_unbox = TRUE, null = "null"))
  }
  esito <- giro(registro_doppio(record_json(list())), vecchia, dry_run = FALSE)

  # test
  # Measured on 2026-08-14: on 0.9.1 the field comes back on zero rows out of
  # seventeen. The instance answered, but not this question — and the gate
  # interrogates answers, never absences. IT gets the copy of the alert, which
  # is what puts the cause in front of somebody who can remove it.
  expect_length(scritture(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_AMBITO_NON_LEGGIBILE"
  )
})


test_that("a server the channel does not serve is a transport error", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list(record_id = "1", server = "edc07"))),
    istanza_doppia(list())
  )

  # test
  # The register offers thirteen instances and the module is on three. A row
  # for one of the other ten is not a badly filled request: it is a thing the
  # channel cannot do yet, and saying so keeps it pending instead of closing it
  # against whoever asked.
  expect_equal(esito[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_ISTANZA_SENZA_MODULO"
  )
})


test_that("a drifted dictionary stops the round before it reads a record", {
  # eval
  storto <- function(data) {
    if (identical(form_field_value(data[["content"]]), "metadata")) {
      parsed <- jsonlite::fromJSON(dizionario_json(), simplifyVector = FALSE)
      parsed <- lapply(parsed, function(field) {
        if (identical(field[["field_name"]], "outcome")) {
          field[["field_annotation"]] <- ""
        }
        field
      })
      return(as.character(jsonlite::toJSON(parsed, auto_unbox = TRUE)))
    }
    registro_doppio(record_json(list()))(data)
  }
  esito <- giro(storto, istanza_doppia(list()))

  # test
  # A `@READONLY` that fell means a requester may have typed `applied` into the
  # outcome, so the register could be carrying a success nobody produced —
  # exactly the field the round is about to read to decide it has nothing to
  # do. Nothing is read and nothing is written.
  expect_true(esito[["fermato"]])
  expect_true(esito[["schema"]][["blocks"]])
  expect_length(importazioni(), 0L)
  expect_equal(nrow(esito[["esiti"]]), 0L)
})


test_that("an extra field on the form is reported and stops nothing", {
  # eval
  in_piu <- function(data) {
    if (identical(form_field_value(data[["content"]]), "metadata")) {
      parsed <- jsonlite::fromJSON(dizionario_json(), simplifyVector = FALSE)
      parsed[[length(parsed) + 1L]] <- list(
        field_name = "note_interne", field_type = "notes",
        select_choices_or_calculations = "", field_annotation = ""
      )
      return(as.character(jsonlite::toJSON(parsed, auto_unbox = TRUE)))
    }
    registro_doppio(record_json(list()))(data)
  }
  esito <- giro(in_piu, istanza_doppia(list()))

  # test
  expect_false(esito[["fermato"]])
  expect_equal(
    esito[["schema"]][["tolerated"]], "DIZIONARIO_CAMPO_IN_PIU:note_interne"
  )
})


test_that("a request in scope is simulated and never written", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list())
  )
  simulate <- Filter(function(req) {
    identical(req[["body"]][["data"]][["operation"]], "apply")
  }, inviate)

  # test
  # Rollout point 1 is "dry_run only, over everything", and this is what the
  # referents read before anything writes: what would happen, in their own row.
  expect_length(scritture(), 0L)
  expect_length(simulate, 1L)
  expect_true(simulate[[1]][["body"]][["data"]][["dry_run"]])
  expect_equal(esito[["esiti"]][["outcome"]], "simulated")
})


test_that("an instance that echoes an entry nobody asked for does not abort the round", { # nolint: line_length_linter.
  # eval
  # The key that maps an echoed entry back to its record_id is rebuilt from
  # what the instance reports, with no normalization -- so one entry more
  # than was sent, for a pair the batch never carried, is not exotic. The
  # lookup this reads from has to answer "not mine" instead of raising: a
  # named atomic vector's `[[` throws "subscript out of bounds" on a miss,
  # which would abort the round and lose every outcome it had already
  # computed, for every instance, before anything reached the register.
  rumorosa <- function(data) {
    body <- istanza_doppia(list())(data)
    if (!identical(data[["operation"]], "apply")) {
      return(body)
    }
    parsed <- jsonlite::fromJSON(body, simplifyVector = FALSE)
    parsed[["results"]][[length(parsed[["results"]]) + 1L]] <- list(
      username = "estranea@ubep.unipd.it", project_id = 9099L,
      outcome = "creato",
      before = list(role_name = NULL, dag_name = NULL, expiration = NULL),
      after = list(
        role_name = "data entry", dag_name = NULL, expiration = NULL
      ),
      errors = list()
    )
    as.character(jsonlite::toJSON(parsed, auto_unbox = TRUE, null = "null"))
  }
  esito <- giro(registro_doppio(record_json(list())), rumorosa)

  # test
  # One row went in, one row must come out: the extra entry is ignored, not
  # merged into a row, and its presence must not keep the real one from
  # being reported either.
  expect_equal(nrow(esito[["esiti"]]), 1L)
  expect_equal(esito[["esiti"]][["outcome"]], "simulated")
})


test_that("no record is written twice in one round", {
  # eval
  esito <- giro(
    registro_doppio(record_json(
      list(record_id = "1", username = ""),
      list(record_id = "2", server = "edc07"),
      list(record_id = "3", expiration = "1999-01-01")
    )),
    istanza_doppia(list())
  )

  # test
  # A row can meet more than one verdict in one round — a form error and then
  # its instance being unreachable — and the register takes one outcome per
  # record. Two rows with the same record_id in one import body is a write
  # whose result depends on the order REDCap happens to apply them in.
  expect_false(any(duplicated(esito[["esiti"]][["record_id"]])))
})


test_that("a row still waiting for an identity gets no outcome at all", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list(record_id = "1", username = ""))),
    istanza_doppia(list())
  )

  # test
  # It is not a pair yet (decision 9), so there is nothing to report. Writing
  # `pending` into it every night would be the noise the alert exists to stand
  # out from.
  expect_equal(nrow(esito[["esiti"]]), 0L)
  expect_length(importazioni(), 0L)

  # The claim has to hold when the instance is down too, not only on the
  # happy path: a row that is not a pair was never in `wanted` or `revoked`,
  # so there is nothing for an unreachable instance to have failed at either.
  # Before restricting the transport outcome to actionable record ids, `ids`
  # was every register row for the server, and this row collected
  # TRASPORTO_NON_RAGGIUNGIBILE regardless of never having been asked for.
  inviate <<- list() # nolint: assignment_linter.
  fermo <- httr2::with_mocked_responses(
    function(req) {
      inviate[[length(inviate) + 1L]] <<- req # nolint: assignment_linter.
      if (grepl("prefix=ubep_provisioning", req[["url"]], fixed = TRUE)) {
        stop("Could not resolve host")
      }
      httr2::response(
        status_code = 200L,
        body = charToRaw(registro_doppio(record_json(
          list(record_id = "1", username = "")
        ))(req[["body"]][["data"]]))
      )
    },
    provisioning_reconcile(
      "registro.example.org", "t0ken",
      hosts = c(edc10 = "edc10.example.org"),
      secrets = c(edc10 = "s3cret"),
      instances = c("edc10", "edc12"), at = "2026-08-14 03:00"
    )
  )
  expect_equal(nrow(fermo[["esiti"]]), 0L)
})


test_that("a real write is followed by a read-back, and applied_as comes from it", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_che_scrive(),
    dry_run = FALSE
  )
  riletture <- Filter(function(req) {
    identical(req[["body"]][["data"]][["operation"]], "state")
  }, inviate)

  # test
  # `applied` has to mean "read back", not "no error returned": an outcome that
  # only said the second would be the same thing as the four spike cases that
  # reported true while doing something else. So the round asks twice — once to
  # plan, once to see — and the second read is what applied_as carries. The
  # expiration asserted here is one the apply request never sent: only a
  # genuine re-read can produce it, never the write response's own plan.
  expect_length(scritture(), 1L)
  expect_length(riletture, 2L)
  expect_equal(esito[["esiti"]][["outcome"]], "applied")
  expect_match(esito[["esiti"]][["applied_as"]], "expiration=2027-01-01")
})


test_that("a write that cannot be read back is not called applied", {
  # eval
  inviate <<- list()
  letture <- 0L
  esito <- httr2::with_mocked_responses(
    function(req) {
      inviate[[length(inviate) + 1L]] <<- req
      data <- req[["body"]][["data"]]
      if (grepl("prefix=ubep_provisioning", req[["url"]], fixed = TRUE)) {
        if (identical(data[["operation"]], "state")) {
          letture <<- letture + 1L
          if (letture > 1L) stop("Could not resolve host")
        }
        return(httr2::response(
          status_code = 200L,
          body = charToRaw(istanza_doppia(list())(data))
        ))
      }
      httr2::response(
        status_code = 200L,
        body = charToRaw(registro_doppio(record_json(list()))(data))
      )
    },
    provisioning_reconcile(
      "registro.example.org", "t0ken",
      hosts = c(edc10 = "edc10.example.org"),
      secrets = c(edc10 = "s3cret"),
      instances = c("edc10", "edc12"), at = "2026-08-14 03:00",
      dry_run = FALSE
    )
  )

  # test
  # The write may well have landed. What is missing is the evidence, and
  # `applied` is a claim about evidence. The row goes back in the queue and the
  # next round re-applies it, which is harmless: the diff finds it conforming
  # and classifies it noop.
  expect_equal(esito[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_RILETTURA_FALLITA"
  )
  expect_equal(esito[["esiti"]][["applied_as"]], "")
})


test_that("two projects on one instance are two writes, never one", {
  # eval
  esito <- giro(
    registro_doppio(record_json(
      list(record_id = "1", project_id = "9003"),
      list(record_id = "2", project_id = "9004")
    )),
    # The requester manages both projects, or the gate would refuse the second
    # row and there would be one write to count instead of two.
    istanza_doppia(list(project_id = 9003L), list(project_id = 9004L)),
    dry_run = FALSE
  )
  progetti <- lapply(scritture(), function(req) {
    unique(vapply(
      req[["body"]][["data"]][["requests"]],
      function(r) as.integer(r[["project_id"]]), integer(1)
    ))
  })

  # test
  # api.php refuses a mixed-project write with 400 and INTERNO, before touching
  # anything. A job that took that refusal would look like a broken instance,
  # and the diagnosis would start from the wrong end.
  expect_length(scritture(), 2L)
  expect_true(all(vapply(progetti, length, integer(1)) == 1L))
})


test_that("a diff miss does not leak into to_apply through an index shift", { # nolint: line_length_linter.
  # eval
  # provisioning_diff() always emits a row per desired entry -- see its own
  # union() of keys -- so a key miss cannot happen through the real diff, and
  # this cannot be reached honestly by feeding it a crafted register. Reached
  # here instead by mocking provisioning_diff() itself, the one seam that can
  # produce what a miss looks like to provisioning_reconcile(), without
  # touching the function under test.
  testthat::local_mocked_bindings(
    provisioning_diff = function(desired, actual) {
      # Only the second entry gets a row -- the first is the miss acted()
      # will find no key for.
      second <- desired[[2]]
      data.frame(
        username = as.character(second[["username"]]),
        project_id = as.integer(second[["project_id"]]),
        action = "aggiornato",
        stringsAsFactors = FALSE
      )
    }
  )

  esito <- giro(
    registro_doppio(record_json(
      list(record_id = "1", project_id = "9003"),
      list(record_id = "2", project_id = "9004")
    )),
    istanza_doppia(list(project_id = 9003L), list(project_id = 9004L))
  )
  simulate <- Filter(function(req) {
    identical(req[["body"]][["data"]][["operation"]], "apply")
  }, inviate)

  # test
  # base::Filter() is unlist(lapply()) followed by x[which(ind)]: a
  # logical(0) element does not drop its own slot, it shifts every index
  # after it. The first entry (project 9003) is the miss; the second
  # (project 9004) is the one the mocked diff calls "aggiornato". The batch
  # has to carry only the second -- never the miss, and never both.
  expect_length(simulate, 1L)
  progetti <- unique(vapply(
    simulate[[1]][["body"]][["data"]][["requests"]],
    function(r) as.integer(r[["project_id"]]), integer(1)
  ))
  expect_equal(progetti, 9004L)
})


test_that("an apply the re-read never shows is not called applied", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    dry_run = FALSE
  )

  # test
  # The write came back with no error code -- exactly the shape of the spike
  # cases that reported success while doing something else. `istanza_doppia`
  # is a stateless double: its `state` answer never grows to include the pair
  # an `apply` just claimed to create, because nothing actually moved. The
  # cause is ours to chase, not the requester's, so the row returns to the
  # queue instead of closing on a claim nobody verified.
  expect_equal(esito[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_SCRITTURA_NON_CONFERMATA"
  )
})


test_that("a revoke the re-read still shows is not called applied", {
  # eval
  esito <- giro(
    registro_doppio(record_json(
      list(record_id = "1", request_status = "revoked")
    )),
    istanza_doppia(
      list(),
      list(username = "mario.rossi@ubep.unipd.it", project_id = 9003L)
    ),
    dry_run = FALSE
  )

  # test
  # The revoke's own response can say "revocato" with no error and still be
  # wrong: `istanza_doppia`'s `state` answer keeps reporting the pair it was
  # configured with regardless of what was written, so the re-read finds
  # exactly what the revoke was supposed to remove. Confirmation for a revoke
  # means absence, and absence is exactly what did not happen here.
  expect_equal(esito[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_SCRITTURA_NON_CONFERMATA"
  )
})


test_that("a simulated write carries the module's own intention in applied_as", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list())
  )

  # test
  # A dry run changes nothing on the instance, so there is nothing to read
  # back: applied_as has to come from what the module says it would have
  # done, not from a state nobody wrote.
  expect_equal(esito[["esiti"]][["outcome"]], "simulated")
  expect_match(esito[["esiti"]][["applied_as"]], "role_name=data entry")
})
