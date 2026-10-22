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


# One mock stands in for all three adapters and dispatches on the URL: the
# register speaks to /api/ with a token in the body, the instances to the
# module endpoint, Microsoft Graph to its own host. Keeping a single mock is
# what lets a test assert "no write ever left this machine" — three separate
# doubles could each only speak for themselves.
inviate <- list()


canale_mock <- function(registro, istanza, directory, creazione) {
  function(req) {
    # A mock lives inside httr2's request loop, so this is the one place the
    # captured wire log has to reach out of its own call frame.
    inviate[[length(inviate) + 1L]] <<- req # nolint: assignment_linter.
    if (grepl("graph.example.org", req[["url"]], fixed = TRUE)) {
      # The sweep and the creation share a host and are told apart by their
      # method, which is also how a test says "nothing was created" without
      # having to say "nothing spoke to Graph" -- the sweep speaks every round.
      if (identical(req[["method"]], "POST")) {
        return(creazione(req))
      }
      return(httr2::response(
        status_code = 200L, body = charToRaw(directory())
      ))
    }
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


# Everything the round sent to an instance, whatever it asked for. The
# distinction from `scritture()` is what lets a test say "this row was never
# even looked up", which is the claim the identity gate makes.
interrogazioni <- function() {
  Filter(function(req) {
    grepl("prefix=ubep_provisioning", req[["url"]], fixed = TRUE)
  }, inviate)
}


# The register now takes two kinds of import through the same API call, and
# they must stay tellable apart on the wire: what the round resolved about who
# a row means, and what happened to it. `campi` is how a test names which one
# it is asking about, and passing none keeps the old meaning, any import at
# all.
importazioni <- function(campi = NULL) {
  Filter(function(req) {
    data <- req[["body"]][["data"]]
    if (!identical(form_field_value(data[["action"]]), "import")) {
      return(FALSE)
    }
    if (is.null(campi)) {
      return(TRUE)
    }
    sent <- jsonlite::fromJSON(
      form_field_value(data[["data"]]), simplifyVector = FALSE
    )
    length(sent) > 0L && setequal(names(sent[[1]]), campi)
  }, inviate)
}


# What the register was actually told about the identities, as a frame. A test
# that asserted only on what the round returned would be reading the round's
# own account of itself.
identita_scritte <- function() {
  bodies <- lapply(
    importazioni(c("record_id", "username", "identity")),
    function(req) {
      jsonlite::fromJSON(
        form_field_value(req[["body"]][["data"]][["data"]]),
        simplifyVector = TRUE
      )
    }
  )
  if (length(bodies) == 0L) {
    return(NULL)
  }
  do.call(rbind, bodies)
}


# What the register was actually told about the seals, as a frame. A third
# door beside the outcome and the identity, and separate for the reason the
# other two are separate: the seal must never ride with an outcome. An outcome
# body carrying a seal column would rewrite the seal on every outcome -- and a
# `data_error` on an already applied row would blank it, quietly taking the
# protection off the one kind of row that has it.
sigilli_scritti <- function() {
  bodies <- lapply(
    importazioni(c("record_id", "applied_seal", "seal_state")),
    function(req) {
      jsonlite::fromJSON(
        form_field_value(req[["body"]][["data"]][["data"]]),
        simplifyVector = TRUE
      )
    }
  )
  if (length(bodies) == 0L) {
    return(NULL)
  }
  do.call(rbind, bodies)
}


# What the register was actually told about the row owners, as a frame: the
# fourth door, which carries `owned_by` and nothing else.
proprietari_scritti <- function() {
  corpi <- lapply(importazioni(c("record_id", "owned_by")), function(req) {
    jsonlite::fromJSON(
      form_field_value(req[["body"]][["data"]][["data"]]),
      simplifyVector = TRUE
    )
  })
  if (length(corpi) == 0L) NULL else do.call(rbind, corpi)
}


# One directory record, in the shape Graph puts on the wire. `auto_unbox` makes
# a length-one value a scalar, which is how Graph writes it, and `I()` is what
# keeps `otherMails` an array even when it holds exactly one address.
graph_user <- function(...) {
  utils::modifyList(
    list(
      id = "00000000-0000-0000-0000-000000000001",
      userPrincipalName = "mario.rossi@ubep.unipd.it",
      givenName = "Mario",
      surname = "Rossi",
      mail = NULL,
      otherMails = I(character()),
      officeLocation = "mario.rossi@example.org",
      jobTitle = NULL,
      createdDateTime = "2026-01-01T00:00:00Z",
      accountEnabled = TRUE,
      userType = "Member"
    ),
    list(...)
  )
}


# The tenant a round sweeps. The default holds exactly the person the default
# register row names, so a test that is not about the identity gets a row that
# resolves and reaches the instance, which is what every test written before
# this step assumed without being able to say so.
directory_doppia <- function(...) {
  users <- list(...)
  if (length(users) == 0L) {
    users <- list(graph_user())
  }
  function() {
    as.character(jsonlite::toJSON(list(value = users), auto_unbox = TRUE))
  }
}


# A tenant that holds nobody. Not an error and not the same as a sweep that
# failed: every row resolves `absent`, which is the verdict that would open the
# creation branch.
directory_vuota <- function() {
  function() '{"value":[]}'
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


# `eventi` defaults to an empty log rather than to no answer at all: a round
# that could not read the log and a round that read an empty one decide
# opposite things, and every test written before row protection existed means
# the second.
# `creazioni` defaults to "every row was created by whoever it names as its
# requester", which is what a row filed from the form actually looks like:
# `@USERNAME` fills that field in with the account REDCap authenticated, so
# the two agree. A test about the forgery is a test where they disagree, and
# it says so by passing `creazioni` itself.
# `proprietari` is the answer to the owners' log, `logtype = "record"`, and
# defaults to the creations alone: a log where the channel never wrote
# `owned_by`, so every row belongs to whoever created it.
registro_doppio <- function(records, eventi = "[]", creazioni = NULL,
                            proprietari = NULL) {
  if (is.null(creazioni)) {
    righe <- tryCatch(
      jsonlite::fromJSON(records, simplifyVector = FALSE),
      error = function(e) list()
    )
    creazioni <- as.character(jsonlite::toJSON(
      lapply(righe, function(riga) {
        list(
          timestamp = "2026-08-14 01:00",
          username = riga[["requested_by"]] %||% "",
          action = paste0("Create record ", riga[["record_id"]] %||% ""),
          details = "",
          record = riga[["record_id"]] %||% ""
        )
      }),
      auto_unbox = TRUE
    ))
  }
  if (is.null(proprietari)) {
    proprietari <- creazioni
  }
  function(data) {
    if (identical(form_field_value(data[["content"]]), "metadata")) {
      return(dizionario_json())
    }
    if (identical(form_field_value(data[["content"]]), "log")) {
      if (identical(form_field_value(data[["logtype"]] %||% ""), "record")) {
        return(proprietari)
      }
      # The two log questions are not the same question, and a double that
      # answered both from one fixture would let a test about edits quietly
      # stand in for a test about creations. `logtype` is what tells them
      # apart on the wire, so it is what tells them apart here.
      if (!is.null(data[["logtype"]])) {
        return(creazioni)
      }
      return(eventi)
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


# The defaults of an exported row, reachable on their own so a test can build
# the frame the register will hold and not only the JSON it answers with.
record_default <- function(row) {
  # `username` and `identity` are blank, which is the ordinary state of a
  # freshly filed row and what the work instruction asks for: the round fills
  # them in from the tenant. A fixture that carried the UPN would be a row
  # that had already been resolved, and would test the round against its own
  # output instead of against what a referent writes.
  defaults <- list(
    record_id = "1", server = "edc10", project_id = "9003",
    username = "", identity = "",
    first_name = "Mario", last_name = "Rossi",
    contact_email = "mario.rossi@example.org",
    role_name = "data entry", dag_name = "", expiration = "",
    requested_by = "anna.bianchi@ubep.unipd.it", owned_by = "",
    request_status = "active",
    outcome = "", outcome_detail = "", outcome_at = "", applied_as = "",
    applied_seal = "", seal_state = "", approved_seal = ""
  )
  defaults[names(row)] <- row
  defaults
}


record_json <- function(...) {
  as.character(jsonlite::toJSON(
    lapply(list(...), record_default), auto_unbox = TRUE
  ))
}


# The row as the register will hold it once this round has written back what
# it resolved -- which is what the seal has to be computed from.
riga_come_registro <- function(...) {
  as.data.frame(record_default(list(...)), stringsAsFactors = FALSE)
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
#
# `richiedenti` manage the project, one state row each with User Rights; the
# gate judges whoever wrote what the round carries out, so a test about a
# change by somebody other than the owner names them here. `senza_diritti` are
# users of the project who do not manage it.
istanza_che_scrive <- function(richiedenti = "anna.bianchi@ubep.unipd.it",
                               senza_diritti = character()) {
  written <- FALSE
  utente <- function(chi, diritti) {
    list(
      username = chi, project_id = 9003L,
      role_name = NULL, dag_name = NULL, expiration = NULL,
      user_rights = diritti
    )
  }
  requesters <- c(
    lapply(richiedenti, utente, diritti = 1L),
    lapply(senza_diritti, utente, diritti = 0L)
  )

  function(data) {
    if (identical(data[["operation"]], "apply") && isFALSE(data[["dry_run"]])) {
      written <<- TRUE
    }
    rows <- requesters
    if (written) {
      rows[[length(rows) + 1L]] <- list(
        username = "mario.rossi@ubep.unipd.it", project_id = 9003L,
        role_name = "data entry", dag_name = NULL, expiration = "2027-01-01",
        user_rights = 0L
      )
    }
    do.call(istanza_doppia, rows)(data)
  }
}


# Everything the round sent to Graph asking it to make somebody exist.
creazioni <- function() {
  Filter(function(req) {
    grepl("graph.example.org", req[["url"]], fixed = TRUE) &&
      identical(req[["method"]], "POST")
  }, inviate)
}


creazione_riuscita <- function() {
  function(req) {
    httr2::response(
      status_code = 201L,
      headers = list(`Content-Type` = "application/json"),
      body = charToRaw('{"id":"00000000-0000-0000-0000-00000000000a"}')
    )
  }
}


# `channel_account` is the account `registro_con_log()` signs the round's
# writes with; a test that wants the package without it passes `NULL`.
giro <- function(registro,
                 istanza,
                 directory = directory_doppia(),
                 creazione = creazione_riuscita(),
                 channel_account = "svc-canale-ubep",
                 ...) {
  inviate <<- list() # nolint: assignment_linter.
  httr2::with_mocked_responses(
    canale_mock(registro, istanza, directory, creazione),
    provisioning_reconcile(
      register_url = "registro.example.org",
      register_token = "t0ken",
      hosts = c(edc10 = "edc10.example.org", edc12 = "edc12.example.org"),
      secrets = c(edc10 = "s3cret", edc12 = "s3cret"),
      graph_token = "gr4ph",
      graph_url = "graph.example.org/v1.0",
      instances = c("edc10", "edc12"),
      channel_account = channel_account,
      at = "2026-08-14 03:00",
      ...
    )
  )
}


# An instance that cannot be reached at all. Written as a double rather than as
# a mock of its own so that Graph and the register keep being served from the
# one place they are served from everywhere else.
istanza_muta <- function() {
  function(data) stop("Could not resolve host")
}


# An instance that answers the planning read and loses the one that follows a
# write. The counter is what makes the two reads distinguishable: `applied` is
# a claim about the second, and there is no other way to take it away.
istanza_senza_rilettura <- function() {
  letture <- 0L
  function(data) {
    if (identical(data[["operation"]], "state")) {
      letture <<- letture + 1L # nolint: assignment_linter.
      if (letture > 1L) stop("Could not resolve host")
    }
    istanza_doppia(list())(data)
  }
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
  esito <- giro(registro_doppio(record_json(list())), istanza_muta())

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


test_that("a permission unreadable on one row alone also queues the row", { # nolint: line_length_linter.
  # eval
  senza_valore <- function(data) {
    body <- istanza_doppia(list())(data)
    parsed <- jsonlite::fromJSON(body, simplifyVector = FALSE)
    parsed[["results"]] <- lapply(parsed[["results"]], function(row) {
      # `[` with list(NULL) keeps the key and empties the value; `[[<- NULL`
      # would delete it, which is the *other* fault — the one above, where the
      # module never reports the field at all.
      row["user_rights"] <- list(NULL)
      row
    })
    as.character(jsonlite::toJSON(parsed, auto_unbox = TRUE, null = "null"))
  }
  esito <- giro(
    registro_doppio(record_json(list())), senza_valore, dry_run = FALSE
  )

  # test
  # One granularity below the test above, and the same rule: the instance
  # answered and this row's permission is not an answer. A role deleted
  # underneath a row reads as null, and calling that "not authorized" sends a
  # referent who may well hold the permission to argue about an authorization
  # nobody can see. It is a refusal either way — what changes is who is told
  # and whether the row comes back.
  expect_length(scritture(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_PERMESSO_NON_LEGGIBILE"
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
  # Three projects rather than one, because the resolution now fills the same
  # UPN into every row that names the same person: two rows on one project
  # would be a duplicated pair, which is a fourth verdict and not the one this
  # test is about.
  esito <- giro(
    registro_doppio(record_json(
      list(record_id = "1", project_id = "9003"),
      list(record_id = "2", server = "edc07", project_id = "9004"),
      list(record_id = "3", project_id = "9005", expiration = "1999-01-01")
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


test_that("the round fills the username from the tenant and the row becomes a pair", { # nolint: line_length_linter.
  # eval
  esito <- giro(registro_doppio(record_json(list())), istanza_doppia(list()))
  scritte <- identita_scritte()
  chieste <- Filter(function(req) {
    identical(req[["body"]][["data"]][["operation"]], "apply")
  }, inviate)

  # test
  # What the whole sub-project is for. The referent leaves `username` blank,
  # which is what the work instruction asks of them; the round resolves who the
  # row means against the tenant, writes the canonical UPN beside the verdict
  # that authorizes it, and only then is there a pair to act on. Before this
  # the row simply sat there, because the channel's only test of a pair was
  # whether somebody had typed a name into the form.
  expect_equal(scritte[["identity"]], "existing")
  expect_equal(scritte[["username"]], "mario.rossi@ubep.unipd.it")
  expect_length(chieste, 1L)
  expect_equal(
    chieste[[1]][["body"]][["data"]][["requests"]][[1]][["username"]],
    "mario.rossi@ubep.unipd.it"
  )
  expect_equal(esito[["esiti"]][["outcome"]], "simulated")
})


test_that("an identity nobody confirmed keeps the row away from every instance", { # nolint: line_length_linter.
  # eval
  # A namesake is enough, and it is the criterion of 2026-08-15: an account
  # carrying this surname whose contact address is not the one given. Nothing
  # here can tell "the same person, with an address we did not know" from
  # "somebody else with the same name", and only the referent can.
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_doppia(graph_user(officeLocation = "altro.rossi@example.org"))
  )

  # test
  # The gate is what this task exists to install, and this is the claim it
  # makes: not "the write was refused" but "the instance was never asked". A
  # row whose identity nobody has confirmed is not a pair, so there is nothing
  # to look up and nothing to compare against.
  expect_length(interrogazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "DATO_RECAPITO_NON_IDENTIFICA"
  )
  expect_equal(identita_scritte()[["identity"]], "ambiguous")
  expect_equal(identita_scritte()[["username"]], "")
})


test_that("a collision stops the row and leaves the proposal where a person reads it", { # nolint: line_length_linter.
  # eval
  # Under the surname criterion a collision is no longer a namesake — that is
  # caught earlier and comes back `ambiguous`. What is left is crooked data in
  # the tenant: an account whose UPN reads `mario.rossi` while its surname says
  # somebody else, so the UPN this row would compose is taken by a record that
  # does not answer to the name.
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_doppia(graph_user(
      givenName = "Anna", surname = "Bianchi",
      officeLocation = "anna.bianchi@example.org"
    ))
  )

  # test
  # The proposal goes into the register beside the verdict, which is decision
  # 11: without it the row hands a person two questions and no material. The
  # gate still stops it — a proposal is not a confirmation — and the code is
  # the one sub-project 5 will write the message from.
  expect_length(interrogazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "DATO_IDENTITA_IN_COLLISIONE"
  )
  expect_equal(identita_scritte()[["identity"]], "collision")
  expect_equal(
    identita_scritte()[["username"]], "mario.rossi.2@ubep.unipd.it"
  )
})


test_that("a deactivated account keeps the row away from the instance and passes it to IT", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_doppia(graph_user(accountEnabled = FALSE))
  )

  # test
  # The person exists and cannot sign in: no right is granted, so no access
  # message leaves, and nobody is created in their place. The row waits under
  # a `TRASPORTO_` code, which mails the referent with IT in copy and comes
  # back by itself once IT has reactivated the account. The channel enables
  # nothing: the only call to Graph is the sweep.
  expect_length(interrogazioni(), 0L)
  expect_length(creazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_ACCOUNT_DISATTIVATO"
  )
  expect_equal(identita_scritte()[["identity"]], "disabled")
  expect_equal(
    identita_scritte()[["username"]], "mario.rossi@ubep.unipd.it"
  )
})


test_that("a revocation still reaches the instance when the account is deactivated", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(record_json(list(request_status = "revoked"))),
    istanza_doppia(
      list(),
      list(username = "mario.rossi@ubep.unipd.it", project_id = 9003L)
    ),
    directory_doppia(graph_user(accountEnabled = FALSE))
  )
  revoche <- Filter(function(req) {
    identical(req[["body"]][["data"]][["operation"]], "revoke")
  }, interrogazioni())

  # test
  # Taking a right away does not need the person to sign in. Stopped at the
  # gate, the revocation would leave the right in REDCap with nothing in the
  # channel able to remove it, which is not what happened while a deactivated
  # account still read as `existing`.
  expect_equal(identita_scritte()[["identity"]], "disabled")
  expect_length(revoche, 1L)
  expect_equal(
    revoche[[1]][["body"]][["data"]][["requests"]][[1]][["username"]],
    "mario.rossi@ubep.unipd.it"
  )
  expect_equal(esito[["esiti"]][["outcome"]], "simulated")
})


test_that("an absence leaves the row pending and mails nobody about it", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_vuota()
  )

  # test
  # An empty tenant is not a failed sweep: it answered, and what it said is
  # "nobody is there". `absent` is the one verdict the round acts on by itself,
  # so closing the row as a data error would mail a referent about something
  # nobody has to touch — which is how an alert stops being read.
  #
  # The instance **is** asked, and that is the difference `absent` makes among
  # the three verdicts the gate holds back: the question is about the
  # requester's rights, not about the person, and the answer is what decides
  # whether anybody may be made to exist. What must not happen is a write, and
  # a simulated round does not create either.
  expect_gt(length(interrogazioni()), 0L)
  expect_length(scritture(), 0L)
  expect_length(creazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "pending")
  expect_equal(esito[["esiti"]][["outcome_detail"]], "")
  expect_equal(identita_scritte()[["identity"]], "absent")
})


test_that("a row the resolution stopped reports the reason, and sheds the username it had", { # nolint: line_length_linter.
  # eval
  # A row that resolved on some earlier round and whose contact address has
  # since been emptied. The register therefore carries a username and a verdict
  # this round can no longer stand behind.
  esito <- giro(
    registro_doppio(record_json(list(
      contact_email = "",
      username = "mario.rossi@ubep.unipd.it", identity = "existing"
    ))),
    istanza_doppia(list())
  )

  # test
  # The resolution's own code travels through instead of a generic summary: a
  # row stopped before any verdict already knows exactly what is wrong with it,
  # and `DATO_RECAPITO_ASSENTE` is a sentence the referent can act on in one
  # gesture. And the empty verdict is written, not skipped: it is what takes
  # away the username the row earned back when it still resolved, which is the
  # value that has become false.
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_equal(esito[["esiti"]][["outcome_detail"]], "DATO_RECAPITO_ASSENTE")
  expect_equal(identita_scritte()[["identity"]], "")
  expect_equal(identita_scritte()[["username"]], "")
})


test_that("a row stopped before any verdict keeps the username its filer typed", { # nolint: line_length_linter.
  # eval
  # The mirror of the test above, and the half that was missing. There the row
  # carried a verdict, so its username was the round's own writing and had to
  # go with it. Here nothing has ever resolved this row, so what sits in the
  # field is what the referent typed -- an address in the domain that is not
  # the contact address, also in the domain, which decision 12 refuses.
  esito <- giro(
    registro_doppio(record_json(list(
      contact_email = "spike.uno@ubep.unipd.it",
      username = "altro.utente@ubep.unipd.it"
    ))),
    istanza_doppia(list()),
    directory_doppia(graph_user(
      userPrincipalName = "spike.uno@ubep.unipd.it",
      givenName = "Spike", surname = "Uno",
      officeLocation = "spike.uno@example.org"
    ))
  )

  # test
  # Nothing is written back at all, and that is the property rather than a
  # side effect: the row is already where the resolution leaves it, so there is
  # no change to import. Before this the round emptied the field every pass and
  # then read its own emptiness back as a blank the referent had left, which is
  # how one row collected two different diagnoses without anybody touching it.
  expect_null(identita_scritte())
  expect_length(interrogazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "DATO_RECAPITO_INTERNO_DIVERGENTE"
  )
})


test_that("the gate reads the verdict the round just computed, never the stored one", { # nolint: line_length_linter.
  # eval
  # Decision 2, and the reason the resolution is a step of this round rather
  # than a job of its own: the register says this row was resolved four hours
  # ago and the tenant now says it is ambiguous.
  esito <- giro(
    registro_doppio(record_json(list(identity = "existing"))),
    istanza_doppia(list()),
    directory_doppia(graph_user(officeLocation = "altro.rossi@example.org"))
  )

  # test
  # A round that gated on the stored value would act on a verdict nobody
  # confirmed this pass — and on a failed sweep, on one nobody confirmed at
  # all. It is also the renamed-login case of sub-project 6 seen from here: the
  # row was `existing` and stops being so, and detecting that is all this
  # sub-project owes it.
  expect_length(interrogazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_equal(identita_scritte()[["identity"]], "ambiguous")
})


test_that("an identity that did not move is not written back", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list(
      username = "mario.rossi@ubep.unipd.it", identity = "existing"
    ))),
    istanza_doppia(list())
  )

  # test
  # The same filter the outcomes have had since the beginning, over the other
  # family of fields: without it every quiet night rewrites every row, and the
  # register's Logging — which is where this project keeps the history of who
  # changed what — fills up with edits nobody made.
  expect_length(importazioni(c("record_id", "username", "identity")), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "simulated")
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
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_senza_rilettura(),
    dry_run = FALSE
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


test_that("a sweep that failed is a transport error on every row, and nobody is asked", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(record_json(
      list(record_id = "1"),
      list(record_id = "2", server = "edc12", project_id = "9004")
    )),
    istanza_doppia(list()),
    function() stop("Could not resolve host")
  )

  # test
  # "I could not ask" is not "you are not the one". Every row goes back in the
  # queue and the next round picks it up, and no instance is interrogated at
  # all: the identity the register still carries was confirmed by some earlier
  # round and by nothing in this one, so acting on it would be acting on a
  # verdict nobody produced this pass. It is decision 2 read in the direction
  # that costs something.
  expect_length(interrogazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], rep("transport_error", 2L))
  expect_equal(
    esito[["esiti"]][["outcome_detail"]],
    rep("TRASPORTO_DIRECTORY_NON_RAGGIUNGIBILE", 2L)
  )
  expect_null(identita_scritte())
  expect_equal(nrow(esito[["istanze"]]), 0L)
})


test_that("a stopped row takes no transport error from its neighbour's instance", { # nolint: line_length_linter.
  # eval
  # Two rows on one instance, one resolved and one the gate stops, and the
  # instance is down. This is what the old "a row still waiting for an
  # identity" test protected, restated for the world where the round resolves
  # instead of waiting: before the transport outcome was restricted to rows the
  # round could actually have acted on, every register row for the server
  # collected TRASPORTO_NON_RAGGIUNGIBILE regardless of never having been
  # asked for.
  #
  # The second row is a namesake of the first with another contact address,
  # so the gate stops it as `ambiguous`. It used to be a person the tenant does
  # not hold, which the gate does not stop: that row waits for a creation, and
  # since 0.19.0 it takes the instance's code like a pair does.
  esito <- giro(
    registro_doppio(record_json(
      list(record_id = "1"),
      list(record_id = "2", contact_email = "altro.rossi@example.org",
           project_id = "9004")
    )),
    istanza_muta()
  )
  esiti <- esito[["esiti"]]

  # test
  expect_equal(
    esiti[["outcome"]][esiti[["record_id"]] == "1"], "transport_error"
  )
  expect_equal(esiti[["outcome"]][esiti[["record_id"]] == "2"], "data_error")
  expect_equal(
    esiti[["outcome_detail"]][esiti[["record_id"]] == "2"],
    "DATO_RECAPITO_NON_IDENTIFICA"
  )
})


# A post that takes every message. The creation branch runs only with one:
# without it the key would die with the process, so a test that wants the
# round to reach a creation, or to prove that something else stopped it, has
# to switch the post on first, or it would pass on the missing post alone.
posta_accesa <- function(to, cc, subject, body) {
  list(ok = TRUE, errors = character())
}


test_that("an absence in scope is created, under the name the round found free", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE,
    mailer = posta_accesa
  )

  # test
  # The name has to be the one the resolution checked, and the way to be sure
  # of that is that nothing composes it twice: the verdict carries it out and
  # the adapter is handed it. A second composition would let a round check that
  # one name is free and create another.
  expect_length(creazioni(), 1L)
  expect_equal(
    creazioni()[[1]][["body"]][["data"]][["userPrincipalName"]],
    "mario.rossi@ubep.unipd.it"
  )
  # The row stays `absent` this pass and becomes `created` at the next one,
  # which is decision 4 working as written: `created` is the row whose previous
  # verdict was `absent` and that now matches, and that memory lives in the
  # register. Nothing here has to remember anything.
  expect_equal(identita_scritte()[["identity"]], "absent")
  expect_equal(esito[["esiti"]][["outcome"]], "pending")
})


test_that("a simulated round makes nobody exist", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_vuota(),
    mailer = posta_accesa
  )

  # test
  # `UBEP_SCRITTURA` off means the round says what it would do, and creating a
  # person is not saying anything. It is the same line the instance writes are
  # on, and the one place it could have been forgotten: a creation is not a
  # write on an instance, so nothing else in the round would have stopped it.
  expect_length(creazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "pending")
})


