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
#' **The gate's subject is read from the log, not from the row.** `requested_by`
#' says who filed a request only because `@USERNAME` filled it in, and an
#' action tag governs the form REDCap draws rather than the layer that writes:
#' measured on 2026-09-02, an import writes that field verbatim, so anyone
#' holding the Data Import Tool could name a colleague who manages the project
#' and have the gate check that colleague's rights. So between step 3 and step
#' 4 the round asks REDCap who was authenticated when each row was created and
#' puts that name in the column the gate reads. One call, `logtype =
#' "record_add"` and no window: a record is created once, so the answer holds
#' one row per record that ever existed rather than one per event, and it is
#' asked only when a row is still standing to be judged or has changed since
#' it was applied.
#'
#' **A row somebody other than its creator changed waits for its creator**,
#' whether the round has applied it already or not yet. The same creator the
#' gate judges is the one person who can approve somebody else's change, so
#' whoever approves has already had their rights on the project checked, and
#' will again on every round. Who made the change is read from that row's own
#' log, whole, and without the round's own writes; the rule is
#' `change_needs_approval()`. The log is asked once per row that needs it: a
#' row whose seal moved, and a row not applied yet that the round could act
#' on. Two widenings, both decided on 2026-10-15. A revocation and nothing
#' else, made by somebody who manages the project, does not wait: it is
#' judged at the gate, step 6, because the rights come from the instance. And
#' the IT accounts in `approvers` approve as the creator does.
#'
#' A row the log cannot name is **held and not refused**, which is the same
#' distinction step 6 already makes between a permission that does not grant
#' and one that could not be read. "I could not establish who filed this" is
#' our failure and not the referent's, and the code that carries it is a
#' `TRASPORTO_` one so the row comes back next round and the mail comes to us.
#' The same holds for a changed row whose own log could not be read, or whose
#' creator the log does not name: it takes `TRASPORTO_AUTORE_NON_LEGGIBILE`
#' and not `held`, because a held message asks for an approval that nobody
#' could give, from a creator nobody could name.
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
#'   (`edc10`); only this map knows where they are, and it is also where the
#'   welcome message takes the address it gives a new account.
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
#' @param approvers The IT accounts whose approval of a change counts on any
#'   row, as REDCap usernames. Read by the runner from the machine and empty
#'   by default, so a runner that does not pass it leaves the creator as the
#'   only one who approves.
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
                                   approvers = character(),
                                   at = format(
                                     Sys.time(), "%Y-%m-%d %H:%M", tz = "UTC"
                                   )) {
  stopifnot(
    is.character(hosts), !is.null(names(hosts)),
    is.character(secrets), !is.null(names(secrets)),
    is.character(graph_token), length(graph_token) == 1L,
    is.character(graph_url), length(graph_url) == 1L,
    is.logical(dry_run), length(dry_run) == 1L, !is.na(dry_run),
    is.character(approvers),
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
          benvenuti_recapitati = 0L, benvenuti_persi = 0L,
          posta_dirottata = FALSE
        )
      ))
    }
    mail_round(
      changed, register, born, mailer, dry_run,
      redirect_to = redirect_to, copy_to = copy_to, reply_to = reply_to,
      identified = identified, hosts = hosts
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

  # A row somebody edited after the round applied it. REDCap has no per-row
  # ownership -- rights are per instrument, and the only thing that partitions
  # rows are data access groups, which this project does not have on purpose --
  # so any referent can edit any row, in good faith or by mistake. The seal is
  # what notices: it covers what was asked and not what happened, so it moves
  # only when somebody changed the request itself.
  sealed <- trimws(as.character(register[["applied_seal"]] %||% ""))
  sealed[is.na(sealed)] <- ""
  tampered <- nzchar(sealed) & sealed != request_seal(register)

  # Who was authenticated when each row was made. It is the name the gate has
  # to judge, and since 2026-10-14 it is also the one person a change to the
  # row by somebody else waits for, so it is read before the changed rows are
  # judged. `requested_by` cannot be it: `@USERNAME` is an action tag, it
  # governs the form REDCap draws, and an import draws none -- measured on
  # 2026-09-02, an import writes that field verbatim, so anyone with the Data
  # Import Tool could declare themselves somebody who manages the project and
  # have the gate check that somebody's rights.
  #
  # Asked with `logtype = "record_add"` and no window at all, and both halves
  # matter. The classification is REDCap's, so this package never reads the
  # prose of `action` -- one act reads `Create record 7` from the form and
  # `Create record (import) 20` from an import. And a record is created once,
  # so the answer holds one row per record that ever existed: it grows with
  # the register rather than with the traffic, where a window would lose the
  # creation of every row filed before yesterday.
  #
  # Still one call for the whole round, and still only when a row needs it.
  #
  # A log that could not be read holds the rows that needed it, and the rows
  # do not say why: a held row reads the same whether nobody approved it or
  # nobody could ask. So the register's answer goes into the round's own
  # errors, where it reaches whoever reads the record -- us, under the
  # `TRASPORTO_` code the register gave -- instead of being dropped here.
  log_errors <- character()
  creators <- rep("", nrow(register))
  if (any(admitted | awaiting | tampered)) {
    reading_creations <- register_log(
      register_url, register_token, logtype = "record_add"
    )
    if (isTRUE(reading_creations[["ok"]])) {
      creators <- log_creators(reading_creations[["log"]], record_ids)
    } else {
      log_errors <- c(log_errors, reading_creations[["errors"]])
    }
  }

  # A row the round has never applied carries no seal to compare, and is the
  # creator's all the same: changed by somebody else while it waits in the
  # queue, it would be carried out on the creator's authority -- the gate
  # checks the creator's rights -- with nobody asking the creator. So its log
  # is read too, whenever the round could act on it: the gate let it through
  # or it waits to be created, and its creator is known. A row whose creator
  # could not be read stops at the gate anyway, on a `TRASPORTO_` code.
  fresh <- !nzchar(sealed) & (admitted | awaiting) & nzchar(creators)
  checked <- tampered | fresh

  # The log is read only for a row that needs it, one call per row and with no
  # window: the question is who touched this row since the round last applied
  # it, or since it was filed, and that can be longer ago than any window. A
  # window of a day lost the edit and kept the approval that came after it, so
  # the change had no author and the approval passed for somebody else's. On
  # the ordinary night nothing is tampered with, every row has been applied,
  # and the register is never asked at all; a row waiting to be applied costs
  # one call for each round it waits.
  events <- log_frame(list())
  unread <- logical(length(record_ids))
  for (i in which(checked)) {
    reading_log <- register_log(
      register_url, register_token, record = record_ids[[i]]
    )
    # A log that could not be read leaves the row held. "I could not ask who
    # did this" is not "the creator did it", and between the two ways of being
    # wrong this is the one that does not grant. It has to be said, not left
    # to the empty log: on a row never applied an empty log reads as nobody
    # having changed it.
    if (isTRUE(reading_log[["ok"]])) {
      events <- rbind(events, reading_log[["log"]])
    } else {
      unread[[i]] <- TRUE
      log_errors <- c(log_errors, reading_log[["errors"]])
    }
  }

  # A change made by the creator alone is the creator's to make, and goes on
  # as any other row. Anybody else's hand in it and the row stops here, where
  # a withdrawn one stops, until the creator approves: applying it would grant
  # whatever the edit says on the authority of a round that ran before the
  # edit existed, and of a request somebody else filed. The rule is in
  # `change_needs_approval()` and nowhere else. An edit made while an earlier
  # round ran counts as well: it sits below that round's seal, which covers
  # only what the round had read, and `log_pending_authors()` finds it there.
  awaits <- checked
  awaits[checked] <- seal_needs_approval(
    register[checked, , drop = FALSE], events, creators[checked]
  )
  cleared <- awaits & seal_approved(register, events, creators, approvers)

  # A changed row whose log could not be read, or whose creator the log does
  # not name, is neither approved nor held: there is no change anybody could
  # approve, nor a creator to ask. It stops on the code the gate gives a row
  # with no author, so it comes back next round and the message says the
  # failure is ours, instead of asking the referent for a seal that approves
  # nothing.
  blind <- (checked & unread) | (tampered & !nzchar(creators))

  # A revocation and nothing else, by somebody other than the creator, is
  # free when they manage the project, and only the instance can say whether
  # they do. So it is not held here: it stands provisionally and the gate
  # decides, asking the rights of everybody with a hand in it.
  intent <- register_intent_fields()
  revoked_now <- trimws(as.character(register[["request_status"]])) %in%
    "revoked"
  withdrawal <- awaits & !cleared & !blind & revoked_now
  withdrawal[withdrawal] <- vapply(which(withdrawal), function(i) {
    log_revocation_only(events, record_ids[[i]], creators[[i]], intent)
  }, logical(1))
  withdrawal_authors <- lapply(seq_along(record_ids), function(i) {
    if (!withdrawal[[i]]) {
      return(character())
    }
    log_pending_authors(events, record_ids[[i]], creators[[i]], intent)
  })

  held <- awaits & !cleared & !blind & !withdrawal
  standing <- (admitted | awaiting) & !held & !blind

  # The register as this round will have left it, and not as it read it. The
  # round resolves `username` and writes it back in this same pass, so sealing
  # the row as read would seal a version the register is about to stop
  # holding: `username` is inside the seal -- it has to be, since changing it
  # changes who gets the access -- and the next round would find every applied
  # row modified, by the round's own hand. The mechanism would accuse itself
  # on the ordinary path, on every row, one pass after each apply.
  #
  # The seal a held row asks its creator to paste is computed on it for the
  # same reason: the creator reads the row after this round has written the
  # username, and a seal of the row as read would never match it.
  #
  # `resolved_names` is what the register ends up with either way: written when
  # it differs, already there when it does not.
  register_after <- register
  register_after[["username"]] <- resolved_names
  seal_after <- request_seal(register_after)

  held_outcome <- function(i) {
    outcome_payload(
      record_ids[[i]], "held",
      detail = paste0("SIGILLO_DIVERSO:", seal_after[[i]]),
      at = at
    )
  }

  stopped <- do.call(rbind, c(
    list(empty_outcomes),
    lapply(which(!standing), function(i) {
      # Before the identity verdict, and not after it. A row can be both held
      # and unservable -- change the username on an applied row and it is
      # `ambiguous` as well as edited -- and of the two, "somebody changed this
      # after it was applied" is the one that names what happened and who can
      # undo it. `ambiguous` would send the referent to fix a name nobody
      # complained about until the edit.
      #
      # The detail carries the seal the creator has to paste, and that is what
      # tells the creator about a second change: the seal moves with it, so
      # the outcome reads as changed and the message leaves again with the
      # new value, while the one the creator holds approves nothing any more.
      # It is also where a referent who lost the message finds it, on the row
      # itself.
      if (held[[i]]) {
        return(held_outcome(i))
      }
      if (blind[[i]]) {
        return(outcome_payload(
          record_ids[[i]],
          round_outcome_kind("TRASPORTO_AUTORE_NON_LEGGIBILE", dry_run),
          detail = "TRASPORTO_AUTORE_NON_LEGGIBILE", at = at
        ))
      }

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
  # `requested_by` carries the creator the log named, for the gate.
  resolved <- register
  resolved[["username"]] <- resolved_names
  resolved[["identity"]] <- verdicts
  resolved[["requested_by"]] <- creators
  resolved <- resolved[standing, , drop = FALSE]

  # 4. the pure layer
  plan <- register_to_desired(resolved)
  asks <- scope_pairs(resolved)

  # The rights a provisional withdrawal is judged on are those of whoever had a
  # hand in it, and the instance answers only for the pairs it is asked about.
  extra <- lapply(which(withdrawal & standing), function(i) {
    who <- withdrawal_authors[[i]]
    who <- who[!is.na(who) & nzchar(who)]
    server <- trimws(as.character(register[["server"]][[i]]))
    project <- trimws(as.character(register[["project_id"]][[i]]))
    data.frame(
      server = rep(server, length(who)),
      project_id = rep(project, length(who)),
      username = who,
      stringsAsFactors = FALSE
    )
  })
  asks <- do.call(rbind, c(list(asks), extra))
  asks <- asks[
    !duplicated(scope_key(asks$server, asks$project_id, asks$username)), ,
    drop = FALSE
  ]

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

  # A row the log could not name is not a row nobody filed, and the difference
  # decides who gets told. Left to the gate it would come back as "you are not
  # authorized to ask for that project" -- a verdict about the referent, sent
  # to the one person who cannot act on it, when what actually failed is our
  # own reading of the register's log. So it takes a `TRASPORTO_` code: the
  # row stays queued and comes back next round, and the mail comes to us.
  # Same shape and same reason as `TRASPORTO_PERMESSO_NON_LEGGIBILE`.
  unnamed <- !scope_filled(resolved[["requested_by"]])
  for (id in as.character(resolved[["record_id"]])[unnamed]) {
    if (is.null(row_errors[[id]])) {
      row_errors[[id]] <- "TRASPORTO_AUTORE_NON_LEGGIBILE"
    }
  }

  form_errors <- outcome_rows(character(), "pending")
  if (length(row_errors) > 0L) {
    form_errors <- do.call(rbind, lapply(
      names(row_errors),
      function(id) {
        # The kind is read off the codes rather than fixed, because this list
        # is no longer all `DATO_`: a row held for a log nobody could read has
        # to come back next round, and only `transport_error` does that.
        outcome_payload(
          id, round_outcome_kind(row_errors[[id]], dry_run),
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

    # A row already carrying an error must not travel into the plan. Until now
    # this held without being written: every such row had failed validation,
    # and a row that fails validation never becomes a desired entry. A row
    # held because the log could not name who filed it is well formed in every
    # other way, so it does enter -- and the exclusion that was a consequence
    # has to become a statement.
    served <- function(e) {
      !as.character(e[["record_id"]]) %in% names(row_errors)
    }
    wanted <- Filter(served, wanted)
    revoked <- Filter(served, revoked)

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

    rights <- round_rights(server, state)
    provisional <- as.character(rows[["record_id"]]) %in%
      record_ids[withdrawal]
    refused <- scope_errors(rows[!provisional, , drop = FALSE], rights)
    refused <- refused[names(refused) %in% ids]

    # A provisional withdrawal is judged on the rights of whoever had a hand
    # in it, and not on the creator's alone: one that stands goes on as any
    # other row, one that does not stand waits for the creator after all.
    waits <- character()
    for (id in intersect(ids, record_ids[withdrawal])) {
      i <- match(id, record_ids)
      verdict <- scope_withdrawal(
        rows[as.character(rows[["record_id"]]) == id, , drop = FALSE],
        withdrawal_authors[[i]], creators[[i]], nzchar(sealed[[i]]), rights
      )
      if (identical(verdict, "held")) {
        waits <- c(waits, id)
      } else if (nzchar(verdict)) {
        refused[[id]] <- verdict
      }
    }

    in_scope <- function(e) {
      !as.character(e[["record_id"]]) %in% c(names(refused), waits)
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
      in_scope = setdiff(ids, c(names(refused), waits)),
      # The withdrawals the gate sent back to wait for their creator.
      trattenute = waits,
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

  # The withdrawals the gate did not free are held as if they had been held
  # before the instance was asked: same outcome, same seal state, same message.
  sent_back <- unlist(lapply(per_instance, function(a) a[["trattenute"]]))
  late <- record_ids %in% sent_back
  held <- held | late
  late_held <- do.call(
    rbind, c(list(empty_outcomes), lapply(which(late), held_outcome))
  )

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
    list(stopped, late_held, form_errors),
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
  # round settled instead of what the referent left blank. And the creator the
  # log named, which is where a held row's message goes: it asks its reader
  # to approve, and the creator is the only one whose approval counts. With
  # it, who changed the row, which is what the creator has to judge.
  edited_by <- vapply(seq_along(record_ids), function(i) {
    if (!checked[[i]]) {
      return("")
    }
    authors <- log_pending_authors(
      events, record_ids[[i]], creators[[i]], intent
    )
    if (anyNA(authors)) "" else paste(authors, collapse = ", ")
  }, character(1))
  posta <- posted(
    changed, born,
    identified = data.frame(
      record_id = as.character(record_ids),
      username = resolved_names,
      identity = verdicts,
      creator = creators,
      edited_by = edited_by,
      stringsAsFactors = FALSE
    )
  )
  import <- register_import(
    register_url, register_token, posta[["recapitate"]]
  )

  # The seals, written last and through a door that takes nothing else.
  #
  # Only a row whose outcome is `applied` gets a fresh seal. A simulated round
  # applied nothing, so sealing it would state that a change had been carried
  # out and would leave the next real round believing it had already happened.
  #
  # A held row keeps the seal it already carries and only its state moves: the
  # seal is the record of what was applied, and the round has just refused to
  # apply anything. Rewriting it would adopt the very edit the round declined,
  # and the next pass would find the row conforming -- the protection would
  # erase its own evidence one round after firing.
  #
  # The seal of an applied row is computed on `register_after`, the register
  # as this round will have left it, for the reason given where it is built.

  # `approved` is sticky, and it has to be to mean anything. Recomputed as
  # `intact` on every ordinary round it would name a state that lasts one
  # pass: four hours after an approval the register would again be unable to
  # say whether a row had ever been contested, and the event log would be the
  # only witness left. Carried forward, the value answers the question the
  # register is asked -- how did the version now in force get here.
  state_before <- trimws(as.character(register[["seal_state"]] %||% ""))
  state_before[is.na(state_before)] <- ""

  sealing <- do.call(rbind, c(
    list(seal_payload("", "", "intact")[0, , drop = FALSE]),
    lapply(
      as.character(outcomes[["record_id"]])[
        as.character(outcomes[["outcome"]]) == "applied"
      ],
      function(id) {
        i <- match(id, record_ids)
        seal_payload(
          id,
          seal_after[[i]],
          # Applied while waiting for an approval says an approval carried
          # this row here. A change the creator made alone was nobody's to
          # contest, and leaves the row as it was. Otherwise the row keeps
          # what it had: a change approved once stays approved until somebody
          # edits the row again, which is when `modified` takes over below.
          if (cleared[[i]] || identical(state_before[[i]], "approved")) {
            "approved"
          } else {
            "intact"
          }
        )
      }
    ),
    lapply(which(held), function(i) {
      seal_payload(record_ids[[i]], sealed[[i]], "modified")
    })
  ))
  seal_written <- register_seal_import(
    register_url, register_token,
    round_changed(
      register, sealing, fields = c("applied_seal", "seal_state")
    )
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
      identity_written[["errors"]], unique(log_errors), import[["errors"]],
      posta[["errori"]], seal_written[["errors"]]
    )
  )
}
