#' Read the request register's data dictionary
#'
#' The dictionary is the schema, and it lives as a file rather than as R code
#' because REDCap imports it as it is: one artifact, two consumers.
#'
#' @return A data frame with the eighteen columns of a REDCap data dictionary.
#'
#' @keywords internal
register_dictionary <- function() {
  path <- system.file(
    "extdata", "request-register-dictionary.csv",
    package = "ubep.azure"
  )
  readr::read_csv(path, show_col_types = FALSE)
}


#' Split a REDCap choice string into codes and labels
#'
#' Choices travel as `"code, label | code, label"`, and only the **first** comma
#' separates the two: a label may carry commas of its own.
#'
#' @param text One cell of the dictionary's choices column.
#'
#' @return A data frame with `code` and `label`.
#'
#' @keywords internal
dictionary_choices <- function(text) {
  items <- trimws(strsplit(as.character(text), "|", fixed = TRUE)[[1]])
  items <- items[nzchar(items)]

  data.frame(
    code = trimws(sub("^([^,]*),.*$", "\\1", items)),
    label = trimws(sub("^[^,]*,\\s*", "", items)),
    stringsAsFactors = FALSE
  )
}


#' The register fields only the job writes
#'
#' Marked `@READONLY` in the dictionary, which governs the form and not the
#' API: the job keeps writing them while a requester cannot. Without the tag a
#' requester could type `applied` into the outcome, and the register would carry
#' a success nobody produced.
#'
#' @return A character vector of field names.
#'
#' @keywords internal
register_readonly_fields <- function() {
  c(
    "identity", "requested_by", "outcome", "outcome_detail",
    "outcome_at", "applied_as"
  )
}


#' Turn one register row into a request
#'
#' The register's field names are the request's field names, so there is no map
#' between the two and no key can fall into a default without raising. That is
#' the whole reason the names were chosen.
#'
#' A blank cell is dropped rather than carried as `""`. The difference matters
#' downstream: `provisioning_diff()` reads an absent field as "not set", while
#' an empty string would be a value nobody asked for — and a DAG nobody asked
#' for is an update, never a `noop`.
#'
#' @param row A one-row data frame from the register.
#'
#' @return A named list holding only the fields that carry a value.
#'
#' @keywords internal
request_from_row <- function(row) {
  stopifnot(is.data.frame(row), nrow(row) == 1L)

  fields <- c(
    "server", "username", "project_id", "role_name", "dag_name",
    "expiration", "contact_email"
  )

  value_of <- function(field) {
    if (!field %in% names(row)) {
      return(NULL)
    }
    raw <- row[[field]]
    if (length(raw) != 1L || is.na(raw)) {
      return(NULL)
    }
    text <- trimws(as.character(raw))
    if (nzchar(text)) text else NULL
  }

  request <- lapply(fields, value_of)
  names(request) <- fields
  request[!vapply(request, is.null, logical(1))]
}


#' Turn the register into the desired state
#'
#' The register declares requests; it does not describe reality. A pair that
#' exists in REDCap and appears nowhere here means nothing, so this function
#' never produces a revocation that a person did not ask for: only
#' `request_status = "revoked"` does that.
#'
#' Three things keep a row out of the desired state, and they are not the same
#' thing. A row with no resolved username is not a pair yet and is not an
#' error. A pair that appears twice is an error on **both** rows, because
#' either one of them is the mistake and there is no way to tell which —
#' guessing which one wins is what a ledger does, and a register refuses. A row
#' that fails validation carries the data-error codes back to whoever wrote it.
#'
#' @param register The register as a data frame, one row per pair, carrying at
#'   least `record_id` and `request_status`.
#'
#' @return A list with `desired`, `revoked` and `errors`. The first two hold
#'   requests that already went through `intake_request()`, each carrying its
#'   `record_id` so the outcome knows where to go back. `errors` is named by
#'   `record_id`.
#'
#' @keywords internal
register_to_desired <- function(register) {
  stopifnot(
    is.data.frame(register),
    all(c("record_id", "request_status") %in% names(register))
  )

  ids <- as.character(register[["record_id"]])
  statuses <- as.character(register[["request_status"]])
  requests <- lapply(
    seq_len(nrow(register)),
    function(i) request_from_row(register[i, , drop = FALSE])
  )

  is_pair <- vapply(
    requests,
    function(request) {
      all(
        vapply(
          c("server", "project_id", "username"),
          function(field) !is.null(request[[field]]),
          logical(1)
        )
      )
    },
    logical(1)
  )

  keys <- vapply(seq_along(requests), function(i) {
    if (!is_pair[[i]]) {
      return(NA_character_)
    }
    paste(
      requests[[i]][["server"]],
      requests[[i]][["project_id"]],
      requests[[i]][["username"]],
      sep = "\r"
    )
  }, character(1))

  # The NA guard is not decoration: `NA %in% NA` is TRUE, so without it every
  # row still waiting for an identity would report itself as a duplicate.
  repeated <- !is.na(keys) & keys %in% keys[duplicated(keys)]

  desired <- list()
  revoked <- list()
  errors <- list()

  for (i in seq_along(requests)) {
    if (!is_pair[[i]]) {
      next
    }

    if (repeated[[i]]) {
      errors[[ids[[i]]]] <- "DATO_COPPIA_DUPLICATA"
      next
    }

    taken <- intake_request(requests[[i]])
    if (length(taken[["errors"]]) > 0L) {
      errors[[ids[[i]]]] <- taken[["errors"]]
      next
    }

    entry <- taken[["request"]]
    entry[["record_id"]] <- ids[[i]]
    if (identical(statuses[[i]], "revoked")) {
      revoked[[length(revoked) + 1L]] <- entry
    } else {
      desired[[length(desired) + 1L]] <- entry
    }
  }

  list(desired = desired, revoked = revoked, errors = errors)
}


#' Build the body that writes an outcome back into the register
#'
#' The register holds two kinds of field and they must never mix. What a person
#' asked for is intent; what happened is observation. This body carries only the
#' second, and the columns are fixed here rather than assembled from the caller
#' so that a bug cannot rewrite intent: without that separation a repeated
#' transport error could switch off legitimate requests, and nobody could tell
#' "a person removed it" from "a bug removed it".
#'
#' `applied_as` is meant to carry what the channel **read back** after writing,
#' not the return code. An outcome that only said "no error" would be the same
#' thing as the four spike cases that reported `true` while doing something
#' else.
#'
#' @param record_id The register record to write to.
#' @param outcome One of `"pending"`, `"applied"`, `"data_error"`,
#'   `"transport_error"`, `"simulated"`.
#' @param detail Error codes or a human-readable note.
#' @param at When the outcome was recorded, as `YYYY-MM-DD HH:MM`.
#' @param applied_as What the re-read found.
#'
#' @return A one-row data frame with exactly the outcome columns.
#'
#' @keywords internal
outcome_payload <- function(record_id,
                            outcome,
                            detail = "",
                            at = "",
                            applied_as = "") {
  vocabulary <- c(
    "pending", "applied", "data_error", "transport_error", "simulated"
  )
  stopifnot(
    is.character(record_id), length(record_id) == 1L,
    is.character(outcome), length(outcome) == 1L, outcome %in% vocabulary
  )

  data.frame(
    record_id = record_id,
    outcome = outcome,
    outcome_detail = as.character(detail),
    outcome_at = as.character(at),
    applied_as = as.character(applied_as),
    stringsAsFactors = FALSE
  )
}
