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
#' 10. **create the accounts the gate allowed and the tenant does not hold**;
#' 11. write back the outcome, and only what changed.
#'
#' **Step 3 is a step of this round and not a job of its own** — decision 2 of
#' the design — and the reason is latency: resolving and acting have the same
#' cadence and the second consumes the first, so a resolver on a timer of its
#' own would make every new row wait one more cycle to be looked at. It follows
#' that the gate has no window at all: it asks after the verdict it has just
#' computed, never after the one the register carries, and writing `identity`
#' back is the minutes of the verdict rather than the input to the next step.
#'
#' **Step 10 is last because it needs step 6's answer**, and that is the whole
#' shape of it. A row whose verdict is `absent` is not a pair — there is nobody
#' to grant a right to — so it never enters the desired state; but it does
#' travel as far as the scope question, because whoever could not have granted
#' that project by hand must not be able to make the person to grant it to
#' either. An instance that did not answer has neither allowed nor refused, and
#' the row waits.
#'
#' **The row it creates stays `absent` for this pass** and becomes `created` at
#' the next one, which is decision 4 working as written rather than a delay
#' being tolerated: `created` is the row whose previous verdict was `absent` and
#' that now matches, and that memory lives in the register. A round that wrote
#' `created` on the strength of having just made the account would be keeping a
#' second source of truth beside the sweep, which is the thing decision 4 of the
#' channel's design forbids.
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
#'   `credenziali`, `scritte` and `errori`. `scritte` counts the outcomes
#'   REDCap took and not the identities: they are two writes into two field
#'   families, and one counter for both would be a number nobody could read
#'   back into either. `credenziali` carries what the accounts created this
#'   round were born with, and it is the only road those take.
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
                                   mailer = NULL,
                                   redirect_to = NULL,
                                   copy_to = NULL,
                                   reply_to = NULL,
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

  # Send first, write after. A row whose message did not leave stays as the
  # register has it, so the next round finds it changed again and retries --
  # the queue is the register, and no second state exists to keep aligned. The
  # cost accepted in exchange is a duplicate, never a loss.
  #
  # With no mailer the round behaves exactly as it did before the mail existed:
  # everything changed is written, nothing is sent. That is the default on
  # purpose, because installing the package must not start a mail on the next
  # timer.
  #
  # It is a function and not two call sites because the round writes to the
  # register in two places -- here and on a failed sweep -- and a notification
  # that skipped one of them would be a `transport_error` nobody was told
  # about.
  # `identified` is empty by default because the branch above calls this before
  # the sweep has resolved anybody: a round that could not ask the tenant has
  # no identity to tell, and saying so is the honest message.
  posted <- function(changed, born = list(), identified = NULL) {
    if (is.null(mailer)) {
      return(list(
        recapitate = changed, errori = character(),
        contatori = list(
          posta_partite = 0L, posta_fallite = 0L,
          credenziali_recapitate = 0L, credenziali_perse = 0L,
          posta_dirottata = FALSE
        )
      ))
    }
    mail_round(
      changed, register, born, mailer, dry_run,
      redirect_to = redirect_to, copy_to = copy_to, reply_to = reply_to,
      identified = identified
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
    # This branch writes into the register too, so it goes through the same
    # door: a notification that skipped it would be a transport error the
    # referent was never told about.
    posta <- posted(round_changed(register, outcomes))
    import <- register_import(
      register_url, register_token, posta[["recapitate"]]
    )
    return(list(
      at = at, fermato = FALSE, schema = schema, istanze = empty_instances,
      esiti = outcomes, scritte = import[["scritte"]],
      posta = posta[["contatori"]],
      errori = c(import[["errors"]], posta[["errori"]])
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
  # desired state, not the scope question, not an instance. `ambiguous` and
  # `collision` come back to whoever filed the row, under a code that names
  # what they can correct.
  #
  # `absent` is neither of those and is the reason this is two tests and not
  # one. It is not actionable -- there is nobody to grant a right to -- but it
  # is the one verdict the round closes by itself, by creating. So it stays
  # standing: it goes on to the scope question, because whoever could not have
  # granted that project by hand must not be able to make the person to grant
  # it to either, and that question is answered by an instance.
  admitted <- identity_actionable(verdicts)
  absent <- !admitted & identity_normalize(verdicts) == "absent"

  # A request revoked before it was ever served. Until now `request_status`
  # reached only `register_to_desired()`, so the creation branch hung off the
  # verdict alone and a row somebody had revoked still made the person exist.
  # The two are not the same question -- a revocation speaks about the access
  # and the verdict about who somebody is -- but nobody who revokes an unserved
  # request expects an account to come of it. The only other answer available
  # was to tell people to delete the record instead, and that contradicts what
  # the form itself promises: absence is not a request.
  withdrawn <- absent &
    trimws(as.character(register[["request_status"]])) == "revoked"

  awaiting <- absent & !withdrawn
  standing <- admitted | awaiting

  stopped <- do.call(rbind, c(
    list(empty_outcomes),
    lapply(which(!standing), function(i) {
      # Nothing to take away and nobody to make: the state this row asks for is
      # the one the tenant is already in. Settled the way `already_gone` settles
      # a revocation of a right that is not there -- the same word and the same
      # read-back -- because `pending` on a row nobody will ever touch again is
      # a row left open for ever.
      if (withdrawn[[i]]) {
        return(outcome_payload(
          record_ids[[i]], round_outcome_kind(character(), dry_run),
          at = at, applied_as = round_applied_as(NULL)
        ))
      }

      codes <- identity_stop_codes(verdicts[[i]], resolutions[[i]][["errors"]])
      if (length(codes) == 0L) {
        # A verdict that is neither actionable nor `absent` and has nothing to
        # say about why is a word this function was never taught. `pending`
        # holds the row, where letting the empty code list reach
        # `round_outcome_kind()` would have it read as "nothing went wrong".
        return(outcome_payload(record_ids[[i]], "pending", at = at))
      }
      outcome_payload(
        record_ids[[i]], round_outcome_kind(codes, dry_run),
        detail = paste(codes, collapse = ","), at = at
      )
    })
  ))

  # From here on the round works on the rows it may still serve, carrying the
  # UPN this pass confirmed rather than the one somebody typed:
  # `register_to_desired()` builds a pair out of `username`, and the value it
  # must build it out of is the resolved one. An `absent` row travels with an
  # empty one, so it reaches the scope question without ever becoming a pair.
  resolved <- register
  resolved[["username"]] <- resolved_names
  resolved[["identity"]] <- verdicts
  resolved <- resolved[standing, , drop = FALSE]

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
      # The rows this instance was asked about and did not refuse. Only present
      # when the instance answered: the early returns above carry no such key,
      # and their silence is what keeps a creation from happening on a question
      # nobody got to ask.
      in_scope = setdiff(ids, names(refused)),
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

  # 10. make exist whoever the gate allowed and the tenant does not hold.
  # `User.Create` is the whole permission this runs under: it cannot modify an
  # account that already exists, reset a credential, disable or delete one. So
  # the worst a wrong creation can do is leave an account nobody has used, with
  # the request that caused it written in the register next to the name of
  # whoever filed it.
  #
  # A simulated round creates nobody. It is the same line the instance writes
  # are on, and the one place it could have been forgotten: a creation is not a
  # write on an instance, so nothing else in the round would have stopped it.
  in_scope <- unlist(lapply(per_instance, function(a) a[["in_scope"]]))
  creations <- if (dry_run) {
    list()
  } else {
    lapply(which(awaiting & record_ids %in% in_scope), function(i) {
      c(
        directory_create_user(
          graph_token, graph_url,
          as.list(register[i, , drop = FALSE]),
          # The name the resolution found free, carried out of the verdict
          # rather than composed a second time here. Two compositions would let
          # the round check that one name is free and create another.
          resolutions[[i]][["composed"]]
        ),
        list(record_id = record_ids[[i]])
      )
    })
  }

  # A creation that failed leaves the row exactly as it was -- there is still
  # nobody there, so the verdict is still `absent` -- and adds the reason, so
  # the next round retries. Idempotent by construction rather than by a check:
  # if the account did come into being despite the error, the next sweep finds
  # it by its surname and contact address and the row becomes `created` without
  # anything being created twice.
  refused_creations <- Filter(function(a) !isTRUE(a[["ok"]]), creations)
  born <- Filter(function(a) isTRUE(a[["ok"]]), creations)

  created_outcomes <- do.call(rbind, c(
    list(empty_outcomes),
    lapply(refused_creations, function(answer) {
      outcome_payload(
        answer[["record_id"]],
        round_outcome_kind(answer[["errors"]], dry_run),
        detail = paste(answer[["errors"]], collapse = ","), at = at
      )
    })
  ))

  # The default for a row that is waiting to be created and has nothing more
  # specific to say: refused on scope, or a creation that failed, both come
  # first in the merge below and win. It is last so that it can only ever fill
  # a silence.
  waiting <- outcome_rows(record_ids[awaiting], "pending")

  outcomes <- do.call(rbind, c(
    list(stopped, form_errors),
    lapply(per_instance, function(answer) answer[["esiti"]]),
    list(created_outcomes, waiting)
  ))
  # One outcome per record, and the first one wins: the identity verdict comes
  # first because a row the gate stopped never entered anything below it, and a
  # form error is the earlier and more specific verdict of the ones that
  # remain. Two rows with the same record_id in one import body is a write
  # whose result depends on the order REDCap applies them in.
  outcomes <- outcomes[!duplicated(outcomes[["record_id"]]), , drop = FALSE]

  # 11. only what changed, against the register as it was read and not as this
  # round has been rewriting it
  changed <- round_changed(register, outcomes)
  # The same minutes the identity door wrote, so the message names what the
  # round settled instead of what the referent left blank.
  posta <- posted(
    changed, born,
    identified = data.frame(
      record_id = as.character(record_ids),
      username = resolved_names,
      identity = verdicts,
      stringsAsFactors = FALSE
    )
  )
  import <- register_import(
    register_url, register_token, posta[["recapitate"]]
  )

  list(
    at = at,
    fermato = FALSE,
    schema = schema,
    istanze = do.call(
      rbind, lapply(per_instance, function(answer) answer[["stato"]])
    ) %||% empty_instances,
    esiti = outcomes,
    # The credentials the accounts were born with, and the only road they take.
    # Sub-project 5 will deliver them from here. Everywhere else is a place a
    # credential would outlive the act that made it: the register is read by
    # referents, the telemetry record is shipped to a workspace and kept, and
    # standard output is what the timer collects. `round_record()` builds from
    # named fields and this is not one of them, which is what keeps it out
    # rather than a promise that nobody will add it.
    credenziali = data.frame(
      record_id = vapply(born, function(a) a[["record_id"]], character(1)),
      username = vapply(born, function(a) a[["upn"]], character(1)),
      credential = vapply(born, function(a) a[["credential"]], character(1)),
      stringsAsFactors = FALSE
    ),
    scritte = import[["scritte"]],
    # What the post did this round. It travels beside `scritte` because the two
    # are now bound: a row is written only if its message left, so a reader who
    # saw one without the other could not tell a quiet night from a mute one.
    posta = posta[["contatori"]],
    # Every write reports here. An identity body REDCap refused is not visible
    # in any outcome -- the round went on gating on what it computed, which is
    # right -- so without this the register would silently stop carrying the
    # verdicts while every row still reported its own fate correctly. A message
    # that did not leave is here for the same reason: nothing else says it.
    errori = c(
      identity_written[["errors"]], import[["errors"]], posta[["errori"]]
    )
  )
}
