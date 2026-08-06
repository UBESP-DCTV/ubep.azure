#' The assertions the conformance run applies
#'
#' Every field the contract can write is asserted, not a sample: a field the
#' cases do not assert is a field the gate is blind to. The combinations are
#' chosen on failures already observed rather than invented.
#'
#' Two cases clear a field instead of setting it: one clears the DAG, one
#' clears the expiration. The writer asserts an absent value as an empty
#' string, never by omitting it, and what the REDCap `date` column turns an
#' empty string into on write is a fact of the instance under test, not
#' something this code may assume — so clearing has to be exercised as
#' deliberately as setting.
#'
#' @return A list of cases, each with `name`, `assert` and `why`.
#'
#' @keywords internal
conformance_cases <- function() {
  list(
    list(
      name = "all three together",
      assert = list(
        role_name = "data entry", dag_name = "centro-01",
        expiration = "2027-01-01"
      ),
      why = "the ordinary path"
    ),
    list(
      name = "renewal only",
      assert = list(
        role_name = "data entry", dag_name = "centro-01",
        expiration = "2027-06-30"
      ),
      why = paste(
        "updatePrivileges clears the DAG when it is not passed, and reports",
        "success; asserting the full state is what prevents it"
      )
    ),
    list(
      name = "DAG deliberately cleared",
      assert = list(
        role_name = "data entry", dag_name = NULL,
        expiration = "2027-06-30"
      ),
      why = "asserting an absence has to work as well as asserting a value"
    ),
    list(
      name = "role change",
      assert = list(
        role_name = "read only", dag_name = NULL,
        expiration = "2027-06-30"
      ),
      why = "the role has to reach the right identifier"
    ),
    list(
      name = "expiration deliberately cleared",
      assert = list(
        role_name = "data entry", dag_name = "centro-01",
        expiration = NULL
      ),
      why = paste(
        "clearing an expiration has to work as well as setting one; what an",
        "empty string becomes in a date column is a fact only a run against",
        "the real instance measures, never a fact the code may assume"
      )
    )
  )
}


#' Compare what was read back against what was asserted
#'
#' The criterion is the re-read, never the return value: in the spike four
#' cases out of four reported success while three had done something else.
#' A missing row is the loudest failure and must not read as nothing to
#' compare.
#'
#' @param expected Named list of the asserted fields.
#' @param actual Named list read back, or `NULL` when no row came back.
#'
#' @return A list with `conforms` and `differences`.
#'
#' @keywords internal
compare_readback <- function(expected, actual) {
  fields <- c("role_name", "dag_name", "expiration")

  flat <- function(x, field) {
    value <- if (is.null(x)) NULL else x[[field]]
    if (is.null(value) || length(value) == 0L || is.na(value)) {
      NA_character_
    } else {
      as.character(value)
    }
  }

  differences <- Filter(
    function(field) !identical(flat(expected, field), flat(actual, field)),
    fields
  )
  differences <- as.character(unlist(differences))

  list(
    conforms = length(differences) == 0L,
    differences = differences
  )
}


#' Build one write request from a case's assertion
#'
#' `updatePrivileges` reads whatever keys are present and skips the rest, so
#' an absent key is different from an asserted absence. Every case in
#' `conformance_cases()` encodes "clear this field" as an R `NULL`, which is
#' correct on the expectation side that `compare_readback()` reads, but wrong
#' on the wire: `utils::modifyList()` drops a `NULL`-valued key instead of
#' setting it, and even a key that did survive with a `NULL` value would
#' serialize through `httr2::req_body_json(auto_unbox = TRUE)` as `null`, not
#' `""`. So this is the one place a `NULL` in `assert` becomes the explicit
#' empty string the channel elsewhere asserts an absence as.
#'
#' @param username Test account.
#' @param project_id Test project.
#' @param assert Named list of fields to assert, as in one case's `assert`.
#'
#' @return A named list, one element of the `requests` argument
#'   `module_apply()` expects.
#'
#' @keywords internal
request_for <- function(username, project_id, assert) {
  c(
    list(username = username, project_id = as.integer(project_id)),
    lapply(assert, function(value) if (is.null(value)) "" else value)
  )
}