test_that("nobody is created while the post is off, and the round says so", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE
  )
  record <- round_record(esito, scrittura = TRUE, posta = FALSE)

  # test
  # `UBEP_SCRITTURA=1` with `UBEP_POSTA` off. The account would be born and
  # its key would have no road out: the post is the only one, and without it
  # the key dies with the process. So the row waits, as it waits for a silent
  # instance, and the round's record carries why. The code can only come
  # from the creation step, which is what proves the row got that far: the
  # instance answered, the gate let it through, and only the post stopped it.
  expect_length(creazioni(), 0L)
  expect_gt(length(interrogazioni()), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "pending")
  expect_true("TRASPORTO_CREAZIONE_SENZA_POSTA" %in% esito[["errori"]])
  expect_true("TRASPORTO_CREAZIONE_SENZA_POSTA" %in% record[["errori"]])
  expect_equal(nrow(esito[["credenziali"]]), 0L)
})


test_that("a round with nobody to create does not complain about the post", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  # The code names a creation that was withheld, not a switch that is off:
  # with nobody to create, writing with the post off is the configuration the
  # runner documents, and it must not fail every round.
  expect_equal(esito[["esiti"]][["outcome"]], "applied")
  expect_false("TRASPORTO_CREAZIONE_SENZA_POSTA" %in% esito[["errori"]])
})


test_that("nobody is created for a row whose requester could not have granted it", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(
      list(username = "anna.bianchi@ubep.unipd.it", user_rights = 0L)
    ),
    directory_vuota(),
    dry_run = FALSE,
    mailer = posta_accesa
  )

  # test
  # Guard D on the wire. Making an identity exist is a bigger act than granting
  # a right on one, so it cannot be bounded by less. This is also why the round
  # had to be rearranged: an `absent` row is not a pair, so before this it
  # stopped at the identity gate and never reached the instance that answers
  # the scope question at all.
  expect_length(creazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "DATO_AMBITO_NON_AUTORIZZATO"
  )
})


test_that("nobody is born from a request revoked before it was ever served", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list(request_status = "revoked"))),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE,
    mailer = posta_accesa
  )

  # test
  # `request_status` used to reach only `register_to_desired()`, so the creation
  # branch hung off the verdict alone and a row somebody had revoked still made
  # the person exist. The two are not the same question -- a revocation speaks
  # about the access and the verdict about who somebody is -- but nobody who
  # revokes an unserved request expects an account to be born from it, and the
  # register's own field note promises the opposite of a deletion: "absence is
  # not a request".
  #
  # It closes rather than waiting, and `applied` is the word this round already
  # uses for it: a revocation of a right that is not there is settled the same
  # way, with the read-back saying `absent`. Asking for absence and finding it
  # is a success, and `pending` would leave open for ever a row nobody will
  # touch again.
  expect_length(creazioni(), 0L)
  expect_length(interrogazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "applied")
  expect_equal(esito[["esiti"]][["applied_as"]], "absent")
})


test_that("a revocation of somebody who was never made is simulated on a dry run", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(record_json(list(request_status = "revoked"))),
    istanza_doppia(list()),
    directory_vuota()
  )

  # test
  # The outcome is read off `dry_run` like every other settled row and is not
  # fixed at `applied` here: a simulated round reports what it would have
  # concluded, and a register that said `applied` while `UBEP_SCRITTURA` was off
  # would carry a success no round produced.
  expect_equal(esito[["esiti"]][["outcome"]], "simulated")
})


test_that("nobody is created while the instance that would say so is silent", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_muta(),
    directory_vuota(),
    dry_run = FALSE,
    mailer = posta_accesa
  )

  # test
  # An instance that did not answer has not said "yes" and has not said "no".
  # Fail closed: the row waits, and the next round asks again. Creating on an
  # unanswered question would make the gate a thing that holds only while the
  # network does. It waits as a transport error, the next test says why.
  expect_length(creazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "transport_error")
})


test_that("a person to create on a silent instance waits with the instance's code", { # nolint: line_length_linter.
  # eval
  muta <- giro(
    registro_doppio(record_json(list())),
    istanza_muta(),
    directory_vuota()
  )
  senza_modulo <- giro(
    registro_doppio(record_json(list(server = "edc07"))),
    istanza_doppia(list()),
    directory_vuota()
  )

  # test
  # The row is `absent`, so it is not a pair and never enters the plan; it
  # reaches the instance only for the scope question. Left `pending`, it
  # waited without limit and without a word: the referent had the first
  # message and nothing after it, and nothing told us an instance was silent
  # for that row. It now waits the way a pair on the same instance waits, as a
  # transport error under the instance's own code, which comes back to the
  # queue every round and reaches us.
  expect_equal(identita_scritte()[["identity"]], "absent")
  expect_equal(muta[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    muta[["esiti"]][["outcome_detail"]], "TRASPORTO_NON_RAGGIUNGIBILE"
  )
  expect_equal(senza_modulo[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    senza_modulo[["esiti"]][["outcome_detail"]],
    "TRASPORTO_ISTANZA_SENZA_MODULO"
  )
})


test_that("a creation that failed leaves the row absent, with the reason on it", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_vuota(),
    function(req) {
      httr2::response(
        status_code = 403L,
        headers = list(`Content-Type` = "application/json"),
        body = charToRaw('{"error":{"code":"Authorization_RequestDenied"}}')
      )
    },
    dry_run = FALSE,
    mailer = posta_accesa
  )

  # test
  # The row keeps the verdict it had -- there is still nobody there -- and
  # carries the reason, so the next round retries. Idempotent by construction:
  # if the account did come into being despite the error, the sweep finds it
  # and the row becomes `created` without anything being created twice.
  expect_equal(identita_scritte()[["identity"]], "absent")
  expect_equal(esito[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_CREAZIONE_RIFIUTATA"
  )
})


test_that("a creation whose answer was lost counts as a lost key and welcome", {
  # eval
  persa <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_vuota(),
    function(req) stop("Operation timed out"),
    dry_run = FALSE,
    mailer = posta_accesa
  )
  record <- round_record(persa, scrittura = TRUE, posta = TRUE)
  rifiutata <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_vuota(),
    function(req) {
      httr2::response(
        status_code = 403L,
        headers = list(`Content-Type` = "application/json"),
        body = charToRaw('{"error":{"code":"Authorization_RequestDenied"}}')
      )
    },
    dry_run = FALSE,
    mailer = posta_accesa
  )

  # test
  # The POST went out and nothing came back. If Graph made the account, its
  # key was drawn in this process and dies with it: next round the sweep finds
  # the account, the row becomes `created` and then `applied`, and a person
  # holds rights on an account whose key nobody knows, with no alarm. So the
  # round counts it now as a key and a welcome lost -- the alarm on the lost
  # key is the one that sends IT to reset it -- and names the creation code
  # among its errors and on the row, which is where IT finds the person.
  expect_length(creazioni(), 1L)
  expect_equal(persa[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    persa[["esiti"]][["outcome_detail"]],
    "TRASPORTO_CREAZIONE_NON_RAGGIUNGIBILE"
  )
  expect_identical(record[["credenziali_perse"]], 1L)
  expect_identical(record[["benvenuti_persi"]], 1L)
  expect_identical(record[["credenziali_recapitate"]], 0L)
  expect_true("TRASPORTO_CREAZIONE_NON_RAGGIUNGIBILE" %in% record[["errori"]])
  expect_equal(nrow(persa[["credenziali"]]), 0L)
  # Graph's own refusal says nobody was born, and there is no key to lose.
  expect_identical(rifiutata[["posta"]][["credenziali_perse"]], 0L)
  expect_identical(rifiutata[["posta"]][["benvenuti_persi"]], 0L)
})


test_that("a person is not created for a request whose last day has passed", {
  # eval
  oggetti <- character()
  esito <- giro(
    registro_doppio(record_json(list(expiration = "1999-01-01"))),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE,
    mailer = function(to, cc, subject, body) {
      oggetti <<- c(oggetti, subject) # nolint: assignment_linter.
      list(ok = TRUE, errors = character())
    }
  )

  # test
  # A row whose person does not exist yet is not a pair, so it never went
  # through `validate_request()`: the account was born, the welcome and the
  # key left, and the error appeared one round later, on a person who now
  # exists for a request that could never be served. The code is the one the
  # validation gives, so it proves the row was validated before the creation
  # and not stopped somewhere else.
  expect_length(creazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "DATO_SCADENZA_NON_VALIDA"
  )
  expect_equal(nrow(esito[["credenziali"]]), 0L)
  expect_false(any(grepl("Il tuo account UBEP", oggetti, fixed = TRUE)))
})


