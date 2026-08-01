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


#' Run the conformance check against one instance
#'
#' The gate the ceiling policy rests on, and the only thing that earns a
#' conformance date. Seven steps, on a designated test project:
#'
#' 1. read the baseline;
#' 2. apply as a dry run, re-read, and require that nothing changed;
#' 3. apply for real, one case at a time;
#' 4. re-read and compare field by field against what was asserted;
#' 5. revoke, to restore;
#' 6. re-read and confirm the baseline is back;
#' 7. record the date, and only if every step was green.
#'
#' Step 2 is what measures the dry run guarantee instead of asserting it.
#'
#' Every write is a network call that can be refused, time out, or hit a
#' closed version gate. Its `ok` flag is captured and checked before the
#' re-read is trusted: a write that failed still leaves the instance
#' unchanged, and reading that back as "nothing differs" would blame
#' conformance for what is actually a transport failure. When a write
#' reports `ok = FALSE`, the corresponding step is failed immediately and the
#' reported errors are recorded in `differences` prefixed `TRASPORTO`,
#' instead of a list of fields — the same vocabulary `module_call()` already
#' uses for a failure that is not the instance's answer.
#'
#' If the instance itself does not answer — no payload, so no major — the
#' run stops after the baseline read: every later step compares against a
#' baseline and a major that were never established, so continuing would
#' measure nothing and could still send further requests to a server already
#' known to be unreachable.
#'
#' Run under `devtools::load_all()`, `registry_path`'s default resolves
#' inside the source tree, so a passing run is written where the next task's
#' `git add` can see it. Run against an installed copy of the package, the
#' same default resolves inside the installation library instead, and the
#' date never reaches the repository — no error, just nothing to commit.
#'
#' Server, secret, project and usernames come from the caller: this
#' repository is public and none of them may appear in it.
#'
#' @param server Hostname, optionally with the path REDCap is mounted under.
#' @param secret Shared secret.
#' @param project_id Test project; writes are refused outside the module's
#'   configured test projects.
#' @param username Test account to assert rights for.
#' @param registry_path CSV to record the outcome in. See the note above on
#'   `devtools::load_all()` versus an installed package.
#'
#' @return A list with `conforms`, `steps` and `differences`, invisibly.
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
    answer <- module_state(server, secret, pairs = pair)
    rows <- answer[["payload"]][["results"]]
    list(
      row = if (length(rows) == 0L) NULL else rows[[1]],
      # The major is taken from the instance, never assumed: recording a
      # run under the wrong major is how a conformance date would certify
      # something nobody tested.
      major = as.integer(answer[["payload"]][["redcap_major"]]),
      answer = answer
    )
  }

  baseline_state <- read_state()
  baseline <- baseline_state[["row"]]
  major <- baseline_state[["major"]]
  # length() first: as.integer(NULL) is integer(0), and is.na() on a
  # zero-length value returns logical(0), which makes && raise in R >= 4.3
  # instead of reporting the one condition this step exists to catch.
  steps[["instance_answered"]] <-
    length(major) == 1L && !is.na(major)

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
  dry_requests <- list(utils::modifyList(
    list(username = username, project_id = as.integer(project_id)),
    first_case[["assert"]]
  ))
  dry_response <- module_apply(server, secret, dry_requests, dry_run = TRUE)

  if (isTRUE(dry_response[["ok"]])) {
    dry_run_verdict <- compare_readback(baseline, read_state()[["row"]])
    steps[["dry_run_changed_nothing"]] <- dry_run_verdict[["conforms"]]
    if (!dry_run_verdict[["conforms"]]) {
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
    requests <- list(utils::modifyList(
      list(username = username, project_id = as.integer(project_id)),
      case[["assert"]]
    ))
    apply_response <- module_apply(server, secret, requests, dry_run = FALSE)

    if (!isTRUE(apply_response[["ok"]])) {
      steps[[case[["name"]]]] <- FALSE
      differences <- c(
        differences,
        note_transport(case[["name"]], apply_response)
      )
      next
    }

    verdict <- compare_readback(case[["assert"]], read_state()[["row"]])
    steps[[case[["name"]]]] <- verdict[["conforms"]]
    if (!verdict[["conforms"]]) {
      differences <- c(differences, note_diff(case[["name"]], verdict))
    }
  }

  # Attempted unconditionally: whatever the loop above did to the instance,
  # revoke is the only step that restores it, so a case failing above must
  # not skip the cleanup that follows it.
  revoke_response <- module_revoke(server, secret, pair, dry_run = FALSE)

  if (isTRUE(revoke_response[["ok"]])) {
    restored_verdict <- compare_readback(baseline, read_state()[["row"]])
    steps[["restored"]] <- restored_verdict[["conforms"]]
    if (!restored_verdict[["conforms"]]) {
      differences <- c(differences, note_diff("restored", restored_verdict))
    }
  } else {
    steps[["restored"]] <- FALSE
    differences <- c(differences, note_transport("restored", revoke_response))
  }

  conforms <- all(unlist(steps))
  if (conforms) {
    record_conformance(registry_path, major = major, on = Sys.Date())
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
#' @param path Registry CSV.
#' @param major REDCap major the run covered.
#' @param on Date of the run.
#'
#' @return The updated registry, invisibly.
#'
#' @keywords internal
record_conformance <- function(path, major, on) {
  registry <- readr::read_csv(path, show_col_types = FALSE)
  registry[["conformance_passed_on"]][
    registry[["redcap_major"]] == major
  ] <- as.character(on)
  readr::write_csv(registry, path)

  invisible(registry)
}