#' Run the conformance check against one instance
#'
#' The gate the ceiling policy rests on, and the only thing that earns a
#' conformance date. Seven steps, on a designated test project:
#'
#' 1. read the baseline;
#' 2. apply as a dry run, re-read, and require that nothing changed;
#' 3. apply for real, one case at a time;
#' 4. re-read and compare field by field against what was asserted;
#' 5. revoke;
#' 6. re-read and compare against the baseline;
#' 7. record the date, and only if every step was green.
#'
#' Step 2 is what measures the dry run guarantee instead of asserting it.
#'
#' Step 5 does not restore anything: a revoke removes rights outright, and
#' that equals the baseline read in step 1 only when that baseline was
#' already empty. **The designated test account must hold no rights in the
#' test project before the run starts.** If it already does, the run
#' overwrites them through the five cases and then removes them entirely;
#' step 6 will correctly report a failed `restored` step, so nothing false
#' gets certified, but the account is left with fewer rights than it had —
#' that precondition is on the caller, not on this function.
#'
#' Every write is a network call that can be refused, time out, or hit a
#' closed version gate. Its `ok` flag is captured and checked before the
#' re-read that follows it is trusted, and the re-read itself gets the same
#' treatment: a call that failed to answer must not be read as "nothing
#' differs", or a transport failure would be filed as a conformance
#' failure — or worse, on the final re-read, as a restore nobody actually
#' observed. When either a write or the re-read after it reports `ok =
#' FALSE`, the corresponding step is failed immediately and the reported
#' errors are recorded in `differences` prefixed `TRASPORTO`, instead of a
#' list of fields — the same vocabulary `module_call()` already uses for a
#' failure that is not the instance's answer.
#'
#' If the instance itself does not answer the baseline read — no payload, so
#' no major and no fingerprint — the run stops right there: every later step
#' compares against a baseline and a pair that were never established, so
#' continuing would measure nothing and could still send further requests
#' to a server already known to be unreachable.
#'
#' The run declares the **measured** fingerprints, not the certified ones,
#' and must: the surface it is about to certify has no conformance date yet
#' by definition. Requiring one would recreate the ordering trap the ceiling
#' already has — the gate would force `dry_run`, the run could not write, and
#' the date could never be earned. The ordinary caller declares the certified
#' list instead, so that a row added after a bare `state` does not reopen
#' writes on a surface nobody ran this check against.
#'
#' Run under `devtools::load_all()`, `registry_path`'s default resolves
#' inside the source tree, so a passing run is written where the next task's
#' `git add` can see it. Run against an installed copy of the package, the
#' same default resolves inside the installation library instead, and the
#' date never reaches the repository — no error, just nothing to commit.
#'
#' The test project must already define every role and data access group
#' the cases name, because the channel asserts memberships and does not
#' create them: a role or a DAG that is not there is a data error the
#' instance returns, not something this run can provision on the way past.
#' Read `conformance_cases()` for the exact names, and check them against
#' the project before running — a missing role surfaces as a
#' `DATO_RUOLO_INESISTENTE` on one case, which reads like a conformance
#' failure and is not one.
#'
#' Server, secret, project and usernames come from the caller: this
#' repository is public and none of them may appear in it.
#'
#' @param server Hostname, optionally with the path REDCap is mounted under.
#' @param secret Shared secret.
#' @param project_id Test project; writes are refused outside the module's
#'   configured test projects. Must already define the roles and the data
#'   access group the cases name — see the note above.
#' @param username Test account to assert rights for. Must hold no rights
#'   in `project_id` before the run starts — see the note on step 5 above.
#' @param registry_path CSV to record the outcome in. See the note above on
#'   `devtools::load_all()` versus an installed package.
#'
#' @return A list with `conforms`, `steps` and `differences`, invisibly.
#'   `steps` gains a `recorded` entry once every other step is green: `TRUE`
#'   once `record_conformance()` succeeds, `FALSE` if it errors — a failure
#'   to write the registry must not discard the result of five real writes
#'   already performed against the instance.
#'
#' @keywords internal
run_conformance_check <- function(server,
                                  secret,
                                  project_id,
                                  username,
                                  registry_path = system.file(
                                    "extdata", "tested-fingerprints.csv",
                                    package = "ubep.azure"
                                  )) {
  stopifnot(
    is.character(username), length(username) == 1L,
    length(project_id) == 1L
  )

  pair <- list(list(username = username, project_id = as.integer(project_id)))
  steps <- list()
  differences <- character()

  # The measured list, not the certified one: the surface this run is about
  # to certify has no conformance date yet by definition, so declaring the
  # certified list here would recreate the ordering trap the ceiling already
  # has. See the roxygen above for the full reasoning.
  #
  # Read from the same registry this run will write to. With a custom
  # registry_path the shipped file is not the one that matters, and a run
  # that declared one registry's surfaces while stamping another's would be
  # certifying a pairing nobody measured.
  measured <- as.character(tested_fingerprints(registry_path)[["fingerprint"]])

  note_transport <- function(label, response) {
    paste0(
      label, ": TRASPORTO (",
      paste(response[["errors"]], collapse = ", "), ")"
    )
  }

  note_diff <- function(label, verdict) {
    paste0(label, ": ", paste(verdict[["differences"]], collapse = ", "))
  }

  # Returns the row, the major and the raw answer together rather than
  # stashing them in the enclosing scope: every call site that needs the
  # major or the raw errors reads it off this return value instead.
  read_state <- function() {
    # module_state() does not need the handshake -- reads aren't subject to
    # it -- but passing declare = measured costs nothing and keeps every
    # call in this function uniform, which is cheaper than explaining why
    # one call site is the exception.
    answer <- module_state(server, secret, pairs = pair, declare = measured)
    rows <- answer[["payload"]][["results"]]
    list(
      row = if (length(rows) == 0L) NULL else rows[[1]],
      # Major and fingerprint both come from the instance, never assumed:
      # recording a run under the wrong pair is how a conformance date would
      # certify something nobody tested.
      major = as.integer(answer[["payload"]][["redcap_major"]]),
      fingerprint = as.character(
        answer[["payload"]][["surface_fingerprint"]] %||% NA_character_
      ),
      answer = answer
    )
  }

  # A step's comparison depends on a re-read succeeding, not only on the
  # write before it: if the re-read itself failed to answer, the outcome is
  # a transport failure, and reading a NULL row as "matches a NULL baseline"
  # would let an unrelated timeout pass as a restore or as a clean dry run.
  # `transport` carries the raw failed answer when the re-read failed, NULL
  # otherwise, so the caller can tell the two causes of `conforms = FALSE`
  # apart without repeating the `ok` check at every site.
  reread_and_compare <- function(expected) {
    state <- read_state()
    if (!isTRUE(state[["answer"]][["ok"]])) {
      list(
        conforms = FALSE, differences = character(),
        transport = state[["answer"]]
      )
    } else {
      c(compare_readback(expected, state[["row"]]), list(transport = NULL))
    }
  }

  baseline_state <- read_state()
  baseline <- baseline_state[["row"]]
  major <- baseline_state[["major"]]
  fingerprint <- baseline_state[["fingerprint"]]
  # length() first: as.integer(NULL) is integer(0), and is.na() on a
  # zero-length value returns logical(0), which makes && raise in R >= 4.3
  # instead of reporting the one condition this step exists to catch.
  steps[["instance_answered"]] <-
    length(major) == 1L && !is.na(major) &&
    length(fingerprint) == 1L && !is.na(fingerprint)

  if (!isTRUE(steps[["instance_answered"]])) {
    return(invisible(list(
      conforms = FALSE,
      steps = steps,
      differences = note_transport(
        "instance_answered", baseline_state[["answer"]]
      )
    )))
  }

  first_case <- conformance_cases()[[1]]
  dry_requests <- list(
    request_for(username, project_id, first_case[["assert"]])
  )
  dry_response <- module_apply(
    server, secret, dry_requests, dry_run = TRUE, declare = measured
  )

  if (isTRUE(dry_response[["ok"]])) {
    dry_run_verdict <- reread_and_compare(baseline)
    steps[["dry_run_changed_nothing"]] <- dry_run_verdict[["conforms"]]
    if (!is.null(dry_run_verdict[["transport"]])) {
      differences <- c(
        differences,
        note_transport(
          "dry_run_changed_nothing", dry_run_verdict[["transport"]]
        )
      )
    } else if (!dry_run_verdict[["conforms"]]) {
      differences <- c(
        differences,
        note_diff("dry_run_changed_nothing", dry_run_verdict)
      )
    }
  } else {
    steps[["dry_run_changed_nothing"]] <- FALSE
    differences <- c(
      differences,
      note_transport("dry_run_changed_nothing", dry_response)
    )
  }

  for (case in conformance_cases()) {
    requests <- list(request_for(username, project_id, case[["assert"]]))
    apply_response <- module_apply(
      server, secret, requests, dry_run = FALSE, declare = measured
    )

    if (!isTRUE(apply_response[["ok"]])) {
      steps[[case[["name"]]]] <- FALSE
      differences <- c(
        differences,
        note_transport(case[["name"]], apply_response)
      )
      next
    }

    verdict <- reread_and_compare(case[["assert"]])
    steps[[case[["name"]]]] <- verdict[["conforms"]]
    if (!is.null(verdict[["transport"]])) {
      differences <- c(
        differences, note_transport(case[["name"]], verdict[["transport"]])
      )
    } else if (!verdict[["conforms"]]) {
      differences <- c(differences, note_diff(case[["name"]], verdict))
    }
  }

  # Attempted unconditionally: whatever the loop above did to the instance,
  # revoke is the only cleanup step, so a case failing above must not skip
  # it. It does not restore anything it did not find empty — see the
  # roxygen above.
  revoke_response <- module_revoke(
    server, secret, pair, dry_run = FALSE, declare = measured
  )

  if (isTRUE(revoke_response[["ok"]])) {
    restored_verdict <- reread_and_compare(baseline)
    steps[["restored"]] <- restored_verdict[["conforms"]]
    if (!is.null(restored_verdict[["transport"]])) {
      differences <- c(
        differences,
        note_transport("restored", restored_verdict[["transport"]])
      )
    } else if (!restored_verdict[["conforms"]]) {
      differences <- c(differences, note_diff("restored", restored_verdict))
    }
  } else {
    steps[["restored"]] <- FALSE
    differences <- c(differences, note_transport("restored", revoke_response))
  }

  conforms <- all(unlist(steps))
  if (conforms) {
    # A failure here (a missing registry row, an unreadable path) must not
    # discard the result of the five real writes already performed: it is
    # recorded as its own step instead of being allowed to propagate and
    # replace the whole return value with a stack trace.
    record_error <- tryCatch(
      {
        record_conformance(
          registry_path,
          major = major, fingerprint = fingerprint, on = Sys.Date()
        )
        NULL
      },
      error = function(e) conditionMessage(e)
    )
    steps[["recorded"]] <- is.null(record_error)
    if (!is.null(record_error)) {
      differences <- c(
        differences, paste0("recorded: TRASPORTO (", record_error, ")")
      )
    }
  }

  invisible(list(
    conforms = conforms, steps = steps, differences = differences
  ))
}


