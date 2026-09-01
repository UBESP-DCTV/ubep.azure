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
registro_doppio <- function(records, eventi = "[]") {
  function(data) {
    if (identical(form_field_value(data[["content"]]), "metadata")) {
      return(dizionario_json())
    }
    if (identical(form_field_value(data[["content"]]), "log")) {
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
      requested_by = "anna.bianchi@ubep.unipd.it",
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


giro <- function(registro,
                 istanza,
                 directory = directory_doppia(),
                 creazione = creazione_riuscita(),
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
  esito <- giro(
    registro_doppio(record_json(
      list(record_id = "1"),
      list(record_id = "2", first_name = "Giulia", last_name = "Verdi",
           contact_email = "giulia.verdi@example.org", project_id = "9004")
    )),
    istanza_muta()
  )
  esiti <- esito[["esiti"]]

  # test
  expect_equal(
    esiti[["outcome"]][esiti[["record_id"]] == "1"], "transport_error"
  )
  expect_equal(esiti[["outcome"]][esiti[["record_id"]] == "2"], "pending")
})


test_that("an absence in scope is created, under the name the round found free", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE
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
    directory_vuota()
  )

  # test
  # `UBEP_SCRITTURA` off means the round says what it would do, and creating a
  # person is not saying anything. It is the same line the instance writes are
  # on, and the one place it could have been forgotten: a creation is not a
  # write on an instance, so nothing else in the round would have stopped it.
  expect_length(creazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "pending")
})


test_that("nobody is created for a row whose requester could not have granted it", { # nolint: line_length_linter.
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(
      list(username = "anna.bianchi@ubep.unipd.it", user_rights = 0L)
    ),
    directory_vuota(),
    dry_run = FALSE
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
    dry_run = FALSE
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
    dry_run = FALSE
  )

  # test
  # An instance that did not answer has not said "yes" and has not said "no".
  # Fail closed: the row waits, and the next round asks again. Creating on an
  # unanswered question would make the gate a thing that holds only while the
  # network does.
  expect_length(creazioni(), 0L)
  expect_equal(esito[["esiti"]][["outcome"]], "pending")
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
    dry_run = FALSE
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


test_that("the credential leaves by one road and is on none of the others", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list())),
    istanza_doppia(list()),
    directory_vuota(),
    dry_run = FALSE
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
      mandate <<- mandate + 1L # nolint: assignment_linter.
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
      corpo <<- body # nolint: assignment_linter.
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


test_that("una riga cambiata dopo l'applicazione non si riapplica da sola", {
  # eval
  esito <- giro(
    registro_doppio(record_json(list(
      record_id = "1", outcome = "applied",
      applied_seal = "000000000000"
    ))),
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


test_that("lo username che il giro risolve non fa sembrare modificata la riga", {
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


test_that("l'approvazione di un terzo sblocca la riga, e la risigilla", {
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
          username = "cinzia.rossi@ubep.unipd.it",
          details = paste0("approved_seal = '", approvato, "'")
        ),
        list(
          username = "bruno.verdi@ubep.unipd.it",
          details = "role_name = 'data entry'"
        )
      )
    ),
    istanza_che_scrive(),
    dry_run = FALSE
  )

  # test
  # The other half of the protection, and the half that has to work or the
  # register fills up with rows nobody can ever clear. The approval carries
  # this row's seal and comes from somebody who did not make the change, so
  # the round applies it -- and seals the row again, at its new value, so the
  # approval covers this change and stops there.
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "applied")
  expect_equal(
    as.character(sigilli_scritti()[["applied_seal"]]), risigillato
  )
  expect_equal(as.character(sigilli_scritti()[["seal_state"]]), "intact")
})


test_that("un registro degli eventi illeggibile lascia la riga trattenuta", {
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
  expect_equal(as.character(esito[["esiti"]][["outcome"]]), "held")
  expect_length(scritture(), 0L)
})