test_that("a person asked for twice on one project is created once", {
  # eval
  esito <- giro(
    registro_doppio(record_json(
      list(record_id = "1"), list(record_id = "2")
    )),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE,
    mailer = posta_accesa
  )
  esiti <- esito[["esiti"]]

  # test
  # The pair the two rows will make once the person exists is one pair, and
  # the register already has a rule for that: the oldest row keeps it and the
  # others are duplicates. Applied only after the creation, it let both rows
  # try to make the same account in the same round.
  expect_length(creazioni(), 1L)
  expect_equal(esito[["credenziali"]][["record_id"]], "1")
  expect_equal(esiti[["outcome"]][esiti[["record_id"]] == "2"], "data_error")
  expect_equal(
    esiti[["outcome_detail"]][esiti[["record_id"]] == "2"],
    "DATO_COPPIA_DUPLICATA"
  )
})


# An instance that knows only some roles and refuses the others the way the
# module does. `Applier::resolveNames()` runs on a simulation too, so a dry-run
# apply already names a role the project does not have.
istanza_con_ruoli <- function(ruoli, ...) {
  base <- istanza_doppia(...)
  function(data) {
    body <- base(data)
    if (!identical(data[["operation"]], "apply")) {
      return(body)
    }
    parsed <- jsonlite::fromJSON(body, simplifyVector = FALSE)
    parsed[["results"]] <- lapply(parsed[["results"]], function(entry) {
      ruolo <- entry[["after"]][["role_name"]]
      if (!is.null(ruolo) && !ruolo %in% ruoli) {
        entry[["outcome"]] <- "errore"
        entry[["errors"]] <- list(list(
          code = "DATO_RUOLO_INESISTENTE",
          message = "role is not defined in this project"
        ))
      }
      entry
    })
    as.character(jsonlite::toJSON(parsed, auto_unbox = TRUE, null = "null"))
  }
}


test_that("a person is not created for a role the project does not have", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list(role_name = "ruolo che non c'e'"))),
    istanza_con_ruoli("data entry", list()),
    directory_vuota(),
    dry_run = FALSE,
    mailer = posta_accesa
  )
  prove <- Filter(function(req) {
    identical(req[["body"]][["data"]][["operation"]], "apply")
  }, inviate)
  controllo <- giro(
    registro_doppio(record_json(list())),
    istanza_con_ruoli("data entry", list()),
    directory_vuota(),
    dry_run = FALSE,
    mailer = posta_accesa
  )

  # test
  # Whether the role exists is the instance's to say, and only a write tells
  # it -- so the round rehearses the grant the person will get, as a dry run,
  # under the name it is about to create, before the person exists. The code
  # can only have come from that rehearsal, and the control shows the same
  # instance letting a role it knows through to the creation.
  expect_length(prove, 1L)
  expect_true(prove[[1]][["body"]][["data"]][["dry_run"]])
  expect_equal(
    prove[[1]][["body"]][["data"]][["requests"]][[1]][["username"]],
    "mario.rossi@ubep.unipd.it"
  )
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_equal(esito[["esiti"]][["outcome_detail"]], "DATO_RUOLO_INESISTENTE")
  expect_equal(nrow(esito[["credenziali"]]), 0L)
  expect_equal(nrow(controllo[["credenziali"]]), 1L)
  expect_equal(controllo[["esiti"]][["outcome"]], "pending")
})


test_that("a simulated round already says the role does not exist", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list(role_name = "ruolo che non c'e'"))),
    istanza_con_ruoli("data entry", list()),
    directory_vuota()
  )

  # test
  # The simulation is where the referents read what the round would do, and a
  # rehearsal that cannot refuse what the performance refuses cannot warn.
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_equal(esito[["esiti"]][["outcome_detail"]], "DATO_RUOLO_INESISTENTE")
})


test_that("a rehearsal the instance does not answer makes nobody exist", {
  # eval
  # The instance answers the state read and then stops answering.
  a_meta <- function(data) {
    if (identical(data[["operation"]], "apply")) {
      stop("Could not resolve host")
    }
    istanza_doppia(list())(data)
  }
  esito <- giro(
    registro_doppio(record_json(list())),
    a_meta,
    directory_vuota(),
    dry_run = FALSE,
    mailer = posta_accesa
  )

  # test
  # Not validated is not valid: the row waits, under the code of the call
  # that did not come back, and the next round rehearses again.
  expect_length(creazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "transport_error")
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_NON_RAGGIUNGIBILE"
  )
})


test_that("the credential leaves by one road and is on none of the others", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE,
    mailer = posta_accesa
  )
  credenziale <- esito[["credenziali"]][["credential"]][[1]]
  record <- round_record(esito, scrittura = TRUE, posta = TRUE)
  altrove <- c(
    unlist(esito[["esiti"]]),
    unlist(lapply(importazioni(), function(req) {
      form_field_value(req[["body"]][["data"]][["data"]])
    })),
    unlist(record)
  )

  # test
  # It comes out of the call that made the account and goes to sub-project 5,
  # which will deliver it. Everywhere else is a place it would outlive the act:
  # the register is read by referents, the telemetry record is shipped to a
  # workspace and kept, and standard output is what the timer collects. Checked
  # against what actually left the machine rather than against a branch, the
  # way the guard on out-of-scope writes is.
  expect_equal(nchar(credenziale), 24L)
  expect_equal(esito[["credenziali"]][["record_id"]], "1")
  expect_false(any(grepl(credenziale, altrove, fixed = TRUE)))
  expect_false("credenziali" %in% names(record))
})


campi_esito <- c(
  "record_id", "outcome", "outcome_detail", "outcome_at", "applied_as"
)


posta_che_rifiuta <- function(to, cc, subject, body) {
  list(ok = FALSE, errors = "TRASPORTO_POSTA_RIFIUTATA")
}


test_that("una riga la cui mail non parte non entra nel corpo dell'import", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_che_scrive(),
    dry_run = FALSE,
    mailer = posta_che_rifiuta
  )

  # test
  # This is the invariant of the whole file: send first, write after. A row the
  # referent was not told about does not become history in the register, so the
  # next round finds it changed again and tries once more. The queue is the
  # register itself.
  expect_length(importazioni(campi_esito), 0L)
  expect_equal(esito[["scritte"]], 0L)
  expect_true("TRASPORTO_POSTA_RIFIUTATA" %in% esito[["errori"]])
  expect_equal(esito[["posta"]][["posta_fallite"]], 1L)
})


test_that("senza mailer il giro si comporta come prima di questo file", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  # The default has to be silence, or installing the package would start a
  # mail on the next timer.
  expect_length(importazioni(campi_esito), 1L)
  expect_equal(esito[["posta"]][["posta_partite"]], 0L)
  expect_false(esito[["posta"]][["posta_dirottata"]])
})


test_that("una mail partita apre la strada alla scrittura della sua riga", {
  # eval
  mandate <- 0L
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_che_scrive(),
    dry_run = FALSE,
    mailer = function(to, cc, subject, body) {
      # The grant also sends the access message, which has no row to open.
      if (!startsWith(subject, "Accesso a REDCap")) {
        mandate <<- mandate + 1L # nolint: assignment_linter.
      }
      list(ok = TRUE, errors = character())
    }
  )

  # test
  expect_equal(mandate, 1L)
  expect_length(importazioni(campi_esito), 1L)
  expect_equal(esito[["posta"]][["posta_partite"]], 1L)
})


test_that("il messaggio nomina l'identita' che questo giro ha stabilito", {
  # eval
  corpo <- NULL
  giro(
    registro_doppio(record_json(list())),
    istanza_che_scrive(),
    dry_run = FALSE,
    mailer = function(to, cc, subject, body) {
      # The outcome message, not the access message the grant also sends.
      if (!startsWith(subject, "Accesso a REDCap")) {
        corpo <<- body # nolint: assignment_linter.
      }
      list(ok = TRUE, errors = character())
    }
  )

  # test
  # The fixture files the row the way a referent does, with `username` blank.
  # The round resolves it and writes it through the identity door *before* the
  # mail leaves, so by the time the referent reads the message the register
  # already carries the UPN. A message that says it is not established yet is
  # contradicting a value this same round produced.
  expect_match(corpo, "mario.rossi@ubep.unipd.it", fixed = TRUE)
  expect_false(grepl("non ancora stabilito", corpo, fixed = TRUE))
})


test_that("il giro passa al benvenuto l'host dell'istanza della riga", {
  # eval
  mandate <- list()
  giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE,
    mailer = function(to, cc, subject, body) {
      mandate[[length(mandate) + 1L]] <<- list( # nolint: assignment_linter.
        to = to, subject = subject, body = body
      )
      list(ok = TRUE, errors = character())
    }
  )
  a <- function(chi, oggetto) {
    Filter(function(m) {
      identical(m[["to"]], chi) && grepl(oggetto, m[["subject"]], fixed = TRUE)
    }, mandate)
  }

  # test
  # The address is not composed from `server` and not written anywhere in the
  # package: the round already holds the inventory's map, and this is the test
  # that it hands it on. Forgetting to would cost nothing visible -- the
  # welcome leaves without the two lines -- which is why it is pinned here.
  benvenuto <- a("mario.rossi@example.org", "Il tuo account UBEP")
  chiave <- a("anna.bianchi@ubep.unipd.it", "Accesso al nuovo account")
  expect_length(benvenuto, 1L)
  expect_length(chiave, 1L)
  expect_match(
    benvenuto[[1L]][["body"]], "REDCap si apre da: https://edc10.example.org/",
    fixed = TRUE
  )
  expect_false(grepl("example.org", chiave[[1L]][["body"]], fixed = TRUE))
})


test_that("un benvenuto perso arriva fino al record del giro", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE,
    mailer = function(to, cc, subject, body) {
      if (identical(to, "mario.rossi@example.org")) {
        return(list(ok = FALSE, errors = "TRASPORTO_POSTA_RIFIUTATA"))
      }
      list(ok = TRUE, errors = character())
    }
  )
  record <- round_record(esito, scrittura = TRUE, posta = TRUE)

  # test
  # Counted where the key is counted, and carried by the same road: the
  # round's `posta`, then the record the alarm reads.
  expect_true("POSTA_BENVENUTO_PERSO" %in% esito[["errori"]])
  expect_identical(record[["benvenuti_persi"]], 1L)
  expect_identical(record[["benvenuti_recapitati"]], 0L)
  expect_identical(record[["credenziali_recapitate"]], 1L)
  expect_identical(record[["posta_fallite"]], 0L)
  # The outcome of the row that made the account still goes in.
  expect_length(importazioni(campi_esito), 1L)
})


test_that("senza mailer il giro porta anche i benvenuti a zero", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  expect_identical(esito[["posta"]][["benvenuti_recapitati"]], 0L)
  expect_identical(esito[["posta"]][["benvenuti_persi"]], 0L)
})


test_that("senza mailer il giro porta anche gli accessi a zero", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  expect_identical(esito[["posta"]][["accessi_recapitati"]], 0L)
  expect_identical(esito[["posta"]][["accessi_persi"]], 0L)
})


test_that("una riga cambiata dopo l'applicazione non si riapplica da sola", {
  # eval
  # The round's seal, in the owners' log it reads the seal from: with the
  # channel's account configured, the field alone says nothing.
  sigillato <- as.character(jsonlite::toJSON(list(list(
    timestamp = "2026-08-12 05:00", username = "svc-canale-ubep",
    action = "Update record (API) 1",
    details = "applied_seal = '000000000000'", record = "1"
  )), auto_unbox = TRUE))
  esito <- giro(
    registro_doppio(
      record_json(list(
        record_id = "1", outcome = "applied",
        applied_seal = "000000000000"
      )),
      proprietari = sigillato
    ),
    istanza_doppia(list()),
    dry_run = FALSE
  )

  # test
  # The seal the round wrote does not match what the row asks for now, so
  # somebody edited it after it was applied. Applying again would grant
  # whatever the edit says, on the authority of a round that ran before the
  # edit existed -- and REDCap has no per-row ownership to stop it, which is
  # the whole reason this branch exists.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  # Not merely "nothing was written": the row never reached an instance at
  # all. A held row is stopped where `withdrawn` is stopped, before the desired
  # state is built, so no instance is ever asked about it.
  expect_length(scritture(), 0L)
  expect_length(interrogazioni(), 0L)
})


test_that("il giro sigilla la riga che ha appena applicato", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list(record_id = "1"))),
    istanza_che_scrive(),
    dry_run = FALSE
  )
  scritto <- sigilli_scritti()

  # test
  # Without this the protection never starts: a row carrying no seal is a row
  # that cannot have been modified after it was applied, so every row would
  # stay unprotected for ever and the branch above would never fire once.
  expect_equal(as.character(scritto[["record_id"]]), "1")
  expect_true(nzchar(as.character(scritto[["applied_seal"]])))
  expect_equal(as.character(scritto[["seal_state"]]), "intact")
})


test_that("lo username che il giro risolve non fa sembrare cambiata la riga", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list(record_id = "1"))),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  # The round resolves `username` and writes it back in the same pass, so the
  # register holds a different value after the round than the one the round
  # read. `username` is inside the seal -- it has to be, since changing it
  # changes who gets the access -- so a seal computed from the row as read
  # would stop matching the moment the round's own write landed, and every
  # applied row would come back `held` one round later. The mechanism would
  # accuse itself, systematically, on the ordinary path.
  expect_equal(
    as.character(sigilli_scritti()[["applied_seal"]]),
    request_seal(riga_come_registro(
      record_id = "1", username = "mario.rossi@ubep.unipd.it"
    ))
  )
})


# The event log as REDCap answers it, newest first.
eventi_json <- function(...) {
  as.character(jsonlite::toJSON(lapply(list(...), function(e) {
    utils::modifyList(
      list(
        timestamp = "2026-09-01 02:45", username = "", action = "Update record",
        details = "", record = "1"
      ),
      e
    )
  }), auto_unbox = TRUE))
}


test_that("l'approvazione di chi ha creato la riga la sblocca, e la risigilla", { # nolint: line_length_linter.
  # eval
  # Two seals, and the test is worth writing because they differ. What the
  # approval has to carry is the seal of the row **as the register holds it**,
  # username still blank; what the round writes back afterwards is the seal of
  # the row once this same pass has resolved the username into it.
  approvato <- request_seal(riga_come_registro(record_id = "1"))
  risigillato <- request_seal(riga_come_registro(
    record_id = "1", username = "mario.rossi@ubep.unipd.it"
  ))
  esito <- giro(
    registro_doppio(
      record_json(list(
        record_id = "1",
        applied_seal = "000000000000", approved_seal = approvato
      )),
      eventi = eventi_json(
        list(
          username = "anna.bianchi@ubep.unipd.it",
          details = paste0("approved_seal = '", approvato, "'")
        ),
        list(
          username = "bruno.verdi@ubep.unipd.it",
          details = "role_name = 'data entry'"
        )
      )
    ),
    # Bruno wrote the change, so the gate judges Bruno's rights.
    istanza_che_scrive(richiedenti = c(
      "anna.bianchi@ubep.unipd.it", "bruno.verdi@ubep.unipd.it"
    )),
    dry_run = FALSE
  )

  # test
  # The other half of the protection, and the half that has to work or the
  # register fills up with rows nobody can ever clear. The approval carries
  # this row's seal and comes from whoever created the row, who is not who
  # changed it, so the round applies it -- and seals the row again, at its new
  # value, so the approval covers this change and stops there.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_equal(
    as.character(sigilli_scritti()[["applied_seal"]]), risigillato
  )
  # `approved` and not `intact`: the two say different things about the same
  # row, and only one of them is true here. `intact` is what a row carries
  # when nobody has ever contested it, and this row was contested and cleared
  # -- writing `intact` would leave the register unable to tell the two apart
  # one round after the protection fired, which is the state the log would
  # then be the only witness of.
  expect_equal(as.character(sigilli_scritti()[["seal_state"]]), "approved")
})