#' Record a passed conformance run in the registry
#'
#' Written by the run itself rather than by hand: a trigger that depends on
#' someone remembering to type a date is a reminder, which is the thing the
#' mechanism exists to replace.
#'
#' Called with `path` defaulted from `run_conformance_check()`, so the same
#' caveat applies here: under `devtools::load_all()` the default resolves
#' inside the source tree and the write lands where the next task's `git
#' add` can see it, while against an installed copy it lands in the
#' installation library instead and never reaches the repository.
#'
#' Raises when the pair matches no row: assigning into a `[` index that is
#' all `FALSE` is a silent no-op in R, and `write_csv()` would then rewrite
#' the file unchanged. A run against a pair the registry has never heard
#' of is precisely the case this mechanism exists for, and it must not be
#' indistinguishable from a run that actually recorded a date.
#'
#' @param path Registry CSV.
#' @param major REDCap major the run covered.
#' @param fingerprint Surface fingerprint the run covered, read from the
#'   instance's own answer. The key is the pair, not the major: a major can
#'   hold more than one surface — an upgrade inside it changes the fingerprint
#'   and leaves the major alone — and stamping every row of a major would
#'   certify a surface nobody tested.
#' @param on Date of the run.
#'
#' @return The updated registry, invisibly.
#'
#' @keywords internal
record_conformance <- function(path, major, fingerprint, on) {
  registry <- readr::read_csv(path, show_col_types = FALSE)

  # NA-safe on both columns: `NA == x` is NA, and `any()` over an NA would
  # make the guard below raise for the wrong reason.
  matched <- !is.na(registry[["redcap_major"]]) &
    registry[["redcap_major"]] == major &
    !is.na(registry[["fingerprint"]]) &
    registry[["fingerprint"]] == fingerprint

  if (!any(matched)) {
    stop(
      "record_conformance(): no row for redcap_major = ", major,
      " and fingerprint = ", fingerprint, " in ", path,
      call. = FALSE
    )
  }

  registry[["conformance_passed_on"]][matched] <- as.character(on)
  readr::write_csv(registry, path)

  invisible(registry)
}
