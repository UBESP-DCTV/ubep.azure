#' Run one round of the channel
#'
#' The only function that holds the register and the instances at the same
#' time, and the only place a write can start from. Everything it decides is
#' decided by the pure layer; what lives here is the order of the questions,
#' and the order is the design:
#'
#' 1. compare the register's dictionary and stop if the drift changes what a
#'    round reads;
#' 2. read the register;
#' 3. turn it into the desired state, keeping the form errors;
#' 4. per instance, read the state **once** for the grantees and the requesters
#'    together;
#' 5. ask the scope gate about the instances that answered, and only those;
#' 6. diff against the real rows somebody asked about;
#' 7. batch by `(server, project_id)`, never across two projects;
#' 8. write back the outcome, and only what changed.
#'
#' Idempotent by construction: a round interrupted between applying and writing
#' the outcome leaves the row as still to do, and the next round applies it
#' again. That is harmless because the diff finds it already conforming and
#' classifies it `noop` — and it is the reason the job can be killed at any
#' moment without repair.
#'
#' A `project_id` the register accepted but that is not a number is named here
#' with `DATO_PROGETTO_INESISTENTE` right after the pure layer runs, and before
#' the scope gate ever sees the row. The row may not be a pair yet — `username`
#' stays blank until the identity is resolved, which is the ordinary state in
#' this version — so `register_to_desired()` never validated it, while
#' `scope_pairs()` admits it on `requested_by` alone. Left to the gate it would
#' come back as a scope refusal, "you may not ask for that project", when the
#' truth is "that is not a project number" — a data error the referent can act
#' on, not a permission they are sent to go ask for when they already hold it.
#'
#' @param register_url,register_token The register's host and API token.
#' @param hosts Named character vector, instance name to hostname, optionally
#'   carrying the path REDCap is mounted under. The register names instances
#'   (`edc10`); only this map knows where they are.
#' @param secrets Named character vector, instance name to shared secret. An
#'   instance whose secret could not be read is named here with `NA` rather
#'   than left out, so the two failures stay distinguishable.
#' @param instances The fleet, in the order the register's `server` field
#'   carries it, for the dictionary comparison. `NULL` compares the other
#'   fields and declares the substitution.
#' @param dry_run Whether to simulate. Defaults to `TRUE`, and the write path
#'   has to be asked for.
#' @param at When the round ran, as `YYYY-MM-DD HH:MM`.
#'
#' @return A list with `at`, `fermato`, `schema`, `istanze`, `esiti`,
#'   `scritte` and `errori`.
#'
#' @keywords internal
provisioning_reconcile <- function(register_url,
                                   register_token,
                                   hosts,
                                   secrets,
                                   instances = NULL,
                                   dry_run = TRUE,
                                   at = format(
                                     Sys.time(), "%Y-%m-%d %H:%M", tz = "UTC"
                                   )) {
  stopifnot(
    is.character(hosts), !is.null(names(hosts)),
    is.character(secrets), !is.null(names(secrets)),
    is.logical(dry_run), length(dry_run) == 1L, !is.na(dry_run),
    is.character(at), length(at) == 1L
  )

  if (!dry_run) {
    stop(
      "provisioning_reconcile(): the write path is not wired yet. A round can ",
      "simulate correctly and still be wrong about writing, because the ",
      "read-back that `applied` has to mean does not exist here.",
      call. = FALSE
    )
  }

  empty_outcomes <- outcome_payload("", "pending")[0, , drop = FALSE]
  empty_instances <- data.frame(
    server = character(), raggiunta = logical(),
    ambito_leggibile = logical(), errori = character(),
    stringsAsFactors = FALSE
  )

  halted <- function(errors, schema = NULL) {
    list(
      at = at, fermato = TRUE, schema = schema, istanze = empty_instances,
      esiti = empty_outcomes, scritte = 0L, errori = errors
    )
  }

  # 1. the schema, before anything reads a record. A dictionary that drifted is
  # also a dictionary register_to_desired() would meet as a missing column, and
  # a stopifnot() is a worse place to learn it than a gate that says so.
  metadata <- register_metadata(register_url, register_token)
  if (!isTRUE(metadata[["ok"]])) {
    return(halted(metadata[["errors"]]))
  }

  schema <- round_schema_verdict(
    compare_dictionary(metadata[["dictionary"]], instances)[["differences"]]
  )
  if (isTRUE(schema[["blocks"]])) {
    return(halted("DIZIONARIO_DERIVATO", schema = schema))
  }

  # 2. the register
  reading <- register_records(register_url, register_token)
  if (!isTRUE(reading[["ok"]])) {
    return(halted(reading[["errors"]], schema = schema))
  }

  register <- reading[["records"]]
  quiet <- list(
    at = at, fermato = FALSE, schema = schema, istanze = empty_instances,
    esiti = empty_outcomes, scritte = 0L, errori = character()
  )
  if (nrow(register) == 0L) {
    return(quiet)
  }

  # 3. the pure layer
  plan <- register_to_desired(register)
  asks <- scope_pairs(register)

  # A project_id the register accepted but that is not a number is a data
  # error, and it has to be named here. The row may not be a pair yet —
  # `username` stays blank until the identity is resolved — so
  # `register_to_desired()` never validated it, while `scope_pairs()` admits it
  # on `requested_by` alone. Left to the gate it would come back as a scope
  # refusal: "you may not ask for that project" instead of "that is not a
  # project number", which sends the referent to ask for a permission they
  # already hold.
  numbers <- suppressWarnings(
    as.integer(trimws(as.character(register[["project_id"]])))
  )
  malformed <- scope_filled(register[["project_id"]]) & is.na(numbers)

  row_errors <- plan[["errors"]]
  for (id in as.character(register[["record_id"]])[malformed]) {
    if (is.null(row_errors[[id]])) {
      row_errors[[id]] <- "DATO_PROGETTO_INESISTENTE"
    }
  }

  outcome_rows <- function(ids, outcome, detail = "", applied_as = "") {
    if (length(ids) == 0L) {
      return(empty_outcomes)
    }
    do.call(rbind, lapply(ids, function(id) {
      outcome_payload(
        as.character(id), outcome,
        detail = paste(detail, collapse = ","), at = at,
        applied_as = applied_as
      )
    }))
  }

  form_errors <- outcome_rows(character(), "pending")
  if (length(row_errors) > 0L) {
    form_errors <- do.call(rbind, lapply(
      names(row_errors),
      function(id) {
        outcome_payload(
          id, "data_error",
          detail = paste(row_errors[[id]], collapse = ","), at = at
        )
      }
    ))
  }

  entries <- c(plan[["desired"]], plan[["revoked"]])
  servers <- sort(unique(c(
    vapply(entries, function(e) as.character(e[["server"]]), character(1)),
    asks[["server"]]
  )))

  # 4. one instance at a time
  per_instance <- lapply(servers, function(server) {
    rows <- register[
      trimws(as.character(register[["server"]])) == server, ,
      drop = FALSE
    ]
    # A row already carrying a form error keeps that outcome: it is the earlier
    # and more specific verdict, and the register takes one outcome per record.
    ids <- setdiff(as.character(rows[["record_id"]]), names(row_errors))

    unreachable <- function(code) {
      list(
        stato = data.frame(
          server = server, raggiunta = FALSE, ambito_leggibile = NA,
          errori = paste(code, collapse = ","), stringsAsFactors = FALSE
        ),
        esiti = outcome_rows(ids, "transport_error", detail = code)
      )
    }

    if (!server %in% names(hosts)) {
      return(unreachable("TRASPORTO_ISTANZA_SENZA_MODULO"))
    }
    if (!server %in% names(secrets) || is.na(secrets[[server]])) {
      return(unreachable("TRASPORTO_SEGRETO_NON_LEGGIBILE"))
    }

    mine <- function(collection) {
      Filter(
        function(e) identical(as.character(e[["server"]]), server), collection
      )
    }
    wanted <- mine(plan[["desired"]])
    revoked <- mine(plan[["revoked"]])

    state <- module_state(
      hosts[[server]], secrets[[server]],
      pairs = round_state_pairs(
        c(wanted, revoked),
        asks[asks[["server"]] == server, , drop = FALSE]
      )
    )

    if (!isTRUE(state[["ok"]])) {
      return(unreachable(state[["errors"]]))
    }

    # 5. the gate, asked only of an instance that answered this question
    if (!round_scope_readable(state)) {
      answer <- unreachable("TRASPORTO_AMBITO_NON_LEGGIBILE")
      answer[["stato"]][["raggiunta"]] <- TRUE
      answer[["stato"]][["ambito_leggibile"]] <- FALSE
      return(answer)
    }

    refused <- scope_errors(rows, round_rights(server, state))
    refused <- refused[names(refused) %in% ids]
    in_scope <- function(e) {
      !as.character(e[["record_id"]]) %in% names(refused)
    }
    wanted <- Filter(in_scope, wanted)
    revoked <- Filter(in_scope, revoked)

    results <- state[["payload"]][["results"]] %||% list()

    # 6. the diff, against the real rows somebody asked about and no others
    diff <- provisioning_diff(wanted, round_actual(results, wanted))
    action <- as.character(diff[["action"]])
    names(action) <- paste(
      diff[["username"]], diff[["project_id"]], sep = "\r"
    )
    acted <- function(e) {
      action[[paste(
        trimws(as.character(e[["username"]])),
        as.integer(e[["project_id"]]),
        sep = "\r"
      )]]
    }

    conforming <- Filter(function(e) identical(acted(e), "noop"), wanted)
    to_apply <- Filter(
      function(e) acted(e) %in% c("creato", "aggiornato"), wanted
    )
    present <- function(e) length(round_actual(results, list(e))) > 0L
    to_revoke <- Filter(present, revoked)
    already_gone <- Filter(Negate(present), revoked)

    settled <- do.call(rbind, c(
      list(empty_outcomes),
      lapply(conforming, function(e) {
        outcome_payload(
          as.character(e[["record_id"]]),
          round_outcome_kind(character(), dry_run), at = at,
          applied_as = round_applied_as(round_actual(results, list(e))[[1]])
        )
      }),
      lapply(already_gone, function(e) {
        outcome_payload(
          as.character(e[["record_id"]]),
          round_outcome_kind(character(), dry_run), at = at,
          applied_as = round_applied_as(NULL)
        )
      })
    ))

    # 7. one batch per project, never across two
    batches <- c(
      lapply(round_batches(to_apply), function(b) c(b, list(op = "apply"))),
      lapply(round_batches(to_revoke), function(b) c(b, list(op = "revoke")))
    )

    written <- do.call(rbind, c(
      list(empty_outcomes),
      lapply(batches, function(batch) {
        call <- if (identical(batch[["op"]], "apply")) {
          module_apply
        } else {
          module_revoke
        }
        answer <- call(
          hosts[[server]], secrets[[server]],
          requests = batch[["requests"]], dry_run = dry_run
        )

        if (!isTRUE(answer[["ok"]])) {
          return(outcome_rows(
            batch[["record_ids"]], "transport_error",
            detail = answer[["errors"]]
          ))
        }

        by_pair <- batch[["record_ids"]]
        names(by_pair) <- vapply(batch[["requests"]], function(r) {
          paste(r[["username"]], r[["project_id"]], sep = "\r")
        }, character(1))

        do.call(rbind, c(
          list(empty_outcomes),
          lapply(answer[["payload"]][["results"]] %||% list(), function(entry) {
            key <- paste(
              as.character(entry[["username"]]),
              as.integer(entry[["project_id"]]),
              sep = "\r"
            )
            id <- by_pair[[key]] %||% NA_character_
            if (is.na(id)) {
              return(empty_outcomes)
            }
            codes <- vapply(
              entry[["errors"]] %||% list(),
              function(error) as.character(error[["code"]]),
              character(1)
            )
            outcome_payload(
              id, round_outcome_kind(codes, dry_run),
              detail = paste(codes, collapse = ","), at = at,
              applied_as = round_applied_as(entry[["after"]])
            )
          })
        ))
      })
    ))

    list(
      stato = data.frame(
        server = server, raggiunta = TRUE, ambito_leggibile = TRUE,
        errori = NA_character_, stringsAsFactors = FALSE
      ),
      esiti = do.call(rbind, list(
        outcome_rows(names(refused), "data_error",
                     detail = "DATO_AMBITO_NON_AUTORIZZATO"),
        settled,
        written
      ))
    )
  })

  outcomes <- do.call(rbind, c(
    list(form_errors),
    lapply(per_instance, function(answer) answer[["esiti"]])
  ))
  # One outcome per record, and the first one wins: a form error is the earlier
  # and more specific verdict, and two rows with the same record_id in one
  # import body is a write whose result depends on the order REDCap applies
  # them in.
  outcomes <- outcomes[!duplicated(outcomes[["record_id"]]), , drop = FALSE]

  # 8. only what changed
  changed <- round_changed(register, outcomes)
  import <- register_import(register_url, register_token, changed)

  list(
    at = at,
    fermato = FALSE,
    schema = schema,
    istanze = do.call(
      rbind, lapply(per_instance, function(answer) answer[["stato"]])
    ) %||% empty_instances,
    esiti = outcomes,
    scritte = import[["scritte"]],
    errori = import[["errors"]]
  )
}