test_that("il giro dopo non retrocede una riga approvata a intatta", {
  # eval
  # The row as it stands once the approval has already been applied: seal in
  # force, `approved` beside it, username resolved so this round has nothing
  # to rewrite. Nobody has touched it since.
  fermo <- request_seal(riga_come_registro(
    record_id = "1", username = "mario.rossi@ubep.unipd.it"
  ))
  esito <- giro(
    registro_doppio(
      record_json(list(
        record_id = "1", username = "mario.rossi@ubep.unipd.it",
        identity = "existing", outcome = "applied",
        applied_seal = fermo, seal_state = "approved"
      ))
    ),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  # The row really is applied on this pass, and the assertion below is worth
  # nothing without it: a fixture the round stops earlier -- on the identity,
  # as the first draft of this test did -- writes no seal either, and would
  # pass while proving nothing.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")

  # Nothing goes through the seal door at all. The seal has not moved and the
  # state must not either: a state recomputed as `intact` on every ordinary
  # round would erase the approval one pass after it was granted, and the
  # third value would name a state that lasts four hours.
  expect_null(sigilli_scritti())
})


# Creation events in the shape REDCap answers a `logtype = "record_add"` with.
# `details` carries the forged name on purpose: it is where an importer's
# chosen `requested_by` actually lands, and a reader that took it from there
# would be reading the payload instead of the authentication.
creazioni_finte <- function(...) {
  as.character(jsonlite::toJSON(
    lapply(list(...), function(evento) {
      utils::modifyList(
        list(
          timestamp = "2026-08-14 01:00",
          username = "anna.bianchi@ubep.unipd.it",
          action = "Create record (import) 1",
          details = "record_id = '1'",
          record = "1"
        ),
        evento
      )
    }),
    auto_unbox = TRUE
  ))
}


# The register as REDCap answers its event log, which the double above does
# not: `beginTime` keeps only the events from that hour on, in the instance's
# clock, and `record` only that row's. And every import the round makes
# becomes an event signed by the account that holds the token, on top of the
# log, carrying only the fields it changed -- which is what REDCap does, so a
# round that wrote something before reading the log reads its own write, and
# reads it without the fields that did not move. `storia` is what happened
# before the round, newest first. Asked for the owners' log, it answers with
# every row's events and the creations below them.
registro_con_log <- function(records,
                             storia = list(),
                             canale = "svc-canale-ubep",
                             creazioni = NULL) {
  base <- registro_doppio(records, creazioni = creazioni)
  scritti <- list()
  righe <- jsonlite::fromJSON(records, simplifyVector = FALSE)
  names(righe) <- vapply(
    righe, function(r) as.character(r[["record_id"]]), character(1)
  )
  completa <- function(e) {
    utils::modifyList(
      list(
        timestamp = "2026-08-14 02:45", username = "",
        action = "Update record", details = "", record = "1"
      ),
      e
    )
  }
  function(data) {
    if (identical(form_field_value(data[["action"]]), "import")) {
      sent <- jsonlite::fromJSON(
        form_field_value(data[["data"]]), simplifyVector = FALSE
      )
      for (r in sent) {
        id <- as.character(r[["record_id"]])
        campi <- Filter(function(campo) {
          !identical(
            as.character(righe[[id]][[campo]] %||% ""),
            as.character(r[[campo]])
          )
        }, setdiff(names(r), "record_id"))
        if (length(campi) == 0L) {
          next
        }
        righe[[id]][campi] <<- r[campi] # nolint: assignment_linter.
        scritti <<- c(list(list( # nolint: assignment_linter.
          timestamp = "2026-08-14 05:00", username = canale,
          action = paste0("Update record (API) ", id),
          details = paste0(
            campi, " = '", vapply(r[campi], as.character, ""), "'",
            collapse = ", "
          ),
          record = id
        )), scritti)
      }
    }
    # The owners' log, `logtype = "record"`: every row's events with no
    # window, newest first, and the creations at the bottom, as REDCap holds
    # them under the oldest stamps.
    if (identical(form_field_value(data[["content"]]), "log") &&
          identical(form_field_value(data[["logtype"]] %||% ""), "record")) {
      nati <- jsonlite::fromJSON(
        base(list(content = "log", logtype = "record_add")),
        simplifyVector = FALSE
      )
      if (!is.null(names(nati))) {
        nati <- list()
      }
      return(as.character(jsonlite::toJSON(
        c(lapply(c(scritti, storia), completa), nati), auto_unbox = TRUE
      )))
    }
    if (identical(form_field_value(data[["content"]]), "log") &&
          is.null(data[["logtype"]])) {
      inizio <- form_field_value(data[["beginTime"]] %||% "")
      riga <- form_field_value(data[["record"]] %||% "")
      eventi <- Filter(
        function(e) {
          (!nzchar(inizio) || e[["timestamp"]] >= inizio) &&
            (!nzchar(riga) || identical(e[["record"]], riga))
        },
        lapply(c(scritti, storia), completa)
      )
      return(as.character(jsonlite::toJSON(eventi, auto_unbox = TRUE)))
    }
    base(data)
  }
}


# What the round asked of the event log, creations aside: one list per call,
# with the window and the record it named, `""` where it named none.
log_chiesti <- function() {
  lapply(
    Filter(function(req) {
      data <- req[["body"]][["data"]]
      identical(form_field_value(data[["content"]] %||% ""), "log") &&
        is.null(data[["logtype"]])
    }, inviate),
    function(req) {
      data <- req[["body"]][["data"]]
      list(
        beginTime = form_field_value(data[["beginTime"]] %||% ""),
        record = form_field_value(data[["record"]] %||% "")
      )
    }
  )
}


test_that("una modifica di due giorni fa e' ancora di chi l'ha fatta", {
  # eval
  # Bruno edits the row applied on the 12th at 22:00, instance time; the
  # rounds after hold it. On the 13th at 23:00 Bruno himself pastes the seal.
  # A round of the 14th at 03:00 UTC that asked for the last 24 hours would
  # see the approval and not the edit, find nobody who made the change, and
  # take Bruno's approval as somebody else's. The username is already the one
  # the round resolves, so the round writes nothing before reading the log.
  approvato <- request_seal(riga_come_registro(
    record_id = "1", username = "mario.rossi@ubep.unipd.it"
  ))
  esito <- giro(
    registro_con_log(
      record_json(list(
        record_id = "1", username = "mario.rossi@ubep.unipd.it",
        identity = "existing", outcome = "applied",
        applied_seal = "000000000000", seal_state = "intact",
        approved_seal = approvato
      )),
      storia = list(
        list(
          timestamp = "2026-08-13 23:00",
          username = "bruno.verdi@ubep.unipd.it",
          details = paste0("approved_seal = '", approvato, "'")
        ),
        list(
          timestamp = "2026-08-12 22:00",
          username = "bruno.verdi@ubep.unipd.it",
          details = "role_name = 'data entry'"
        )
      )
    ),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  # The log is asked for the row and for all of it: who changed a row since
  # it was applied does not stop mattering after a day.
  expect_equal(log_chiesti(), list(list(beginTime = "", record = "1")))
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


# What the round wrote when it applied the row, in an earlier pass: the seals
# door's event, the one that names the channel's account in the row's log as
# the mark of an execution.
esecuzione <- function(sigillo = "000000000000") {
  list(
    timestamp = "2026-08-12 05:00", username = "svc-canale-ubep",
    action = "Update record (API) 1",
    details = paste0(
      "applied_seal = '", sigillo, "', seal_state = 'intact'"
    )
  )
}


test_that("la riscrittura dello username da parte del canale non sblocca chi ha modificato", { # nolint: line_length_linter.
  # eval
  # Bruno changes the role of a row the round applied and blanks its username.
  # The round resolves the username again and writes it back before it reads
  # the log, so the newest write of an intent field is the channel's.
  riga <- list(
    record_id = "1", identity = "existing", outcome = "applied",
    role_name = "read only", username = "", applied_seal = "000000000000",
    seal_state = "intact"
  )
  attuale <- request_seal(do.call(riga_come_registro, riga))
  esito <- giro(
    registro_con_log(
      do.call(record_json, list(c(riga, list(approved_seal = attuale)))),
      storia = list(
        list(
          username = "bruno.verdi@ubep.unipd.it",
          details = paste0("approved_seal = '", attuale, "'")
        ),
        list(
          username = "bruno.verdi@ubep.unipd.it",
          details = "role_name = 'read only', username = ''"
        ),
        esecuzione()
      )
    ),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  # Precondition: the round did rewrite the username, which is the write that
  # lands in the log under the channel's name.
  expect_equal(
    as.character(identita_scritte()[["username"]]), "mario.rossi@ubep.unipd.it"
  )
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


# A row the round applied in an earlier pass and somebody changed since: the
# role is not the one sealed. The username is already the one the round
# resolves, so nothing is written before the log is read.
riga_cambiata <- function(...) {
  utils::modifyList(
    list(
      record_id = "1", username = "mario.rossi@ubep.unipd.it",
      identity = "existing", outcome = "applied", role_name = "read only",
      applied_seal = "000000000000", seal_state = "intact"
    ),
    list(...)
  )
}


sigillo_cambiata <- function(...) {
  request_seal(do.call(riga_come_registro, riga_cambiata(...)))
}


# One round over that row. `storia` is what people did after the round applied
# it, newest first; the execution itself is appended below it.
giro_cambiata <- function(storia,
                          approvato = "",
                          istanza = istanza_che_scrive(),
                          riga = riga_cambiata(),
                          creazioni = NULL,
                          ...) {
  giro(
    registro_con_log(
      record_json(utils::modifyList(riga, list(approved_seal = approvato))),
      storia = c(storia, list(esecuzione())),
      creazioni = creazioni
    ),
    istanza,
    dry_run = FALSE,
    ...
  )
}


cambio <- function(chi, details = "role_name = 'read only'", ...) {
  list(username = chi, details = details, ...)
}


approvazione <- function(chi, sigillo = sigillo_cambiata(), ...) {
  list(username = chi, details = paste0("approved_seal = '", sigillo, "'"), ...)
}


anna <- "anna.bianchi@ubep.unipd.it"
bruno <- "bruno.verdi@ubep.unipd.it"
cinzia <- "cinzia.rossi@ubep.unipd.it"


test_that("chi ha creato la riga la cambia, e il giro la esegue subito", {
  # eval
  esito <- giro_cambiata(list(cambio(anna)))

  # test
  # Anna's own request, changed by Anna: nobody else's work was touched, so
  # nobody else has anything to approve. The round carries it out and seals
  # the new version, as after any execution.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_length(scritture(), 1L)
  expect_equal(
    as.character(sigilli_scritti()[["applied_seal"]]), sigillo_cambiata()
  )
  # `intact`: the row was changed, not contested.
  expect_equal(as.character(sigilli_scritti()[["seal_state"]]), "intact")
})


test_that("chi cambia la riga di un altro la ferma finche' chi l'ha creata non approva", { # nolint: line_length_linter.
  # eval
  esito <- giro_cambiata(list(cambio(bruno)))

  # test
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
  expect_equal(as.character(sigilli_scritti()[["seal_state"]]), "modified")
  expect_equal(
    as.character(sigilli_scritti()[["applied_seal"]]), "000000000000"
  )
})


test_that("l'approvazione di chi ha cambiato la riga non vale", {
  # eval
  esito <- giro_cambiata(
    list(approvazione(bruno), cambio(bruno)),
    approvato = sigillo_cambiata()
  )

  # test
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


test_that("l'approvazione di un terzo non vale", {
  # eval
  esito <- giro_cambiata(
    list(approvazione(cinzia), cambio(bruno)),
    approvato = sigillo_cambiata()
  )

  # test
  # Cinzia did not make the change and did not make the request either. The
  # one person a change to Anna's request waits for is Anna.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


test_that("l'approvazione di chi ha creato la riga vale", {
  # eval
  esito <- giro_cambiata(
    list(approvazione(anna), cambio(bruno)),
    approvato = sigillo_cambiata(),
    istanza = istanza_che_scrive(richiedenti = c(anna, bruno))
  )

  # test
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_length(scritture(), 1L)
  expect_equal(as.character(sigilli_scritti()[["seal_state"]]), "approved")
})


test_that("chi ha creato la riga la cambia dopo una modifica approvata ed eseguita, e il giro la esegue", { # nolint: line_length_linter.
  # eval
  # Newest first. Bruno changed the row, Anna approved it, a round applied it
  # and sealed 111111111111; then Anna changed the expiration.
  esito <- giro_cambiata(
    list(
      cambio(anna, "expiration = '2027-01-31'"),
      esecuzione("111111111111"),
      approvazione(anna, "111111111111"),
      cambio(bruno)
    ),
    riga = riga_cambiata(
      expiration = "2027-01-31", applied_seal = "111111111111"
    )
  )

  # test
  # Bruno's change is behind the newest execution and was carried out with
  # Anna's leave. What is left is Anna's own edit, carried out at once.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_length(scritture(), 1L)
})


test_that("chi ha creato la riga e la cambia dopo un altro non fa sua la modifica dell'altro", { # nolint: line_length_linter.
  # eval
  # Bruno changes the role, Anna then changes the expiration. The version the
  # round would carry out holds Bruno's change too.
  esito <- giro_cambiata(
    list(cambio(anna, "expiration = '2027-01-31'"), cambio(bruno)),
    riga = riga_cambiata(expiration = "2027-01-31")
  )

  # test
  # A later edit by the creator is not an approval: it does not say she saw
  # what Bruno did, and an approval is the one act that does. Waiting for the
  # seal costs her a paste; reading her edit as consent would carry out a
  # change to her request that nobody approved.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


# The revokes the round sent for real, and the usernames the state read asked
# about: the scope gate can judge only the rights the instance was asked for.
revoche <- function() {
  Filter(function(req) {
    identical(req[["body"]][["data"]][["operation"]], "revoke")
  }, scritture())
}


chiesti_allo_stato <- function() {
  unique(unlist(lapply(interrogazioni(), function(req) {
    data <- req[["body"]][["data"]]
    if (!identical(data[["operation"]], "state")) {
      return(character())
    }
    vapply(data[["requests"]] %||% list(), function(p) {
      as.character(p[["username"]])
    }, character(1))
  })))
}


# A row Anna filed, applied, and now revoked; the instance holds the person.
revocata <- function(...) {
  riga_cambiata(role_name = "data entry", request_status = "revoked", ...)
}


con_mario <- function(...) {
  c(
    list(...),
    list(list(
      username = "mario.rossi@ubep.unipd.it", role_name = "data entry",
      user_rights = 0L
    ))
  )
}


test_that("chi gestisce il progetto revoca la richiesta di un altro senza approvazione", { # nolint: line_length_linter.
  # eval
  esito <- giro_cambiata(
    list(cambio(bruno, "request_status = 'revoked'")),
    riga = revocata(),
    istanza = do.call(istanza_doppia, con_mario(
      list(), list(username = bruno, user_rights = 1L)
    ))
  )

  # test
  # Decided on 2026-10-15: taking an access away grants nothing, and Bruno
  # could have removed Mario from the project by hand. The double keeps the
  # row it was asked to remove, so the read-back does not confirm the revoke;
  # what this pins is that it was sent, and that Bruno's rights were asked.
  expect_false(as.character(esito[["esiti"]][["outcome"]]) == "held")
  expect_length(revoche(), 1L)
  expect_true(bruno %in% chiesti_allo_stato())
})


test_that("chi non gestisce il progetto non revoca la richiesta di un altro", {
  # eval
  esito <- giro_cambiata(
    list(cambio(bruno, "request_status = 'revoked'")),
    riga = revocata(),
    istanza = do.call(istanza_doppia, con_mario(
      list(), list(username = bruno, user_rights = 0L)
    ))
  )

  # test
  # Without User Rights on the project the exception does not apply, and the
  # revocation is a change like any other: it waits for Anna.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_equal(
    as.character(esito[["esiti"]][["outcome_detail"]]),
    paste0("SIGILLO_DIVERSO:", sigillo_cambiata(
      role_name = "data entry", request_status = "revoked"
    ))
  )
  expect_length(scritture(), 0L)
  # Held at the gate, the row keeps its seal and its state says it moved.
  expect_equal(as.character(sigilli_scritti()[["seal_state"]]), "modified")
})


test_that("una revoca che cambia anche il ruolo aspetta chi ha creato la riga", { # nolint: line_length_linter.
  # eval
  esito <- giro_cambiata(
    list(cambio(
      bruno, "request_status = 'revoked', role_name = 'data entry'"
    )),
    riga = revocata(),
    istanza = do.call(istanza_doppia, con_mario(
      list(), list(username = bruno, user_rights = 1L)
    ))
  )

  # test
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


test_that("la revoca libera non chiede i diritti di chi ha creato la riga", {
  # eval
  # Anna no longer manages the project; Bruno does, and revokes.
  esito <- giro_cambiata(
    list(cambio(bruno, "request_status = 'revoked'")),
    riga = revocata(),
    istanza = do.call(istanza_doppia, con_mario(
      list(user_rights = 0L), list(username = bruno, user_rights = 1L)
    ))
  )

  # test
  # The revocation stands on Bruno's authority, which is the one the gate
  # asks: Anna had no hand in it.
  expect_false(
    as.character(esito[["esiti"]][["outcome_detail"]]) ==
      "DATO_AMBITO_NON_AUTORIZZATO"
  )
  expect_length(revoche(), 1L)
})


test_that("diritti illeggibili di chi revoca tengono la riga in coda", {
  # eval
  esito <- giro_cambiata(
    list(cambio(bruno, "request_status = 'revoked'")),
    riga = revocata(),
    istanza = do.call(istanza_doppia, con_mario(
      list(), list(username = bruno, user_rights = NULL)
    ))
  )

  # test
  # A permission nobody could read is ours to fix, as on the ordinary gate.
  expect_equal(
    as.character(esito[["esiti"]][["outcome_detail"]]),
    "TRASPORTO_PERMESSO_NON_LEGGIBILE"
  )
  expect_length(scritture(), 0L)
})


test_that("chi gestisce il progetto revoca una richiesta di un altro non ancora eseguita", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_con_log(
      record_json(list(
        record_id = "1", username = "mario.rossi@ubep.unipd.it",
        identity = "existing", request_status = "revoked"
      )),
      storia = list(cambio(bruno, "request_status = 'revoked'"))
    ),
    do.call(istanza_doppia, con_mario(
      list(), list(username = bruno, user_rights = 1L)
    )),
    dry_run = FALSE
  )

  # test
  expect_false(as.character(esito[["esiti"]][["outcome"]]) == "held")
  expect_length(revoche(), 1L)
})


test_that("l'approvazione di IT sblocca la modifica di un altro", {
  # eval
  it <- "it.redcap@ubep.unipd.it"
  esito <- giro_cambiata(
    list(approvazione(it), cambio(bruno)),
    approvato = sigillo_cambiata(),
    istanza = istanza_che_scrive(richiedenti = c(anna, bruno)),
    approvers = it
  )

  # test
  # Decided on 2026-10-15: IT approves any change, so a request whose creator
  # left is not stuck, and keeps its creator on record.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_equal(as.character(sigilli_scritti()[["seal_state"]]), "approved")
})


test_that("senza l'elenco di IT nessun altro approva", {
  # eval
  esito <- giro_cambiata(
    list(approvazione("it.redcap@ubep.unipd.it"), cambio(bruno)),
    approvato = sigillo_cambiata()
  )

  # test
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
})


test_that("un'esecuzione approvata da IT copre la modifica che ha eseguito", {
  # eval
  # Newest first: Bruno changed the role, IT approved, the round carried it
  # out under seal 111111111111; then Anna, the creator, changed the
  # expiration.
  it <- "it.redcap@ubep.unipd.it"
  esito <- giro_cambiata(
    list(
      cambio(anna, "expiration = '2027-01-31'"),
      esecuzione("111111111111"),
      approvazione(it, "111111111111"),
      cambio(bruno)
    ),
    riga = riga_cambiata(
      expiration = "2027-01-31", applied_seal = "111111111111"
    ),
    approvers = it
  )

  # test
  # IT's approval covered Bruno's change as the creator's would have: what
  # remains is Anna's own edit, which needs nobody.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_length(scritture(), 1L)
})


test_that("una revoca libera gia' eseguita non fa aspettare chi riattiva", {
  # eval
  # Bruno revoked, the round carried it out under the seal of the revoked
  # row; then Anna, the creator, set the request back to active.
  revocata_eseguita <- sigillo_cambiata(
    role_name = "data entry", request_status = "revoked"
  )
  esito <- giro_cambiata(
    list(
      cambio(anna, "request_status = 'active'"),
      esecuzione(revocata_eseguita),
      cambio(bruno, "request_status = 'revoked'")
    ),
    riga = riga_cambiata(
      role_name = "data entry", request_status = "active",
      applied_seal = revocata_eseguita
    )
  )

  # test
  # A revocation alone grants nothing, so it does not stay "uncovered" below
  # the execution that carried it out: the change is Anna's alone.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
})


test_that("la revoca altrui di una persona assente non si chiude senza cancello", { # nolint: line_length_linter.
  # eval
  # The tenant no longer holds the person, so the row is `absent` and
  # revoked: there is no pair, and no instance would be asked about Bruno.
  esito <- giro(
    registro_con_log(
      record_json(riga_cambiata(request_status = "revoked")),
      storia = list(cambio(bruno, "request_status = 'revoked'"), esecuzione())
    ),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE
  )

  # test
  # The exception is decided at the gate, on Bruno's rights. A row that never
  # reaches the gate waits for its creator, as before the exception existed.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
})


test_that("chi ha creato la riga revoca la propria richiesta subito", {
  # eval
  revocata <- riga_cambiata(
    role_name = "data entry", request_status = "revoked"
  )
  esito <- giro_cambiata(
    list(cambio(anna, "request_status = 'revoked'")),
    istanza = istanza_doppia(
      list(),
      list(
        username = "mario.rossi@ubep.unipd.it", role_name = "data entry",
        user_rights = 0L
      )
    ),
    riga = revocata
  )

  # test
  # The revoke is carried out: the double keeps the row it was asked to
  # remove, so the read-back still shows it and the round does not call the
  # revoke applied -- what this test pins is that it was sent at all.
  expect_false(as.character(esito[["esiti"]][["outcome"]]) == "held")
  expect_true(any(vapply(interrogazioni(), function(req) {
    identical(req[["body"]][["data"]][["operation"]], "revoke")
  }, logical(1))))
})


test_that("chi approva non ha bisogno dei diritti: un proprietario che li ha persi cede la riga", { # nolint: line_length_linter.
  # eval
  # Anna approves Bruno's change, and Anna no longer manages the project;
  # Bruno does.
  esito <- giro_cambiata(
    list(approvazione(anna), cambio(bruno)),
    approvato = sigillo_cambiata(),
    istanza = istanza_che_scrive(richiedenti = bruno, senza_diritti = anna)
  )

  # test
  # The gate judges whoever wrote what the round carries out, and approving
  # is not writing: it adds no power to the change. So an owner who lost the
  # rights can still let a manager's change through, instead of leaving the
  # row stuck with an owner whose rights nothing can bring back.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_length(scritture(), 1L)
})


test_that("un terzo con pieni diritti sul progetto non approva la richiesta di un altro", { # nolint: line_length_linter.
  # eval
  esito <- giro_cambiata(
    list(approvazione(cinzia), cambio(bruno)),
    approvato = sigillo_cambiata(),
    istanza = istanza_doppia(
      list(),
      list(username = cinzia, user_rights = 1L)
    )
  )

  # test
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


test_that("una modifica di due giorni fa approvata da chi ha creato la riga si esegue", { # nolint: line_length_linter.
  # eval
  esito <- giro_cambiata(
    list(
      approvazione(anna, timestamp = "2026-08-13 23:00"),
      cambio(bruno, timestamp = "2026-08-12 22:00")
    ),
    approvato = sigillo_cambiata(),
    istanza = istanza_che_scrive(richiedenti = c(anna, bruno))
  )

  # test
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
})


test_that("una modifica di due giorni fa resta di chi l'ha fatta anche dopo una del creatore", { # nolint: line_length_linter.
  # eval
  # Bruno changed the role on the 12th at 22:00, instance time; Anna changed
  # the expiration on the 13th at 23:00; nobody approved. The round runs on
  # the 14th at 03:00 UTC.
  esito <- giro_cambiata(
    list(
      cambio(anna, "expiration = '2027-01-31'", timestamp = "2026-08-13 23:00"),
      cambio(bruno, timestamp = "2026-08-12 22:00")
    ),
    riga = riga_cambiata(expiration = "2027-01-31")
  )

  # test
  # A window of a day, whether asked of REDCap or applied to what it
  # answered, keeps Anna's edit and loses Bruno's and the execution below
  # it: the change would be Anna's alone and would be carried out. Asserting
  # on the request is not enough, so this asserts on what the round did.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


test_that("una modifica che il log non attribuisce aspetta chi ha creato la riga", { # nolint: line_length_linter.
  # eval
  # The seal moved and the row's log says nobody changed it since the round
  # applied it: a log purged in between, a field the dictionary gained.
  ferma <- giro_cambiata(list())
  fermi <- scritture()
  approvata <- giro_cambiata(
    list(approvazione(anna)),
    approvato = sigillo_cambiata()
  )

  # test
  # Nobody established is not the creator established: the row waits, and
  # the creator can release it the ordinary way.
  expect_equal(as.character(ferma[["esiti"]][["outcome"]]), "held")
  expect_length(fermi, 0L)
  expect_equal(as.character(approvata[["esiti"]][["outcome"]]), "applied")
})


test_that("un'approvazione gia' eseguita non vale per la modifica dopo", {
  # eval
  # Newest first. Bruno set the role, Anna approved it and the round applied
  # it; Anna set it back to data entry herself and the round applied that;
  # now Bruno sets it again. `approved_seal` still holds Anna's old approval,
  # and the row is back to the version it approves.
  in_uso <- sigillo_cambiata(role_name = "data entry")
  esito <- giro_cambiata(
    list(
      cambio(bruno), esecuzione(in_uso),
      cambio(anna, "role_name = 'data entry'"),
      esecuzione(sigillo_cambiata()), approvazione(anna), cambio(bruno)
    ),
    approvato = sigillo_cambiata(),
    riga = riga_cambiata(applied_seal = in_uso)
  )

  # test
  # That approval was spent when the round carried it out. Taken again, one
  # value would approve every later change that brings the row back to it,
  # and the creator would never be asked nor told.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


test_that("un'approvazione gia' eseguita non riattiva una richiesta revocata", {
  # eval
  revocata <- sigillo_cambiata(request_status = "revoked")
  esito <- giro_cambiata(
    list(
      cambio(bruno, "request_status = 'active'"), esecuzione(revocata),
      cambio(anna, "request_status = 'revoked'"),
      esecuzione(sigillo_cambiata()), approvazione(anna), cambio(bruno)
    ),
    approvato = sigillo_cambiata(),
    riga = riga_cambiata(applied_seal = revocata)
  )

  # test
  # Anna withdrew the access; Bruno turning it back on is a change to her
  # request like any other, whatever she approved before she withdrew it.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


test_that("un'approvazione scritta prima della modifica non la approva", {
  # eval
  # The seal is a public sha256 of the intent fields, so it can be computed
  # for a version that does not exist yet: Anna pastes it, Bruno then makes
  # the row match it.
  esito <- giro_cambiata(
    list(cambio(bruno), approvazione(anna)),
    approvato = sigillo_cambiata()
  )

  # test
  # An approval says the creator saw the change, and nobody sees a change
  # before it is made.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


test_that("una modifica fatta mentre il giro girava non diventa di chi ha creato la riga", { # nolint: line_length_linter.
  # eval
  # Newest first. A round read the row with role data entry; while it was
  # sweeping the tenant Bruno set read only; the round applied what it had
  # read and wrote its seal last, above Bruno's edit. Anna then changed the
  # expiration.
  letta <- sigillo_cambiata(role_name = "data entry")
  esito <- giro_cambiata(
    list(
      cambio(anna, "expiration = '2027-01-31'"), esecuzione(letta),
      cambio(bruno)
    ),
    riga = riga_cambiata(expiration = "2027-01-31", applied_seal = letta)
  )

  # test
  # The seal covers the row the round read, not the one it found when it
  # wrote. Bruno's edit sits below it in the log and the round never applied
  # it: dropped as already executed, Anna's later edit would carry it out as
  # hers.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


test_that("chi cambia una richiesta di un altro non ancora eseguita la ferma", { # nolint: line_length_linter.
  # eval
  # Anna filed the row; before any round applied it, Bruno, who manages
  # nothing on 9003, set the role to admin. The row carries no seal, whether
  # no round has reached it yet or the last one left it in the queue.
  esiti <- vapply(c("", "pending", "transport_error"), function(prima) {
    esito <- giro(
      registro_doppio(
        record_json(
          list(record_id = "1", role_name = "admin", outcome = prima)
        ),
        eventi = eventi_json(
          list(username = bruno, details = "role_name = 'admin'")
        )
      ),
      istanza_che_scrive(),
      dry_run = FALSE
    )
    paste(as.character(esito[["esiti"]][["outcome"]]), length(scritture()))
  }, character(1))

  # test
  # Carried out, the change would run on Anna's authority -- hers are the
  # rights the gate checks -- and nobody asked her. A request is its
  # creator's before the round applies it as much as after.
  expect_equal(unname(esiti), rep("held 0", 3L))
})


test_that("chi ha creato una richiesta non ancora eseguita la cambia, e il giro la esegue", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(
      record_json(list(record_id = "1")),
      eventi = eventi_json(
        list(username = anna, details = "role_name = 'data entry'"),
        list(
          username = anna, action = "Create record 1",
          details = "record_id = '1', role_name = 'read only'"
        )
      )
    ),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_length(scritture(), 1L)
})


test_that("una richiesta nuova con l'id di una riga cancellata non eredita chi aveva cambiato quella", { # nolint: line_length_linter.
  # eval
  # REDCap reuses the ids of deleted records. Id 1 was a field test, applied
  # and then changed by Bruno; the register was emptied, and the id came
  # back as Anna's request. Asked for record 1, REDCap answers with both
  # lives, newest first, and the creation log holds both creations.
  vecchia_vita <- list(
    list(
      username = "amministratore.prova@ubep.unipd.it",
      action = "Delete record 1", details = "record_id = '1'"
    ),
    list(username = bruno, details = "role_name = 'admin'"),
    list(
      username = "svc-canale-ubep", action = "Update record (API) 1",
      details = "outcome = 'applied', applied_seal = 'eeeeeeeeeeee'"
    ),
    list(
      username = "collaudo.prova@ubep.unipd.it", action = "Create record 1",
      details = "record_id = '1', role_name = 'read only'"
    )
  )
  creata <- list(
    username = anna, action = "Create record 1",
    details = "record_id = '1', role_name = 'data entry'"
  )
  giro_con <- function(...) {
    giro(
      registro_doppio(
        record_json(list(record_id = "1")),
        eventi = do.call(eventi_json, c(list(...), list(creata), vecchia_vita)),
        creazioni = creazioni_finte(
          list(username = anna, action = "Create record 1"),
          list(
            username = "collaudo.prova@ubep.unipd.it",
            action = "Create record 1"
          )
        )
      ),
      istanza_che_scrive(),
      dry_run = FALSE
    )
  }

  # test
  # Read whole, the log named Bruno, the field test's creator and whoever
  # deleted it, and the first real request on a reused id was held on its
  # first round, waiting for an approval of changes made to another row.
  esito <- giro_con()
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_length(scritture(), 1L)

  # Bruno's hand in Anna's row, and not in the old one, still holds it.
  esito <- giro_con(list(
    username = bruno, details = "contact_email = 'mario.rossi@example.org'"
  ))
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})


test_that("l'approvazione di chi l'ha creata sblocca una richiesta non ancora eseguita", { # nolint: line_length_linter.
  # eval
  riga <- list(
    record_id = "1", username = "mario.rossi@ubep.unipd.it",
    identity = "existing", role_name = "read only"
  )
  approvato <- request_seal(do.call(riga_come_registro, riga))
  esito <- giro(
    registro_doppio(
      record_json(c(riga, list(approved_seal = approvato))),
      eventi = eventi_json(
        list(
          username = anna,
          details = paste0("approved_seal = '", approvato, "'")
        ),
        list(username = bruno, details = "role_name = 'read only'")
      )
    ),
    istanza_che_scrive(richiedenti = c(anna, bruno)),
    dry_run = FALSE
  )

  # test
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_equal(as.character(sigilli_scritti()[["seal_state"]]), "approved")
})


test_that("un log illeggibile non lascia eseguire una richiesta non ancora eseguita", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(
      record_json(list(record_id = "1")),
      eventi = '{"error":"You do not have Logging rights"}'
    ),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  # Whether somebody else changed the request is the log's to say, and the
  # log did not answer: the row waits, under a code that says the failure is
  # ours and not a change to approve, and the reason reaches the round's
  # record, where IT reads it.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "transport_error")
  expect_equal(
    as.character(esito[["esiti"]][["outcome_detail"]]),
    "TRASPORTO_AUTORE_NON_LEGGIBILE"
  )
  expect_length(scritture(), 0L)
  expect_true("TRASPORTO_REGISTRO_RIFIUTATO" %in% esito[["errori"]])
})


test_that("un registro degli eventi illeggibile non lascia valere l'approvazione", { # nolint: line_length_linter.
  # eval
  approvato <- request_seal(riga_come_registro(record_id = "1"))
  esito <- giro(
    registro_doppio(
      record_json(list(
        record_id = "1",
        applied_seal = "000000000000", approved_seal = approvato
      )),
      eventi = '{"error":"You do not have Logging rights"}'
    ),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  # The approval is there and it is the right one, and it still does not
  # count: without the log the round cannot tell whether it came from somebody
  # other than whoever made the change, and that is the whole condition. "I
  # could not ask who did this" is not "somebody else approved it" -- between
  # the two ways of being wrong, this is the one that does not grant.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "transport_error")
  expect_length(scritture(), 0L)
})


# Every message the round sends, as the mailer received it.
posta_raccolta <- function() {
  mandate <- list()
  list(
    mailer = function(to, cc, subject, body) {
      mandate[[length(mandate) + 1L]] <<- list( # nolint: assignment_linter.
        to = to, subject = subject, body = body
      )
      list(ok = TRUE, errors = character())
    },
    mandate = function() mandate
  )
}


test_that("la riga trattenuta si annuncia a chi l'ha creata, non a chi la riga nomina", { # nolint: line_length_linter.
  # eval
  # `requested_by` names Carla; the creation log says Anna made the row. The
  # two agree on every row filed from the form, and an import is what makes
  # them disagree.
  posta <- posta_raccolta()
  giro_cambiata(
    list(cambio(bruno)),
    riga = riga_cambiata(requested_by = "carla.neri@ubep.unipd.it"),
    creazioni = creazioni_finte(list(username = anna)),
    mailer = posta[["mailer"]]
  )

  # test
  # The message asks its reader to approve, and only the creator can: sent to
  # anybody else it asks for an act that will not count.
  destinatari <- vapply(posta[["mandate"]](), `[[`, "", "to")
  expect_equal(destinatari, anna)
  # And it names who changed the row, read from the row's log.
  expect_match(
    posta[["mandate"]]()[[1L]][["body"]], paste("Modificata da:", bruno),
    fixed = TRUE
  )
})


test_that("una seconda modifica a una riga trattenuta porta al creatore il sigillo nuovo", { # nolint: line_length_linter.
  # eval
  # The first round holds Bruno's change and tells Anna its seal.
  prima <- posta_raccolta()
  esito_prima <- giro_cambiata(list(cambio(bruno)), mailer = prima[["mailer"]])
  # Then Bruno changes the role again, before Anna has approved anything. The
  # register carries what the first round wrote.
  dopo <- posta_raccolta()
  esito_dopo <- giro_cambiata(
    list(cambio(bruno, "role_name = 'data manager'"), cambio(bruno)),
    riga = riga_cambiata(
      role_name = "data manager", outcome = "held",
      outcome_detail = as.character(esito_prima[["esiti"]][["outcome_detail"]]),
      seal_state = "modified"
    ),
    mailer = dopo[["mailer"]]
  )

  # test
  # The seal Anna holds approves a version of the row that no longer exists.
  # Without a message carrying the new one she cannot approve the row at all:
  # it would stay held with nobody told why.
  expect_equal(as.character(esito_dopo[["esiti"]][["outcome"]]), "held")
  mandate <- dopo[["mandate"]]()
  expect_length(mandate, 1L)
  expect_equal(mandate[[1L]][["to"]], anna)
  expect_match(
    mandate[[1L]][["body"]], sigillo_cambiata(role_name = "data manager"),
    fixed = TRUE
  )
  # The seal is in the outcome detail too, which is what makes the row count
  # as changed, and what a referent who lost the message finds on the row.
  expect_equal(
    as.character(esito_dopo[["esiti"]][["outcome_detail"]]),
    paste0("SIGILLO_DIVERSO:", sigillo_cambiata(role_name = "data manager"))
  )
})


test_that("una riga trattenuta che non cambia non riscrive al creatore", {
  # eval
  prima <- posta_raccolta()
  esito_prima <- giro_cambiata(list(cambio(bruno)), mailer = prima[["mailer"]])
  dopo <- posta_raccolta()
  giro_cambiata(
    list(cambio(bruno)),
    riga = riga_cambiata(
      outcome = "held",
      outcome_detail = as.character(esito_prima[["esiti"]][["outcome_detail"]]),
      seal_state = "modified"
    ),
    mailer = dopo[["mailer"]]
  )

  # test
  # One message per version of the row, not one per round.
  expect_length(prima[["mandate"]](), 1L)
  expect_length(dopo[["mandate"]](), 0L)
})


test_that("il sigillo della riga trattenuta e' quello che la riga avra' dopo il giro", { # nolint: line_length_linter.
  # eval
  # Bruno blanks the username and changes the role; the round writes the
  # username back in this same pass, before the message leaves.
  posta <- posta_raccolta()
  esito <- giro_cambiata(
    list(cambio(bruno, "role_name = 'read only', username = ''")),
    riga = riga_cambiata(username = ""),
    mailer = posta[["mailer"]]
  )

  # test
  # Anna reads the message after the round, on a row that carries the
  # resolved username: a seal of the row as read would never match it.
  atteso <- sigillo_cambiata()
  expect_equal(
    as.character(esito[["esiti"]][["outcome_detail"]]),
    paste0("SIGILLO_DIVERSO:", atteso)
  )
  expect_match(posta[["mandate"]]()[[1L]][["body"]], atteso, fixed = TRUE)
})


test_that("senza il creatore la riga cambiata non chiede un'approvazione", {
  # eval
  posta <- posta_raccolta()
  esito <- giro(
    registro_doppio(
      record_json(list(record_id = "1", applied_seal = "000000000000")),
      creazioni = '{"error":"You do not have Logging privileges"}'
    ),
    istanza_che_scrive(),
    dry_run = FALSE,
    mailer = posta[["mailer"]],
    copy_to = "it@example.org"
  )

  # test
  # The creator could not be read this round, so the row has no owner and
  # nobody can approve until it is. A held message would ask the reader for a
  # seal that approves nothing and claim to reach the owner when it does not:
  # the row takes the code the gate gives a row with no author, the message
  # says it is ours, and it goes to IT alone, whom it tells so. `requested_by`
  # (here `anna`) is not a fallback.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "transport_error")
  expect_equal(
    as.character(esito[["esiti"]][["outcome_detail"]]),
    "TRASPORTO_AUTORE_NON_LEGGIBILE"
  )
  mandate <- posta[["mandate"]]()
  expect_equal(vapply(mandate, `[[`, "", "to"), "it@example.org")
  expect_no_match(mandate[[1L]][["body"]], "approved_seal", fixed = TRUE)
  expect_match(mandate[[1L]][["body"]], "Referente della riga non stabilito",
               fixed = TRUE)
})


test_that("la mail di un log illeggibile non chiede di incollare un sigillo", {
  # eval
  posta <- posta_raccolta()
  giro(
    registro_doppio(
      record_json(list(record_id = "1", applied_seal = "000000000000")),
      eventi = '{"error":"You do not have Logging rights"}'
    ),
    istanza_che_scrive(),
    dry_run = FALSE,
    mailer = posta[["mailer"]]
  )

  # test
  corpo <- posta[["mandate"]]()[[1L]][["body"]]
  expect_match(corpo, "TRASPORTO_AUTORE_NON_LEGGIBILE", fixed = TRUE)
  expect_no_match(corpo, "approved_seal", fixed = TRUE)
  expect_no_match(corpo, "Modificata da", fixed = TRUE)
})


test_that("un log illeggibile arriva fino al record del giro", {
  # eval
  esito <- giro(
    registro_doppio(
      record_json(list(record_id = "1", applied_seal = "000000000000")),
      eventi = '{"error":"You do not have Logging rights"}'
    ),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  # The row says what failed only in general, `TRASPORTO_AUTORE_NON_LEGGIBILE`.
  # Why the log could not be read is the register's answer, and it has to
  # reach whoever reads the round's record, or the row waits in silence.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "transport_error")
  expect_true("TRASPORTO_REGISTRO_RIFIUTATO" %in% esito[["errori"]])
  expect_true(
    "TRASPORTO_REGISTRO_RIFIUTATO" %in%
      round_record(esito, scrittura = TRUE, posta = FALSE)[["errori"]]
  )
})


test_that("un log delle creazioni illeggibile arriva fino al record del giro", {
  # eval
  esito <- giro(
    registro_doppio(
      record_json(list()),
      creazioni = '{"error":"You do not have Logging privileges"}'
    ),
    istanza_doppia(list()),
    dry_run = FALSE
  )

  # test
  # The row carries its own code, `TRASPORTO_AUTORE_NON_LEGGIBILE`. The reason
  # the log could not be read is the register's answer, and only the round's
  # record can carry it.
  expect_true("TRASPORTO_REGISTRO_RIFIUTATO" %in% esito[["errori"]])
})


test_that("the gate judges whoever filed the row, not whoever the row says filed it", { # nolint: line_length_linter.
  # eval
  # `requested_by` names Anna, who manages this project and whose request
  # would be served. The log says Carla made the row, and Carla manages
  # nothing here. Measured on 2026-09-02: an import writes that field
  # verbatim, so the register alone cannot tell these two situations apart.
  esito <- giro(
    registro_doppio(
      record_json(list()),
      creazioni = creazioni_finte(
        list(username = "carla.neri@ubep.unipd.it")
      )
    ),
    istanza_doppia(list()),
    dry_run = FALSE
  )

  # test
  # The assertion is on the gate's own code and not merely on "nothing was
  # written", and that is deliberate. A row can fail to be written for a dozen
  # reasons that have nothing to do with the gate, and a test satisfied by
  # absence would pass just as well if the row had died before ever reaching
  # it -- which is how yesterday's blind test passed. `DATO_AMBITO_NON_
  # AUTORIZZATO` can only have been produced by the gate, so it proves the row
  # got there.
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "DATO_AMBITO_NON_AUTORIZZATO"
  )
  expect_equal(esito[["esiti"]][["outcome"]], "data_error")
  expect_length(scritture(), 0L)
})


test_that("a creation log that could not be read holds the row, it does not refuse it", { # nolint: line_length_linter.
  # eval
  # The register answers the creation question with a refusal -- the service
  # account lost its Logging right, say, which is a thing that happens to a
  # right somebody granted by hand.
  esito <- giro(
    registro_doppio(
      record_json(list()),
      creazioni = '{"error":"You do not have Logging privileges"}'
    ),
    istanza_doppia(list()),
    dry_run = FALSE
  )

  # test
  # The row must not be written, and that much a `DATO_` code would also
  # achieve. What it must not do is tell the referent they are not authorized:
  # they filed a correct request, they may well hold the permission, and what
  # is broken is inside REDCap where only we can reach it. `DATO_` closes the
  # row against them and mails them; `TRASPORTO_` keeps it queued and mails
  # us. It is the same distinction `scope_errors()` already makes for a
  # permission it could not read, and for the same reason.
  expect_length(scritture(), 0L)
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_AUTORE_NON_LEGGIBILE"
  )
  expect_equal(esito[["esiti"]][["outcome"]], "transport_error")
})


test_that("a row held for an unreadable log makes nobody exist either", {
  # eval
  # The tenant holds nobody, so the row resolves `absent` and it is the
  # creation branch that would act on it -- the branch that runs last, after
  # the gate, and that no earlier assertion in this cycle covers.
  esito <- giro(
    registro_doppio(
      record_json(list()),
      creazioni = '{"error":"You do not have Logging privileges"}'
    ),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE,
    mailer = posta_accesa
  )

  # test
  # Making the person is the one act of the round that cannot be undone by
  # running it again: an account exists afterwards. The rule the design states
  # for it is that whoever could not have granted the project by hand must not
  # be able to make the person to grant it to either -- and a round that
  # cannot say who filed the row cannot say that person could.
  expect_length(creazioni(), 0L)
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_AUTORE_NON_LEGGIBILE"
  )
})


# A row filed through the Data Import Tool, whose account the round makes. The
# creation log names Anna, who imported it and whose rights the gate judges;
# `requested_by` is whatever the CSV carried, which REDCap writes verbatim.
giro_importato <- function(requested_by) {
  posta <- posta_raccolta()
  esito <- giro(
    registro_doppio(
      record_json(list(requested_by = requested_by)),
      creazioni = creazioni_finte(list(username = anna))
    ),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE,
    mailer = posta[["mailer"]]
  )
  mandate <- posta[["mandate"]]()
  a <- function(oggetto) {
    vapply(
      Filter(function(m) grepl(oggetto, m[["subject"]], fixed = TRUE), mandate),
      function(m) m[["to"]], character(1)
    )
  }
  list(
    esito = esito,
    tutti = vapply(mandate, function(m) m[["to"]], character(1)),
    chiave = a("Accesso al nuovo account"),
    richiesta = a("Richiesta 1")
  )
}


test_that("la chiave di una riga importata va a chi l'ha creata", {
  # eval
  visto <- giro_importato("nominato.da.import@example.org")

  # test
  # The account is born on the creator's authority, the gate having judged
  # the creator's rights; the key goes back to the same person. An import
  # naming somebody else, the person themselves included, does not move it.
  expect_length(creazioni(), 1L)
  expect_equal(visto[["chiave"]], anna)
  expect_equal(visto[["richiesta"]], anna)
  expect_false("nominato.da.import@example.org" %in% visto[["tutti"]])
  expect_identical(visto[["esito"]][["posta"]][["credenziali_recapitate"]], 1L)
})


test_that("una riga importata senza requested_by non perde la chiave", {
  # eval
  visto <- giro_importato("")

  # test
  # With the empty field as its address, the key left for nobody: an account
  # born that nobody could get into, `POSTA_CREDENZIALE_PERSA`.
  expect_length(creazioni(), 1L)
  expect_equal(visto[["chiave"]], anna)
  expect_equal(visto[["richiesta"]], anna)
  expect_identical(visto[["esito"]][["posta"]][["credenziali_recapitate"]], 1L)
  expect_identical(visto[["esito"]][["posta"]][["credenziali_perse"]], 0L)
  expect_false("POSTA_CREDENZIALE_PERSA" %in% visto[["esito"]][["errori"]])
  expect_false("POSTA_SENZA_DESTINATARIO" %in% visto[["esito"]][["errori"]])
})


test_that("il giro non scrive requested_by nel registro", {
  # eval
  giro_importato("")

  # test
  # The channel does not write the fields of a request, and the seal covers
  # them: the creator travels in memory, to the gate and to the post.
  scritti <- unlist(lapply(importazioni(), function(req) {
    sent <- jsonlite::fromJSON(
      form_field_value(req[["body"]][["data"]][["data"]]),
      simplifyVector = FALSE
    )
    unlist(lapply(sent, names))
  }))
  expect_true("outcome" %in% scritti)
  expect_false("requested_by" %in% scritti)
})


# The channel's write of the row's owner, as the owner door leaves it: signed
# by the account `giro()` configures, below the execution of the round that
# decided the passage.
passaggio <- function(chi, ...) {
  utils::modifyList(
    list(
      timestamp = "2026-08-12 05:00", username = "svc-canale-ubep",
      action = "Update record (API) 1",
      details = paste0("owned_by = '", chi, "'")
    ),
    list(...)
  )
}


# Newest first: Bruno changed Anna's row, Anna approved, a round carried it
# out under seal 111111111111 and passed the row to Bruno. What the test adds
# stands above that execution.
dopo_passaggio <- function(...) {
  c(
    list(...),
    list(
      esecuzione("111111111111"), passaggio(bruno),
      approvazione(anna, "111111111111"), cambio(bruno)
    )
  )
}


test_that("dopo il passaggio la modifica dell'ultimo si esegue subito", {
  # eval
  esito <- giro_cambiata(
    dopo_passaggio(cambio(bruno, "expiration = '2027-01-31'")),
    riga = riga_cambiata(
      expiration = "2027-01-31", applied_seal = "111111111111"
    ),
    istanza = istanza_che_scrive(richiedenti = bruno)
  )

  # test
  # The row is Bruno's now, so his own change needs nobody, and the gate
  # judges his rights, not Anna's.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_length(scritture(), 1L)
})


test_that("dopo il passaggio la modifica del creatore aspetta l'ultimo", {
  # eval
  posta <- posta_raccolta()
  esito <- giro_cambiata(
    dopo_passaggio(cambio(anna, "expiration = '2027-01-31'")),
    riga = riga_cambiata(
      expiration = "2027-01-31", applied_seal = "111111111111"
    ),
    istanza = istanza_che_scrive(richiedenti = c(anna, bruno)),
    mailer = posta[["mailer"]]
  )

  # test
  # Having created the row no longer makes it Anna's: her change is somebody
  # else's, and the message asking for the approval goes to Bruno.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_equal(vapply(posta[["mandate"]](), `[[`, "", "to"), bruno)
})


test_that("il cancello giudica ogni giro i diritti dell'ultimo", {
  # eval
  # The row stands as the round left it after the passage: sealed, approved,
  # nobody has touched it since. Bruno owns it; only Anna manages 9003.
  fermo <- request_seal(riga_come_registro(
    record_id = "1", username = "mario.rossi@ubep.unipd.it"
  ))
  righe <- record_json(list(
    record_id = "1", username = "mario.rossi@ubep.unipd.it",
    identity = "existing", outcome = "applied", applied_seal = fermo,
    seal_state = "approved"
  ))
  storia <- list(
    esecuzione(fermo), passaggio(bruno), approvazione(anna, fermo),
    cambio(bruno), esecuzione()
  )
  solo_anna <- giro(
    registro_con_log(righe, storia = storia), istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  # Nothing changed, and the gate still asks every round: an owner who lost
  # the rights stops the row as the creator did before the passage.
  expect_equal(
    as.character(solo_anna[["esiti"]][["outcome_detail"]]),
    "DATO_AMBITO_NON_AUTORIZZATO"
  )
  expect_length(scritture(), 0L)
})


test_that("il cancello chiede i diritti di chi ha scritto la modifica, non di chi l'ha approvata", { # nolint: line_length_linter.
  # eval
  senza_bruno <- giro_cambiata(
    list(approvazione(anna), cambio(bruno)),
    approvato = sigillo_cambiata(), istanza = istanza_che_scrive()
  )
  chiesti <- chiesti_allo_stato()
  con_bruno <- giro_cambiata(
    list(approvazione(anna), cambio(bruno)),
    approvato = sigillo_cambiata(),
    istanza = istanza_che_scrive(richiedenti = bruno)
  )

  # test
  # Whoever wrote what is carried out must be able to do it by hand. Anna's
  # approval adds no power to Bruno's change, so it is Bruno who is asked.
  expect_equal(
    as.character(senza_bruno[["esiti"]][["outcome_detail"]]),
    "DATO_AMBITO_NON_AUTORIZZATO"
  )
  expect_true(bruno %in% chiesti)
  expect_equal(as.character(con_bruno[["esiti"]][["outcome"]]), "applied")
})


test_that("una modifica approvata senza autore stabilito non si esegue", {
  # eval
  # The approval is Anna's and stands, but the change below it has a blank
  # author: nobody whose rights the gate could ask.
  esito <- giro_cambiata(
    list(approvazione(anna), cambio("")),
    approvato = sigillo_cambiata(),
    istanza = istanza_che_scrive(richiedenti = c(anna, bruno))
  )

  # test
  expect_equal(
    as.character(esito[["esiti"]][["outcome_detail"]]),
    "TRASPORTO_AUTORE_NON_LEGGIBILE"
  )
  expect_length(scritture(), 0L)
})


test_that("il valore di owned_by nel registro non si crede", {
  # eval
  # The field names Bruno, and the channel never wrote it: an import did.
  posta <- posta_raccolta()
  giro_cambiata(
    list(cambio(anna)), riga = riga_cambiata(owned_by = bruno),
    istanza = istanza_che_scrive(), mailer = posta[["mailer"]]
  )

  # test
  # The row is Anna's, read from the log: her change is carried out on her
  # rights, and the outcome goes to her. The access message the grant also
  # sends goes to the person the row names, and Bruno gets nothing at all.
  mandate <- posta[["mandate"]]()
  di_accesso <- vapply(
    mandate, function(m) startsWith(m[["subject"]], "Accesso a REDCap"), NA
  )
  expect_length(scritture(), 1L)
  expect_equal(vapply(mandate[!di_accesso], `[[`, "", "to"), anna)
  expect_equal(
    vapply(mandate[di_accesso], `[[`, "", "to"), "mario.rossi@example.org"
  )
  expect_false(bruno %in% vapply(mandate, `[[`, "", "to"))
})


test_that("il giro chiede il log dei proprietari una volta, senza finestra", {
  # eval
  giro(registro_doppio(record_json(list())), istanza_che_scrive())
  chiesti <- Filter(function(req) {
    identical(
      form_field_value(req[["body"]][["data"]][["logtype"]] %||% ""), "record"
    )
  }, inviate)

  # test
  # The owner is the newest write of the channel, however old: a window would
  # lose a passage decided before it and give the row back to its creator.
  expect_length(chiesti, 1L)
  expect_null(chiesti[[1L]][["body"]][["data"]][["beginTime"]])
  expect_null(chiesti[[1L]][["body"]][["data"]][["record"]])
})


test_that("un log dei proprietari illeggibile tiene le righe, non le rifiuta", {
  # eval
  esito <- giro(
    registro_doppio(
      record_json(list()),
      proprietari = '{"error":"You do not have Logging privileges"}'
    ),
    istanza_che_scrive(), dry_run = FALSE
  )

  # test
  # Nobody established is not the creator established: the row waits under
  # a code that says the failure is ours, and the reason reaches the record.
  expect_equal(
    as.character(esito[["esiti"]][["outcome_detail"]]),
    "TRASPORTO_AUTORE_NON_LEGGIBILE"
  )
  expect_length(scritture(), 0L)
  # The register's answer to the owners' log, the only log that failed here.
  expect_match(
    esito[["errori"]], "^TRASPORTO_REGISTRO_RIFIUTATO$", all = FALSE
  )
})


test_that("senza il log delle creazioni il log dei proprietari non si chiede", {
  # eval
  giro(
    registro_doppio(
      record_json(list()),
      creazioni = '{"error":"You do not have Logging privileges"}'
    ),
    istanza_doppia(list()),
    dry_run = FALSE
  )
  chiesti <- function(tipo) {
    Filter(function(req) {
      identical(
        form_field_value(req[["body"]][["data"]][["logtype"]] %||% ""), tipo
      )
    }, inviate)
  }

  # test
  # The owner falls back on the creator, so without the creators the owners'
  # log could answer nothing the round would act on.
  expect_length(chiesti("record_add"), 1L)
  expect_length(chiesti("record"), 0L)
})


test_that("senza l'account del canale nessuna riga passa", {
  # eval
  posta <- posta_raccolta()
  esito <- giro_cambiata(
    dopo_passaggio(cambio(bruno, "expiration = '2027-01-31'")),
    riga = riga_cambiata(
      expiration = "2027-01-31", applied_seal = "111111111111"
    ),
    istanza = istanza_che_scrive(richiedenti = c(anna, bruno)),
    mailer = posta[["mailer"]], channel_account = NULL
  )

  # test
  # Anna is still the owner: Bruno's change waits for her.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_equal(vapply(posta[["mandate"]](), `[[`, "", "to"), anna)
})


test_that("chi importa owned_by su una riga nuova non la prende", {
  # eval
  # Anna filed the row; before any round, Bruno imported owned_by alone.
  posta <- posta_raccolta()
  esito <- giro(
    registro_con_log(
      record_json(list(record_id = "1", owned_by = bruno)),
      storia = list(list(
        username = bruno, details = paste0("owned_by = '", bruno, "'")
      ))
    ),
    istanza_che_scrive(), dry_run = FALSE,
    mailer = posta[["mailer"]], copy_to = "it@example.org"
  )

  # test
  # The channel is the configured account, and Bruno's import is ignored:
  # the row is Anna's, carried out on her rights, its outcome goes to her,
  # and the round writes her back into the field.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_length(scritture(), 1L)
  expect_equal(proprietari_scritti()[["owned_by"]], anna)
  mandate <- posta[["mandate"]]()
  di_accesso <- vapply(
    mandate, function(m) startsWith(m[["subject"]], "Accesso a REDCap"), NA
  )
  expect_equal(unique(vapply(mandate[!di_accesso], `[[`, "", "to")), anna)
  expect_false(bruno %in% vapply(mandate, `[[`, "", "to"))
})


test_that("una spazzata fallita manda l'esito a IT, con il referente non stabilito", { # nolint: line_length_linter.
  # eval
  posta <- posta_raccolta()
  esito <- giro(
    registro_doppio(record_json(list(record_id = "1"))),
    istanza_doppia(list()),
    function() stop("Could not resolve host"),
    dry_run = FALSE,
    mailer = posta[["mailer"]], copy_to = "it@example.org"
  )

  # test
  # The round stopped before reading the log, so nobody owns the row this
  # round: the outcome goes to IT alone, and says so in both languages.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "transport_error")
  mandate <- posta[["mandate"]]()
  expect_equal(vapply(mandate, `[[`, "", "to"), "it@example.org")
  expect_match(
    mandate[[1L]][["body"]], "Referente della riga non stabilito", fixed = TRUE
  )
  expect_match(
    mandate[[1L]][["body"]], "Whoever owns the row is not established",
    fixed = TRUE
  )
})


test_that("una riga cambiata senza proprietario stabilito non si trattiene", {
  # eval
  # Bruno changes the role of Anna's applied row, and a write of owned_by
  # with no author stands above it: the log cannot say whose the row is.
  posta <- posta_raccolta()
  esito <- giro_cambiata(
    list(
      cambio("", paste0("owned_by = '", bruno, "'")),
      cambio(bruno)
    ),
    istanza = istanza_che_scrive(richiedenti = c(anna, bruno)),
    mailer = posta[["mailer"]], copy_to = "it@example.org"
  )

  # test
  # A held message asks the owner for an approval; with no owner it would
  # say both that it goes to IT alone and that it goes to whoever owns the
  # row. The row is not held: it waits under our code, and the message says
  # only the first.
  expect_equal(
    as.character(esito[["esiti"]][["outcome_detail"]]),
    "TRASPORTO_AUTORE_NON_LEGGIBILE"
  )
  expect_length(scritture(), 0L)
  mandate <- posta[["mandate"]]()
  expect_equal(vapply(mandate, `[[`, "", "to"), "it@example.org")
  expect_match(
    mandate[[1L]][["body"]], "Referente della riga non stabilito", fixed = TRUE
  )
  expect_no_match(
    mandate[[1L]][["body"]], "va al referente della riga", fixed = TRUE
  )
})


test_that("un account del canale vuoto, di soli spazi o mancante ferma il giro", { # nolint: line_length_linter.
  # eval and test
  # A blank name would make every row's channel nobody's: it is a missing
  # configuration, and the round stops before it asks the register anything.
  for (account in list("", "  ", NA, NA_character_, character(),
                       c("svc-canale-ubep", ""))) {
    expect_error(
      giro(
        registro_doppio(record_json(list())), istanza_che_scrive(),
        channel_account = account
      ),
      "channel_account",
      info = format(account)
    )
    expect_length(inviate, 0L)
  }
})


test_that("il cancello giudica ogni autore della modifica, non solo il primo", {
  # eval
  # Anna filed the row and set its expiration; before any round applied it,
  # Bruno set the role, and then Anna approved. Both wrote what the round
  # would carry out, Bruno last, so he is the first author the log names.
  riga <- list(
    record_id = "1", username = "mario.rossi@ubep.unipd.it",
    identity = "existing", role_name = "read only", expiration = "2027-01-31"
  )
  approvato <- request_seal(do.call(riga_come_registro, riga))
  giro_con <- function(richiedenti) {
    giro(
      registro_doppio(
        record_json(c(riga, list(approved_seal = approvato))),
        eventi = eventi_json(
          list(
            username = anna,
            details = paste0("approved_seal = '", approvato, "'")
          ),
          list(username = bruno, details = "role_name = 'read only'"),
          list(username = anna, details = "expiration = '2027-01-31'")
        )
      ),
      istanza_che_scrive(richiedenti = richiedenti),
      dry_run = FALSE
    )
  }
  solo_bruno <- giro_con(bruno)
  scritte_solo_bruno <- scritture()
  tutti <- giro_con(c(anna, bruno))

  # test
  # Anna no longer manages the project, and her expiration is part of what
  # would be carried out: Bruno's rights do not cover it. A gate that judged
  # the first author alone would let the row through on Bruno's.
  expect_equal(
    as.character(solo_bruno[["esiti"]][["outcome_detail"]]),
    "DATO_AMBITO_NON_AUTORIZZATO"
  )
  expect_length(scritte_solo_bruno, 0L)
  expect_equal(as.character(tutti[["esiti"]][["outcome"]]), "applied")
})


test_that("la prima esecuzione scrive il creatore in owned_by", {
  # eval
  giro(
    registro_doppio(record_json(list(record_id = "1"))),
    istanza_che_scrive(), dry_run = FALSE
  )

  # test
  expect_equal(proprietari_scritti()[["owned_by"]], anna)
})


test_that("una riga di oggi riceve owned_by al primo giro, anche intatta", {
  # eval
  fermo <- request_seal(riga_come_registro(
    record_id = "1", username = "mario.rossi@ubep.unipd.it"
  ))
  giro(
    registro_doppio(record_json(list(
      record_id = "1", username = "mario.rossi@ubep.unipd.it",
      identity = "existing", outcome = "applied", applied_seal = fermo,
      seal_state = "intact"
    ))),
    istanza_che_scrive(), dry_run = FALSE
  )

  # test
  # A row applied before the field existed has its owner written all the
  # same, and its seal is not touched to do it.
  expect_equal(proprietari_scritti()[["owned_by"]], anna)
  expect_null(sigilli_scritti())
})


test_that("un owned_by che dice gia' il proprietario non si riscrive", {
  # eval
  giro(
    registro_doppio(record_json(list(record_id = "1", owned_by = anna))),
    istanza_che_scrive(), dry_run = FALSE
  )

  # test
  expect_null(proprietari_scritti())
})


test_that("un owned_by falsificato si corregge dal log", {
  # eval
  giro(
    registro_doppio(record_json(list(record_id = "1", owned_by = bruno))),
    istanza_che_scrive(), dry_run = FALSE
  )

  # test
  expect_equal(proprietari_scritti()[["owned_by"]], anna)
})


test_that("la modifica approvata ed eseguita passa la riga a chi l'ha scritta", { # nolint: line_length_linter.
  # eval
  posta <- posta_raccolta()
  giro_cambiata(
    list(approvazione(anna), cambio(bruno)), approvato = sigillo_cambiata(),
    istanza = istanza_che_scrive(richiedenti = bruno),
    mailer = posta[["mailer"]]
  )

  # test
  # The outcome goes to the new owner, and tells them the row is theirs.
  expect_equal(proprietari_scritti()[["owned_by"]], bruno)
  esito <- Filter(
    function(m) grepl("Richiesta 1", m[["subject"]], fixed = TRUE),
    posta[["mandate"]]()
  )
  expect_equal(vapply(esito, `[[`, "", "to"), bruno)
  expect_match(esito[[1L]][["body"]], "la riga e' tua", fixed = TRUE)
})


# Mario is no longer on the instance, so the revocation settles as
# `already_gone` and the row is executed: the passage is really decided.
senza_mario <- function() {
  istanza_doppia(list(), list(username = bruno, user_rights = 1L))
}


test_that("una revoca libera eseguita non passa la riga", {
  # eval
  esito <- giro_cambiata(
    list(cambio(bruno, "request_status = 'revoked'")),
    riga = revocata(), istanza = senza_mario()
  )

  # test
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_equal(proprietari_scritti()[["owned_by"]], anna)
})


test_that("una revoca approvata dal proprietario non passa la riga", {
  # eval
  sigillo <- sigillo_cambiata(
    role_name = "data entry", request_status = "revoked"
  )
  esito <- giro_cambiata(
    list(
      approvazione(anna, sigillo),
      cambio(bruno, "request_status = 'revoked'")
    ),
    approvato = sigillo, riga = revocata(), istanza = senza_mario()
  )

  # test
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_equal(proprietari_scritti()[["owned_by"]], anna)
})


test_that("una modifica di IT approvata ed eseguita passa la riga a IT", {
  # eval
  it <- "it.redcap@ubep.unipd.it"
  giro_cambiata(
    list(approvazione(anna), cambio(it)), approvato = sigillo_cambiata(),
    istanza = istanza_che_scrive(richiedenti = it), approvers = it
  )

  # test
  expect_equal(proprietari_scritti()[["owned_by"]], it)
})


test_that("owned_by si scrive dopo l'esito e prima del sigillo", {
  # eval
  giro_cambiata(
    list(approvazione(anna), cambio(bruno)), approvato = sigillo_cambiata(),
    istanza = istanza_che_scrive(richiedenti = bruno)
  )
  porta <- function(campi) {
    which(vapply(inviate, function(req) {
      any(vapply(importazioni(campi), identical, logical(1), req))
    }, logical(1)))
  }

  # test
  # The owner of a stretch is read below the seal that opens it, so the
  # owner has to stand below the seal of the same round.
  expect_lt(porta(campi_esito), porta(c("record_id", "owned_by")))
  expect_lt(
    porta(c("record_id", "owned_by")),
    porta(c("record_id", "applied_seal", "seal_state"))
  )
})


test_that("un giro che simula non passa la riga", {
  # eval
  giro(
    registro_con_log(
      record_json(utils::modifyList(
        riga_cambiata(), list(approved_seal = sigillo_cambiata())
      )),
      storia = list(approvazione(anna), cambio(bruno), esecuzione())
    ),
    istanza_che_scrive(richiedenti = bruno), dry_run = TRUE
  )

  # test
  # The owner door writes on a simulated round as the identity door does,
  # but nothing was applied, so the owner stays the one of today.
  expect_equal(proprietari_scritti()[["owned_by"]], anna)
})


test_that("senza l'account del canale il giro non scrive owned_by", {
  # eval
  giro_cambiata(
    list(approvazione(anna), cambio(bruno)), approvato = sigillo_cambiata(),
    istanza = istanza_che_scrive(richiedenti = bruno),
    channel_account = NULL
  )

  # test
  expect_null(proprietari_scritti())
})


# A register that refuses the owner door alone, as REDCap refuses an import
# it does not take, and answers everything else as `registro` does.
rifiuta_proprietari <- function(registro) {
  function(data) {
    if (identical(form_field_value(data[["action"]]), "import")) {
      sent <- jsonlite::fromJSON(
        form_field_value(data[["data"]]), simplifyVector = FALSE
      )
      if (length(sent) > 0L &&
            setequal(names(sent[[1L]]), c("record_id", "owned_by"))) {
        return('{"error":"The field owned_by could not be saved"}')
      }
    }
    registro(data)
  }
}


test_that("una porta del proprietario rifiutata arriva al record del giro, e il sigillo si scrive", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    rifiuta_proprietari(registro_con_log(
      record_json(utils::modifyList(
        riga_cambiata(), list(approved_seal = sigillo_cambiata())
      )),
      storia = list(approvazione(anna), cambio(bruno), esecuzione())
    )),
    istanza_che_scrive(richiedenti = bruno), dry_run = FALSE
  )

  # test
  # The passage is lost and the round says so, in its record and nowhere
  # else; the seal of what it carried out is written all the same.
  expect_length(importazioni(c("record_id", "owned_by")), 1L)
  expect_equal(esito[["errori"]], "TRASPORTO_REGISTRO_RIFIUTATO")
  expect_equal(
    as.character(sigilli_scritti()[["applied_seal"]]), sigillo_cambiata()
  )
})


accessi <- function(posta) {
  Filter(
    function(m) grepl("Accesso a REDCap", m[["subject"]], fixed = TRUE),
    posta[["mandate"]]()
  )
}


test_that("la concessione confermata manda la mail di accesso", {
  posta <- posta_raccolta()
  esito <- giro(
    registro_doppio(record_json(list())), istanza_che_scrive(),
    dry_run = FALSE, mailer = posta[["mailer"]]
  )
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_equal(
    vapply(accessi(posta), `[[`, "", "to"), "mario.rossi@example.org"
  )
  expect_identical(esito[["posta"]][["accessi_recapitati"]], 1L)
})


test_that("un banco riacceso o un accesso dato a mano non manda la mail", {
  for (prima in c("transport_error", "")) {
    posta <- posta_raccolta()
    esito <- giro(
      registro_doppio(record_json(list(outcome = prima))),
      istanza_doppia(list(), list(
        username = "mario.rossi@ubep.unipd.it", role_name = "data entry",
        user_rights = 0L
      )),
      dry_run = FALSE, mailer = posta[["mailer"]]
    )
    expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
    expect_length(accessi(posta), 0L)
  }
})


test_that("un ruolo cambiato non manda la mail", {
  posta <- posta_raccolta()
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list(), list(
      username = "mario.rossi@ubep.unipd.it", role_name = "read only",
      user_rights = 0L
    )),
    dry_run = FALSE, mailer = posta[["mailer"]]
  )
  # The update did go through: the instance answered the write and the
  # read-back shows the pair. Only a creation sends the access message.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_length(scritture(), 1L)
  expect_length(accessi(posta), 0L)
})


test_that("la riattivazione dopo una revoca manda la mail", {
  posta <- posta_raccolta()
  giro_cambiata(
    list(cambio(anna, "request_status = 'active'")),
    riga = riga_cambiata(role_name = "data entry", applied_as = "absent"),
    mailer = posta[["mailer"]]
  )
  expect_length(accessi(posta), 1L)
})


# A write the read-back does not show is not a grant: the next round finds
# the right in place and is `noop`, so this one is the only chance to send,
# and it must not, because nothing says the person has access.
test_that("una concessione che la rilettura non conferma non manda la mail", {
  posta <- posta_raccolta()
  esito <- giro(
    registro_doppio(record_json(list())), istanza_doppia(list()),
    dry_run = FALSE, mailer = posta[["mailer"]]
  )
  expect_equal(
    esito[["esiti"]][["outcome_detail"]], "TRASPORTO_SCRITTURA_NON_CONFERMATA"
  )
  expect_length(accessi(posta), 0L)
})


test_that("una revoca o un giro che simula non mandano la mail", {
  posta <- posta_raccolta()
  # Mario is there until the revoke, and gone from the read-back after it,
  # so the revoke is confirmed and comes back `applied`.
  revocato <- FALSE
  istanza_che_revoca <- function(data) {
    if (identical(data[["operation"]], "revoke") &&
          isFALSE(data[["dry_run"]])) {
      revocato <<- TRUE # nolint: assignment_linter.
    }
    righe <- if (revocato) list(list()) else con_mario(list())
    do.call(istanza_doppia, righe)(data)
  }
  revoca <- giro_cambiata(
    list(cambio(anna, "request_status = 'revoked'")), riga = revocata(),
    istanza = istanza_che_revoca, mailer = posta[["mailer"]]
  )
  # Read before the next round, which starts a new list of requests.
  expect_length(revoche(), 1L)
  simulato <- giro(
    registro_doppio(record_json(list())), istanza_che_scrive(),
    dry_run = TRUE, mailer = posta[["mailer"]]
  )
  # Both did what they were asked: the revoke was carried out, the
  # simulation planned the grant. Neither is a grant created this round.
  expect_equal(as.character(revoca[["esiti"]][["outcome"]]), "applied")
  expect_equal(as.character(simulato[["esiti"]][["outcome"]]), "simulated")
  expect_length(accessi(posta), 0L)
})


test_that("un referente che importa outcome e owned_by su una riga eseguita non la ferma", { # nolint: line_length_linter.
  # eval
  # Anna's row, applied and untouched since; Bruno imports a CSV that
  # carries the channel's columns, with values of his own. The seal does not
  # cover them, so nothing the row asks for has moved.
  fermo <- request_seal(riga_come_registro(
    record_id = "1", username = "mario.rossi@ubep.unipd.it"
  ))
  righe <- record_json(list(
    record_id = "1", username = "mario.rossi@ubep.unipd.it",
    identity = "existing", outcome = "held", applied_seal = fermo,
    seal_state = "intact", owned_by = bruno
  ))
  storia <- list(
    cambio(bruno, paste0("outcome = 'held', owned_by = '", bruno, "'")),
    esecuzione(fermo)
  )
  posta <- posta_raccolta()
  esito <- giro(
    registro_con_log(righe, storia = storia), istanza_che_scrive(),
    dry_run = FALSE, mailer = posta[["mailer"]], copy_to = "it@example.org"
  )

  # test
  # The row does not stop on our code, and it stays Anna's: the round
  # carries it out on her rights, rewrites its outcome, and writes her back
  # into the field.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_false(
    "TRASPORTO_AUTORE_NON_LEGGIBILE" %in% esito[["esiti"]][["outcome_detail"]]
  )
  expect_equal(proprietari_scritti()[["owned_by"]], anna)
  mandate <- posta[["mandate"]]()
  expect_false(bruno %in% vapply(mandate, `[[`, "", "to"))
})


test_that("dopo il cambio dell'account il passaggio scritto dal vecchio resta creduto", { # nolint: line_length_linter.
  # eval
  # The token's old account carried Bruno's change out and passed the row to
  # him; Bruno has changed the expiration since.
  vecchio <- "svc-canale-vecchio"
  dal_vecchio <- function(evento) {
    utils::modifyList(evento, list(username = vecchio))
  }
  storia <- list(
    cambio(bruno, "expiration = '2027-01-31'"),
    dal_vecchio(esecuzione("111111111111")), dal_vecchio(passaggio(bruno)),
    approvazione(anna, "111111111111"), cambio(bruno),
    dal_vecchio(esecuzione())
  )
  con <- function(account) {
    giro(
      registro_con_log(
        record_json(riga_cambiata(
          expiration = "2027-01-31", applied_seal = "111111111111"
        )),
        storia = storia
      ),
      istanza_che_scrive(richiedenti = bruno), dry_run = FALSE,
      channel_account = account
    )
  }

  # test
  # Both accounts listed: the passage stands, the row is Bruno's, and his
  # own change is carried out on his rights.
  entrambi <- con(c("svc-canale-ubep", vecchio))
  expect_equal(as.character(entrambi[["esiti"]][["outcome"]]), "applied")
  # The new account alone, which has written nothing on this register yet:
  # every write of the channel would read as somebody else's, so the round
  # stops before judging anything.
  solo_nuovo <- con("svc-canale-ubep")
  expect_true(solo_nuovo[["fermato"]])
  expect_equal(solo_nuovo[["errori"]], "TRASPORTO_REGISTRO_CANALE_ASSENTE")
})


# A referent's CSV that writes the seal along with the row: the seal is a
# public hash, and the field is written by an import as any other.
sigillo_importato <- function(sigillo, details = "role_name = 'read only'") {
  cambio(bruno, paste0(details, ", applied_seal = '", sigillo, "'"))
}


test_that("chi cambia il ruolo e importa il sigillo della riga cambiata la ferma", { # nolint: line_length_linter.
  # eval
  # Anna's applied row. Bruno changes the role and imports, in the same CSV,
  # the seal of the row as he changed it: compared with the field, the row
  # would look untouched.
  cambiata <- riga_cambiata()
  falso <- request_seal(do.call(riga_come_registro, cambiata))
  posta <- posta_raccolta()
  esito <- giro(
    registro_con_log(
      record_json(utils::modifyList(cambiata, list(applied_seal = falso))),
      storia = list(sigillo_importato(falso), esecuzione())
    ),
    istanza_che_scrive(richiedenti = c(anna, bruno)), dry_run = FALSE,
    mailer = posta[["mailer"]]
  )

  # test
  # The seal the round compares against is the channel's, from the log: the
  # row changed, Bruno changed it, and it waits for Anna.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
  mandate <- posta[["mandate"]]()
  expect_equal(vapply(mandate, `[[`, "", "to"), anna)
  expect_match(mandate[[1L]][["body"]], bruno, fixed = TRUE)
})


test_that("ruolo e sigillo nello stesso evento di un altro: dopo l'approvazione si guardano i suoi diritti", { # nolint: line_length_linter.
  # eval
  # Bruno writes the role and a seal of his own in one event; Anna approves
  # the row as it stands.
  storia <- list(
    approvazione(anna), sigillo_importato("ffffffffffff")
  )
  con <- function(richiedenti) {
    giro_cambiata(
      storia, approvato = sigillo_cambiata(),
      riga = riga_cambiata(applied_seal = "ffffffffffff"),
      istanza = istanza_che_scrive(richiedenti = richiedenti)
    )
  }
  senza_bruno <- con(anna)
  chiesti <- chiesti_allo_stato()
  con_bruno <- con(c(anna, bruno))

  # test
  # The change is Bruno's, and his rights are the ones asked.
  expect_equal(
    as.character(senza_bruno[["esiti"]][["outcome_detail"]]),
    "DATO_AMBITO_NON_AUTORIZZATO"
  )
  expect_true(bruno %in% chiesti)
  expect_equal(as.character(con_bruno[["esiti"]][["outcome"]]), "applied")
})


test_that("un sigillo importato da solo lascia la riga intatta, e il canale lo riscrive", { # nolint: line_length_linter.
  # eval
  # Anna's applied row, untouched; Bruno imports a seal and nothing else.
  fermo <- request_seal(riga_come_registro(
    record_id = "1", username = "mario.rossi@ubep.unipd.it"
  ))
  righe <- record_json(list(
    record_id = "1", username = "mario.rossi@ubep.unipd.it",
    identity = "existing", outcome = "applied",
    applied_seal = "ffffffffffff", seal_state = "intact"
  ))
  esito <- giro(
    registro_con_log(
      righe,
      storia = list(
        cambio(bruno, "applied_seal = 'ffffffffffff'"), esecuzione(fermo)
      )
    ),
    istanza_che_scrive(), dry_run = FALSE
  )

  # test
  # Nothing the row asks for moved: it is carried out on Anna's rights, and
  # the field gets back the channel's seal.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_equal(as.character(sigilli_scritti()[["applied_seal"]]), fermo)
})


test_that("una riga mai sigillata dal canale e' mai eseguita, qualunque sigillo porti", { # nolint: line_length_linter.
  # eval
  # Anna's new row, never carried out. Bruno changes the role and imports the
  # seal of the row as he changed it.
  cambiata <- list(record_id = "1", role_name = "read only")
  falso <- request_seal(do.call(riga_come_registro, cambiata))
  posta <- posta_raccolta()
  esito <- giro(
    registro_con_log(
      record_json(utils::modifyList(cambiata, list(applied_seal = falso))),
      storia = list(sigillo_importato(falso))
    ),
    istanza_che_scrive(richiedenti = c(anna, bruno)), dry_run = FALSE,
    mailer = posta[["mailer"]]
  )

  # test
  # Compared with the field, the row would read as applied and untouched,
  # and Bruno's role would be granted on Anna's rights. The channel never
  # sealed it, so it is a row waiting for its first execution, and Bruno's
  # hand in it waits for Anna.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
  expect_equal(vapply(posta[["mandate"]](), `[[`, "", "to"), anna)
})


test_that("senza il log dei proprietari il sigillo del campo non fa eseguire niente", { # nolint: line_length_linter.
  # eval
  # The same forged row, on a round whose owners' log cannot be read: the
  # seal is the field's, as before, and the row looks untouched.
  cambiata <- riga_cambiata()
  falso <- request_seal(do.call(riga_come_registro, cambiata))
  esito <- giro(
    registro_doppio(
      record_json(utils::modifyList(cambiata, list(applied_seal = falso))),
      proprietari = '{"error":"You do not have Logging privileges"}'
    ),
    istanza_che_scrive(richiedenti = c(anna, bruno)), dry_run = FALSE
  )

  # test
  # No owner this round, so nobody whose rights the gate could ask: the row
  # waits on our code.
  expect_equal(
    as.character(esito[["esiti"]][["outcome_detail"]]),
    "TRASPORTO_AUTORE_NON_LEGGIBILE"
  )
  expect_length(scritture(), 0L)
})


# Anna's applied row: Bruno changed the role, Anna approved, and Bruno also
# imported his own name into `owned_by`, so the field already says what the
# passage this round decides will say.
giro_passaggio_anticipato <- function(registro = identity, ...) {
  giro(
    registro(registro_con_log(
      record_json(utils::modifyList(
        riga_cambiata(owned_by = bruno),
        list(approved_seal = sigillo_cambiata())
      )),
      storia = list(approvazione(anna), cambio(bruno), esecuzione())
    )),
    istanza_che_scrive(richiedenti = bruno), dry_run = FALSE, ...
  )
}


test_that("un passaggio che il campo mostra gia' si registra con due scritture", { # nolint: line_length_linter.
  # eval
  esito <- giro_passaggio_anticipato()

  # test
  # REDCap logs no write that leaves a value as it was, so writing Bruno
  # over Bruno would leave the log without the passage. The door writes the
  # owner of today first, then Bruno: two writes of the channel, the newest
  # one the passage.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_equal(proprietari_scritti()[["owned_by"]], c(anna, bruno))
  expect_false("TRASPORTO_PASSAGGIO_NON_REGISTRATO" %in% esito[["errori"]])
})


test_that("un passaggio che non si registra lo dice nel record del giro", {
  # eval
  # The register refuses the first of the two writes, the owner of today.
  rifiuta_anna <- function(registro) {
    function(data) {
      if (identical(form_field_value(data[["action"]]), "import")) {
        sent <- jsonlite::fromJSON(
          form_field_value(data[["data"]]), simplifyVector = FALSE
        )
        if (length(sent) > 0L && identical(sent[[1L]][["owned_by"]], anna)) {
          return('{"error":"The field owned_by could not be saved"}')
        }
      }
      registro(data)
    }
  }
  esito <- giro_passaggio_anticipato(rifiuta_anna)

  # test
  # The field already said Bruno, so the door has nothing left to write, and
  # the passage is not in the log: the round's record says so.
  expect_length(importazioni(c("record_id", "owned_by")), 1L)
  expect_true("TRASPORTO_PASSAGGIO_NON_REGISTRATO" %in% esito[["errori"]])
  expect_true("TRASPORTO_REGISTRO_RIFIUTATO" %in% esito[["errori"]])
})


test_that("un sigillo che il log non puo' ricevere lo dice nel record del giro", { # nolint: line_length_linter.
  # eval
  # Bruno changed the role and imported the seal of the changed row; Anna
  # approved it, and the round carries it out on Bruno's rights. The seal it
  # would write is the one the field holds already, and REDCap logs no write
  # that leaves a value as it was: the log keeps the old seal of the channel.
  cambiata <- riga_cambiata()
  falso <- request_seal(do.call(riga_come_registro, cambiata))
  esito <- giro(
    registro_con_log(
      record_json(utils::modifyList(
        cambiata, list(applied_seal = falso, approved_seal = falso)
      )),
      storia = list(
        approvazione(anna, falso), sigillo_importato(falso), esecuzione()
      )
    ),
    istanza_che_scrive(richiedenti = c(anna, bruno)), dry_run = FALSE
  )

  # test
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_true("TRASPORTO_SIGILLO_NON_REGISTRATO" %in% esito[["errori"]])
})


test_that("un'utenza del canale che il log non ha mai visto ferma il giro", {
  # eval
  # Anna's applied row, sealed by the channel; the machine names an account
  # that never wrote on this register, a typo or the old one dropped too
  # early.
  posta <- posta_raccolta()
  esito <- giro_cambiata(
    list(cambio(anna)), istanza = istanza_che_scrive(),
    mailer = posta[["mailer"]], channel_account = "svc-canale-sbagliato"
  )

  # test
  # Read with that name, every seal and every passage of the channel would
  # be somebody else's: rows back to their creators, every change held. The
  # round stops before it judges or writes anything, and says why.
  expect_true(esito[["fermato"]])
  expect_equal(esito[["errori"]], "TRASPORTO_REGISTRO_CANALE_ASSENTE")
  expect_length(importazioni(), 0L)
  expect_length(scritture(), 0L)
  expect_length(posta[["mandate"]](), 0L)
})


test_that("su un registro nuovo un'utenza mai vista non ferma il giro", {
  # eval
  # Nothing has been sealed yet: there is no channel to have seen. The
  # double signs the round's own writes with the account configured.
  esito <- giro(
    registro_con_log(
      record_json(list(record_id = "1")), canale = "svc-canale-nuovo"
    ),
    istanza_che_scrive(), dry_run = FALSE,
    channel_account = "svc-canale-nuovo"
  )

  # test
  expect_false(esito[["fermato"]])
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
})


test_that("una scrittura scoperta che il proprietario riscrive non ferma la sua revoca", { # nolint: line_length_linter.
  # eval
  # Anna's row. A round sealed Anna's own change of the role; Cinzia, who
  # does not manage 9003, wrote the role while it ran, below its seal. Anna
  # changed the role and put it back, so no round sealed the row again, and
  # then revoked.
  eseguita <- sigillo_cambiata()
  esito <- giro_cambiata(
    list(
      cambio(anna, "request_status = 'revoked'"),
      cambio(anna, "role_name = 'read only'"),
      cambio(anna, "role_name = 'zz'"),
      esecuzione(eseguita),
      cambio(cinzia, "role_name = 'admin'"),
      cambio(anna, "role_name = 'read only'")
    ),
    riga = riga_cambiata(request_status = "revoked", applied_seal = eseguita),
    istanza = istanza_che_scrive(richiedenti = anna)
  )
  chiesti <- chiesti_allo_stato()

  # test
  # Cinzia's write is no longer in the row. Counted, it would hold the row,
  # and after Anna's approval the gate would ask Cinzia's rights and refuse
  # the revocation on every round.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_false(cinzia %in% chiesti)
})


test_that("chi riporta sopra il sigillo il valore di una scrittura scoperta ferma la riga", { # nolint: line_length_linter.
  # eval
  # The same stretch; above the seal Bruno moves the role and brings it to
  # Cinzia's value.
  eseguita <- sigillo_cambiata()
  posta <- posta_raccolta()
  esito <- giro_cambiata(
    list(
      cambio(bruno, "role_name = 'admin'"),
      cambio(bruno, "role_name = 'zz'"),
      esecuzione(eseguita),
      cambio(cinzia, "role_name = 'admin'"),
      cambio(anna, "role_name = 'read only'")
    ),
    riga = riga_cambiata(role_name = "admin", applied_seal = eseguita),
    istanza = istanza_che_scrive(richiedenti = c(anna, bruno)),
    mailer = posta[["mailer"]]
  )

  # test
  # Cinzia's value was never carried out, so it is not the value to compare
  # with: Bruno's write is a change, and the row waits for Anna.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
  mandate <- posta[["mandate"]]()
  expect_equal(vapply(mandate, `[[`, "", "to"), anna)
  expect_match(mandate[[1L]][["body"]], paste0("Modificata da: ", bruno),
               fixed = TRUE)
})
