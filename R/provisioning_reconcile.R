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
#' 3. resolve **who each row is talking about**, against the tenant read whole,
#'    and write the verdict back;
#' 4. turn what the gate admits into the desired state, keeping the form
#'    errors;
#' 5. per instance, read the state **once** for the grantees and the requesters
#'    together;
#' 6. ask the scope gate about the instances that answered, and only those;
#' 7. diff against the real rows somebody asked about;
#' 8. batch by `(server, project_id)`, never across two projects;
#' 9. read back what a real write did, before calling it applied;
#' 10. write back the outcome, and only what changed.
#'
#' **Step 3 is a step of this round and not a job of its own** — decision 2 of
#' the design — and the reason is latency: resolving and acting have the same
#' cadence and the second consumes the first, so a resolver on a timer of its
#' own would make every new row wait one more cycle to be looked at. It follows
#' that the gate has no window at all: it asks after the verdict it has just
#' computed, never after the one the register carries, and writing `identity`
#' back is the minutes of the verdict rather than the input to the next step.
#'
#' Idempotent by construction: a round interrupted between applying and writing
#' the outcome leaves the row as still to do, and the next round applies it
#' again. That is harmless because the diff finds it already conforming and
#' classifies it `noop` — and it is the reason the job can be killed at any
#' moment without repair.
#'
#' A `project_id` the register accepted but that is not a number is named here
#' with `DATO_PROGETTO_INESISTENTE` right after the pure layer runs, and before
#' the scope gate ever sees the row. `validate_request()` catches the ones that
#' will not coerce; this catches the ones that coerce to something else, since
#' `as.integer("9003.7")` is `9003L` and not `NA`, while `scope_pairs()` admits
#' the row on `requested_by` alone. Left to the gate it would come back as a
#' scope refusal, "you may not ask for that project", when the truth is "that
#' is not a project number" — a data error the referent can act on, not a
#' permission they are sent to go ask for when they already hold it.
#'
#' @param register_url,register_token The register's host and API token.
#' @param hosts Named character vector, instance name to hostname, optionally
#'   carrying the path REDCap is mounted under. The register names instances
#'   (`edc10`); only this map knows where they are.
#' @param secrets Named character vector, instance name to shared secret. An
#'   instance whose secret could not be read is named here with `NA` rather
#'   than left out, so the two failures stay distinguishable.
#' @param graph_token,graph_url The Microsoft Graph access token and endpoint
#'   the sweep of step 3 is made with. Both are arguments and neither has a
#'   default: this repository is public, and an endpoint written in is an
#'   endpoint published. An empty endpoint is not an error here but a sweep
#'   that could not start, which is what the parameters sheet says a missing
#'   `UBEP_GRAPH` does — every row takes a transport error instead of a
#'   verdict, rather than the round dying with a message nobody reads.
#' @param instances The fleet, in the order the register's `server` field
#'   carries it, for the dictionary comparison. `NULL` compares the other
#'   fields and declares the substitution.
#' @param dry_run Whether to simulate. Defaults to `TRUE`.
#' @param at When the round ran, as `YYYY-MM-DD HH:MM`.
#'
#' @return A list with `at`, `fermato`, `schema`, `istanze`, `esiti`,
#'   `scritte` and `errori`. `scritte` counts the outcomes REDCap took and not
#'   the identities: they are two writes into two field families, and one
#'   counter for both would be a number nobody could read back into either.
#'
#' @keywords internal
provisioning_reconcile <- function(register_url,
                                   register_token,
                                   hosts,
                                   secrets,
                                   graph_token,
                                   graph_url,
                                   instances = NULL,
                                   dry_run = TRUE,
                                   at = format(
                                     Sys.time(), "%Y-%m-%d %H:%M", tz = "UTC"
                                   )) {
  stopifnot(
    is.character(hosts), !is.null(names(hosts)),
    is.character(secrets), !is.null(names(secrets)),
    is.character(graph_token), length(graph_token) == 1L,
    is.character(graph_url), length(graph_url) == 1L,
    is.logical(dry_run), length(dry_run) == 1L, !is.na(dry_run),
    is.character(at), length(at) == 1L
  )

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

  record_ids <- as.character(register[["record_id"]])

  # 3. who each row is talking about. The sweep reads the tenant whole because
  # the contact address is not filterable server-side, which also makes the
  # comparison ours and therefore able to normalize -- 74 accounts carry the
  # address with spaces at the edges, and an `eq` would have called all 74
  # `absent`, which is the verdict that opens the creation branch.
  #
  # An endpoint that is not there is not a crash: the parameters sheet says a
  # missing `UBEP_GRAPH` means the sweep does not start and every row takes a
  # transport error, and a `stopifnot()` here would instead kill the round with
  # a message that reaches nobody, since a round that does not return leaves no
  # record and `ubep-canale-assenza` then says the channel is not running.
  sweep <- if (nzchar(graph_url) && nzchar(graph_token)) {
    directory_users(graph_token, graph_url)
  } else {
    list(
      ok = FALSE, errors = "TRASPORTO_DIRECTORY_SENZA_ENDPOINT", users = NULL
    )
  }

  # A sweep that failed is a transport error on every row, and the round asks
  # no instance anything. "I could not ask" is not "you are not the one", so
  # the rows go back in the queue rather than closing against whoever filed
  # them. And nothing is acted on: the `identity` the register still carries
  # was confirmed by some earlier round and by nothing in this one, so granting
  # under it would be granting under a verdict nobody produced this pass --
  # which is the same reason the gate reads the value it has just computed.
  if (!isTRUE(sweep[["ok"]])) {
    outcomes <- outcome_rows(
      record_ids, "transport_error", detail = sweep[["errors"]]
    )
    import <- register_import(
      register_url, register_token, round_changed(register, outcomes)
    )
    return(list(
      at = at, fermato = FALSE, schema = schema, istanze = empty_instances,
      esiti = outcomes, scritte = import[["scritte"]],
      errori = import[["errors"]]
    ))
  }

  resolutions <- lapply(seq_len(nrow(register)), function(i) {
    resolve_identity(as.list(register[i, , drop = FALSE]), sweep[["users"]])
  })
  verdicts <- vapply(
    resolutions, function(answer) as.character(answer[["identity"]]),
    character(1)
  )
  resolved_names <- vapply(
    resolutions, function(answer) as.character(answer[["username"]]),
    character(1)
  )

  # The minutes of the verdict, written through the door that takes nothing
  # else, and only for the rows it moved. `register` is the register as read
  # and stays that way: it is what the two comparisons below are made against,
  # and a frame already carrying this round's answers would compare a value
  # with itself and report that nothing ever changes.
  identity_written <- register_identity_import(
    register_url, register_token,
    round_changed(
      register,
      do.call(rbind, c(
        list(identity_payload("", "", "")[0, , drop = FALSE]),
        lapply(seq_along(record_ids), function(i) {
          identity_payload(record_ids[[i]], resolved_names[[i]], verdicts[[i]])
        })
      )),
      fields = c("username", "identity")
    )
  )

  # What the gate refuses stops here and enters nothing that follows: not the
  # desired state, not the scope question, not an instance. `absent` waits
  # rather than closing -- the round will create the account itself once task 6
  # lands -- and the other two come back to whoever filed the row, under a code
  # that names what they can correct.
  admitted <- identity_actionable(verdicts)
  stopped <- do.call(rbind, c(
    list(empty_outcomes),
    lapply(which(!admitted), function(i) {
      codes <- identity_stop_codes(verdicts[[i]], resolutions[[i]][["errors"]])
      if (length(codes) == 0L) {
        return(outcome_payload(record_ids[[i]], "pending", at = at))
      }
      outcome_payload(
        record_ids[[i]], round_outcome_kind(codes, dry_run),
        detail = paste(codes, collapse = ","), at = at
      )
    })
  ))

  # From here on the round works on the rows it may act on, carrying the UPN
  # this pass confirmed rather than the one somebody typed:
  # `register_to_desired()` builds a pair out of `username`, and the value it
  # must build it out of is the resolved one.
  resolved <- register
  resolved[["username"]] <- resolved_names
  resolved[["identity"]] <- verdicts
  resolved <- resolved[admitted, , drop = FALSE]

  # 4. the pure layer
  plan <- register_to_desired(resolved)
  asks <- scope_pairs(resolved)

  # A project_id the register accepted but that is not a number is a data
  # error, and it has to be named here. `validate_request()` catches the ones
  # that will not coerce; this catches the ones that coerce to something else,
  # while `scope_pairs()` admits the row on `requested_by` alone. Left to the
  # gate it would come back as a scope refusal: "you may not ask for that
  # project" instead of "that is not a project number", which sends the
  # referent to ask for a permission they already hold.
  trimmed_ids <- trimws(as.character(resolved[["project_id"]]))
  numbers <- suppressWarnings(as.integer(trimmed_ids))
  # `as.integer("9003.7")` is `9003L`, not `NA`: `is.na()` alone lets a
  # decimal id through as if it were the number it truncates to. The digit
  # check catches what the coercion silently rounds away.
  malformed <- scope_filled(resolved[["project_id"]]) &
    (is.na(numbers) | !grepl("^[0-9]+$", trimmed_ids))

  row_errors <- plan[["errors"]]
  for (id in as.character(resolved[["record_id"]])[malformed]) {
    if (is.null(row_errors[[id]])) {
      row_errors[[id]] <- "DATO_PROGETTO_INESISTENTE"
    }
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

  # 5. one instance at a time
  per_instance <- lapply(servers, function(server) {
    rows <- resolved[
      trimws(as.character(resolved[["server"]])) == server, ,
      drop = FALSE
    ]
    # A row already carrying a form error keeps that outcome: it is the earlier
    # and more specific verdict, and the register takes one outcome per record.
    ids <- setdiff(as.character(rows[["record_id"]]), names(row_errors))

    mine <- function(collection) {
      Filter(
        function(e) identical(as.character(e[["server"]]), server), collection
      )
    }
    wanted <- mine(plan[["desired"]])
    revoked <- mine(plan[["revoked"]])

    # The record ids of a row the round could actually have acted on. Not every
    # register row for this server: a row the identity gate stopped never
    # reached `resolved` at all, and one that did can still fail validation and
    # never enter `wanted` or `revoked`. Left as every row, an unreachable
    # instance would collect a transport error on a row the round never
    # touched, contradicting the early-feedback promise the scope-refusal path
    # below still keeps for exactly those rows.
    asked_for <- unique(c(
      vapply(
        wanted, function(e) as.character(e[["record_id"]]), character(1)
      ),
      vapply(
        revoked, function(e) as.character(e[["record_id"]]), character(1)
      )
    ))

    unreachable <- function(code) {
      list(
        stato = data.frame(
          server = server, raggiunta = FALSE, ambito_leggibile = NA,
          errori = paste(code, collapse = ","), stringsAsFactors = FALSE
        ),
        esiti = outcome_rows(
          intersect(ids, asked_for), "transport_error", detail = code
        )
      )
    }

    if (!server %in% names(hosts)) {
      return(unreachable("TRASPORTO_ISTANZA_SENZA_MODULO"))
    }
    if (!server %in% names(secrets) || is.na(secrets[[server]])) {
      return(unreachable("TRASPORTO_SEGRETO_NON_LEGGIBILE"))
    }

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

    # 6. the gate, asked only of an instance that answered this question
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

    # 7. the diff, against the real rows somebody asked about and no others
    diff <- provisioning_diff(wanted, round_actual(results, wanted))
    # A list, not a character vector: `[[` on an unmatched character subscript
    # raises "subscript out of bounds" on an atomic vector but returns NULL on
    # a list, and a miss here has to fall through, not abort the round.
    # Unreachable today -- provisioning_diff() emits a row per desired entry
    # -- but the same latent crash as by_pair below, on the same construct.
    action <- as.list(as.character(diff[["action"]]))
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
      function(e) isTRUE(acted(e) %in% c("creato", "aggiornato")), wanted
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

    # 8. one batch per project, never across two
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

        # 9. What `applied` has to mean. A dry run has nothing to read back —
        # the instance is unchanged — so it carries the intention the module
        # planned. A real write carries what the instance says afterwards, and
        # if that cannot be read the write is not called applied: the write
        # may well have landed, but `applied` is a claim about evidence, not
        # about the absence of an error.
        reread <- NULL
        if (!dry_run) {
          seen <- module_state(
            hosts[[server]], secrets[[server]],
            pairs = lapply(batch[["requests"]], function(r) {
              list(username = r[["username"]], project_id = r[["project_id"]])
            })
          )
          if (!isTRUE(seen[["ok"]])) {
            return(outcome_rows(
              batch[["record_ids"]], "transport_error",
              detail = "TRASPORTO_RILETTURA_FALLITA"
            ))
          }
          reread <- seen[["payload"]][["results"]] %||% list()
        }

        # A list, not a character vector: `[[` on an unmatched character
        # subscript raises "subscript out of bounds" on an atomic vector but
        # returns NULL on a list, and the `%||%` right below only ever gets
        # consulted on a list. The key is rebuilt from what the instance
        # echoes, with no normalization, so an entry the module returns with a
        # different case or padding -- or one entry more than it was sent --
        # is not exotic, and the guard against it has to actually run instead
        # of the round losing every outcome it computed to an uncaught error.
        by_pair <- as.list(batch[["record_ids"]])
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
            observed <- round_observed(reread, entry)
            # A write with no error code has said only that nothing went
            # wrong sending it -- the same thing the four spike cases said
            # while doing something else. Only the re-read settles it: an
            # apply not shown by the re-read, or a revoke still shown by it,
            # is not called applied, and the row returns to the queue instead
            # of closing on a claim nobody verified.
            kind <- round_outcome_kind(codes, dry_run)
            detail <- paste(codes, collapse = ",")
            if (identical(kind, "applied") &&
                  !round_write_confirmed(batch[["op"]], observed)) {
              kind <- "transport_error"
              detail <- "TRASPORTO_SCRITTURA_NON_CONFERMATA"
            }
            outcome_payload(
              id, kind,
              detail = detail, at = at,
              applied_as = round_applied_as(observed)
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
      esiti = do.call(rbind, c(
        list(empty_outcomes),
        # The gate refuses for more than one reason and they do not all belong
        # to the same person, so the outcome is read off the code's prefix
        # instead of being fixed here. Writing "data_error" once for every
        # refusal was the shorter line and the wrong one: it told a referent
        # whose rights row is unreadable that they are not authorized.
        lapply(names(refused), function(id) {
          code <- as.character(refused[[id]])
          outcome_payload(
            id, round_outcome_kind(code, dry_run), detail = code, at = at
          )
        }),
        list(settled, written)
      ))
    )
  })

  outcomes <- do.call(rbind, c(
    list(stopped, form_errors),
    lapply(per_instance, function(answer) answer[["esiti"]])
  ))
  # One outcome per record, and the first one wins: the identity verdict comes
  # first because a row the gate stopped never entered anything below it, and a
  # form error is the earlier and more specific verdict of the ones that
  # remain. Two rows with the same record_id in one import body is a write
  # whose result depends on the order REDCap applies them in.
  outcomes <- outcomes[!duplicated(outcomes[["record_id"]]), , drop = FALSE]

  # 10. only what changed, against the register as it was read and not as this
  # round has been rewriting it
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
    # Both writes report here. An identity body REDCap refused is not visible
    # in any outcome -- the round went on gating on what it computed, which is
    # right -- so without this the register would silently stop carrying the
    # verdicts while every row still reported its own fate correctly.
    errori = c(identity_written[["errors"]], import[["errors"]])
  )
}
