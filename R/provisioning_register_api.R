#' Call the register's REDCap API once
#'
#' The only function in the package that speaks to the request register, and
#' the only one that builds its URL. The register is read and written with a
#' token rather than with the module, which is the mechanism the channel's
#' first design set aside: the argument against it was that the friction grows
#' with the number of projects, and here the project is one, and one forever.
#'
#' The answer is recognized by its shape and never by its status code. An
#' instance whose API is switched off answers 200 with an HTML page, exactly as
#' a disabled module answers 200 with a sentence, and a client that inferred
#' success from the status would fail inside the JSON parser reporting an error
#' that does not name the cause.
#'
#' @param url Hostname of the instance hosting the register, optionally
#'   followed by the path REDCap is mounted under. A scheme is dropped rather
#'   than honored, so a base handed over as http is corrected instead of
#'   silently downgrading the channel.
#' @param token The API token of the service account, sent in the body.
#' @param params Named list of REDCap API parameters, without `token`,
#'   `format` and `returnFormat`, which are set here.
#'
#' @return A list with `ok`, `errors` and `payload`, shaped like the module
#'   client's answer because it answers the same kind of question.
#'
#' @keywords internal
register_call <- function(url, token, params) {
  stopifnot(
    is.character(url), length(url) == 1L,
    is.character(token), length(token) == 1L, nzchar(token),
    is.list(params), length(params) > 0L, !is.null(names(params))
  )

  base <- sub("^[A-Za-z][A-Za-z0-9+.-]*://", "", url)
  base <- sub("/+$", "", base)

  request <- httr2::request(paste0("https://", base, "/api/")) |>
    httr2::req_method("POST") |>
    httr2::req_body_form(
      token = token, format = "json", returnFormat = "json",
      !!!params
    )

  response <- tryCatch(
    request |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform(),
    error = function(e) NULL
  )

  if (is.null(response)) {
    return(list(
      ok = FALSE,
      errors = "TRASPORTO_REGISTRO_NON_RAGGIUNGIBILE",
      payload = NULL
    ))
  }

  payload <- tryCatch(
    jsonlite::fromJSON(
      httr2::resp_body_string(response),
      simplifyVector = FALSE
    ),
    error = function(e) NULL,
    warning = function(w) NULL
  )

  if (is.null(payload) || !is.list(payload)) {
    return(list(
      ok = FALSE,
      errors = "TRASPORTO_REGISTRO_RISPOSTA_INATTESA",
      payload = NULL
    ))
  }

  refused <- !is.null(payload[["error"]]) ||
    !identical(as.integer(httr2::resp_status(response)), 200L)

  if (refused) {
    # The message is the server's prose and is worth keeping for diagnosis.
    # The token is scrubbed out of it first: REDCap does not echo it today, and
    # relying on that would be trusting the other end to keep our secret.
    message <- as.character(payload[["error"]] %||% "")
    return(list(
      ok = FALSE,
      errors = "TRASPORTO_REGISTRO_RIFIUTATO",
      payload = list(message = gsub(token, "", message, fixed = TRUE))
    ))
  }

  list(ok = TRUE, errors = character(), payload = payload)
}


#' Read one list element as a length-one character, or as an empty string
#'
#' Both frame builders below walk a REDCap list-of-lists field by field, and
#' both meet the same two edges there: a field a given record does not carry,
#' and a value REDCap hands back longer than one (a checkbox field, most
#' often). Neither is an error at this layer — it becomes `""`, so a shape
#' this reader is not the one meant to judge cannot raise before the caller's
#' own shape check gets to see it.
#'
#' @param value One raw list element: `NULL`, length one, or longer.
#'
#' @return A length-one character vector.
#'
#' @keywords internal
scalar_as_character <- function(value) {
  if (is.null(value) || length(value) != 1L) "" else as.character(value)
}


#' Assemble named character columns into a data frame, untouched by either
#'
#' `check.names = FALSE` is what keeps a name like `Variable / Field Name`
#' from being mangled into a syntactic one, and `stringsAsFactors = FALSE` is
#' what keeps a character column character instead of becoming a factor.
#'
#' @param columns A named list of equal-length character vectors, one per
#'   column, in the order they should appear.
#'
#' @return A data frame built from `columns`, names and types as given.
#'
#' @keywords internal
columns_frame <- function(columns) {
  do.call(
    data.frame,
    c(columns, list(stringsAsFactors = FALSE, check.names = FALSE))
  )
}


#' Turn a REDCap record export into a frame of character columns
#'
#' Every column stays character, `project_id` included. The pure layer already
#' reads it as text and compares it as text, and a type guessed here would be
#' a second opinion about the same value — which is the shape of bug this
#' package keeps finding: two paths to one answer that disagree in silence.
#'
#' @param records The parsed export, a list of one list per record.
#'
#' @return A data frame with one row per record.
#'
#' @keywords internal
records_frame <- function(records) {
  if (length(records) == 0L) {
    return(data.frame(record_id = character(), stringsAsFactors = FALSE))
  }

  fields <- unique(unlist(lapply(records, names)))
  columns <- lapply(fields, function(field) {
    vapply(
      records,
      function(record) scalar_as_character(record[[field]]),
      character(1)
    )
  })
  names(columns) <- fields

  columns_frame(columns)
}


#' Read every record of the register
#'
#' Asks for the raw codes rather than the labels. Measured on 2026-08-14 the
#' two coincide on all four coded fields, 24 choices out of 24, so the choice
#' is indifferent — and it is asked for anyway, because a convention that holds
#' today is not a convention the caller should depend on silently.
#'
#' @inheritParams register_call
#'
#' @return The `register_call()` list plus `records`, a data frame.
#'
#' @keywords internal
register_records <- function(url, token) {
  answer <- register_call(url, token, list(
    content = "record",
    action = "export",
    type = "flat",
    rawOrLabel = "raw",
    exportCheckboxLabel = "false"
  ))

  if (!isTRUE(answer[["ok"]])) {
    return(c(answer, list(records = NULL)))
  }

  # An export is a JSON array, which parses to a list with no names. An object
  # arrives named, and it is not a record set: read as one it would produce a
  # one-row register made out of a message.
  if (!is.null(names(answer[["payload"]]))) {
    return(list(
      ok = FALSE,
      errors = "TRASPORTO_REGISTRO_RISPOSTA_INATTESA",
      payload = NULL,
      records = NULL
    ))
  }

  c(answer, list(records = records_frame(answer[["payload"]])))
}


#' The five columns REDCap's event log answers with
#'
#' Fixed here rather than derived from the answer, unlike `records_frame()`,
#' and the difference is what the two are for: a register record set is
#' whatever the project's dictionary holds today, while the log's shape belongs
#' to REDCap and does not move with the project. Deriving it would make an
#' empty window — the common case on a quiet night — come back with no
#' columns at all, and every reader would then have to guard against a frame
#' that has no `username`.
#'
#' @return A character vector of column names.
#'
#' @keywords internal
log_fields <- function() {
  c("timestamp", "username", "action", "details", "record")
}


#' Turn REDCap's event log export into a frame of character columns
#'
#' @param entries The parsed export, a list of one list per event.
#'
#' @return A data frame with one row per event and always `log_fields()` as
#'   columns, empty of rows when nothing happened in the window.
#'
#' @keywords internal
log_frame <- function(entries) {
  columns <- lapply(log_fields(), function(field) {
    if (length(entries) == 0L) {
      return(character())
    }
    vapply(
      entries, function(entry) scalar_as_character(entry[[field]]),
      character(1)
    )
  })
  names(columns) <- log_fields()

  columns_frame(columns)
}


#' Read who touched the register, and when
#'
#' The one question the register's own fields cannot answer. `requested_by`
#' says who filed a row only because `@USERNAME` filled it in on the form, and
#' an action tag governs the form and not the API: measured on 2026-09-01, an
#' import writes into that field whatever it is handed. The log says who was
#' **authenticated**, which is not a value anybody can type.
#'
#' `since` is in the **instance's** civil time and not in UTC, which is the
#' one thing about this call that is easy to get wrong. REDCap stamps its log
#' with the server clock: measured on 2026-09-01, a round that ran at 21:03
#' UTC appears in the log at 23:03. The channel keeps UTC everywhere else, so
#' a caller that handed its own stamp straight through would ask for a window
#' shifted by two hours in summer and **one in winter** — a discrepancy that
#' is not a constant and that would come and go with the change of hour.
#'
#' Callers therefore convert, and they are expected to convert generously: the
#' window is cheap to widen and the filtering that matters is done on the rows,
#' not on the boundary.
#'
#' @inheritParams register_call
#' @param since Beginning of the window, `"%Y-%m-%d %H:%M"`, in the
#'   instance's civil time.
#'
#' @return The `register_call()` list plus `log`, a data frame.
#'
#' @keywords internal
register_log <- function(url, token, since) {
  stopifnot(
    is.character(since), length(since) == 1L, !is.na(since), nzchar(since)
  )

  answer <- register_call(url, token, list(
    content = "log", beginTime = since
  ))

  if (!isTRUE(answer[["ok"]])) {
    return(c(answer, list(log = NULL)))
  }

  # Same guard as the record export, and needed for the same reason: an array
  # parses to an unnamed list, an object arrives named and is a message rather
  # than a log. Read as a log it would become one event nobody produced -- and
  # here that matters more than in the export, because an invented event is an
  # invented author, and the author is what decides whether a change applies.
  if (!is.null(names(answer[["payload"]]))) {
    return(list(
      ok = FALSE,
      errors = "TRASPORTO_REGISTRO_LOG_INATTESO",
      payload = NULL,
      log = NULL
    ))
  }

  c(answer, list(log = log_frame(answer[["payload"]])))
}


#' The four dictionary columns the comparison reads, in the API's vocabulary
#'
#' REDCap holds one schema under two sets of names: the CSV a project imports
#' says `Variable / Field Name`, the API's metadata says `field_name`. A map
#' between two sets of names is exactly where this project's worst class of bug
#' lives, so the map is small, explicit, and covered by a test that sends the
#' packaged dictionary back through it and requires the comparison to conform.
#'
#' @param fields The parsed metadata, a list of one list per field.
#'
#' @return A data frame with the four columns `compare_dictionary()` reads.
#'
#' @keywords internal
metadata_frame <- function(fields) {
  map <- c(
    "Variable / Field Name" = "field_name",
    "Field Type" = "field_type",
    "Choices, Calculations, OR Slider Labels" =
      "select_choices_or_calculations",
    "Field Annotation" = "field_annotation"
  )

  columns <- lapply(map, function(key) {
    vapply(
      fields,
      function(field) scalar_as_character(field[[key]]),
      character(1)
    )
  })
  names(columns) <- names(map)

  columns_frame(columns)
}


#' Read the register's data dictionary as the live project holds it
#'
#' This is the caller `compare_dictionary()` has been waiting for: until now
#' the comparison existed and nothing ever handed it a live dictionary, so a
#' drift on the form — a field dropped, a type loosened, a `@READONLY`
#' annotation removed — could not be seen by anything.
#'
#' @inheritParams register_call
#'
#' @return The `register_call()` list plus `dictionary`, a data frame.
#'
#' @keywords internal
register_metadata <- function(url, token) {
  answer <- register_call(url, token, list(content = "metadata"))

  if (!isTRUE(answer[["ok"]])) {
    return(c(answer, list(dictionary = NULL)))
  }

  if (!is.null(names(answer[["payload"]]))) {
    return(list(
      ok = FALSE,
      errors = "TRASPORTO_REGISTRO_RISPOSTA_INATTESA",
      payload = NULL,
      dictionary = NULL
    ))
  }

  c(answer, list(dictionary = metadata_frame(answer[["payload"]])))
}


#' Write outcomes back into the register
#'
#' The register holds two kinds of field and they must never mix: what a person
#' asked for is intent, what happened is observation, and this writes only the
#' second. `outcome_payload()` fixes the columns; this refuses anything else at
#' the door, so the separation is a structural property rather than a promise
#' kept by whoever assembles the body.
#'
#' `overwriteBehavior` is `overwrite` and that is deliberate. The body carries
#' exactly the five outcome fields, so overwriting can only clear those; with
#' `normal` an empty `applied_as` would leave the previous one in place, and a
#' transport error would inherit the read-back of an earlier success — an
#' outcome that says "it failed" next to a field that says "here is what it
#' wrote".
#'
#' @inheritParams register_call
#' @param payload A data frame as `outcome_payload()` returns, one row per
#'   record to update. Zero rows is the ordinary quiet round and calls nobody.
#'
#' @return The `register_call()` list plus `scritte`, the number of records
#'   REDCap reports having taken.
#'
#' @keywords internal
register_import <- function(url, token, payload) {
  register_field_import(
    url, token, payload,
    expected = c(
      "record_id", "outcome", "outcome_detail", "outcome_at", "applied_as"
    ),
    caller = "register_import",
    reason = paste(
      "The register's intent and its outcome must not travel together."
    )
  )
}


#' Write the resolved identity back into the register
#'
#' The twin of `register_import()`, and separate from it at the door for the
#' same reason that one exists: the register holds three families of field —
#' what a person asked for, what the round resolved about who they mean, and
#' what happened — and no body may carry two of them. Neither door accepts the
#' other's body, which makes the separation structural rather than a promise
#' kept by whoever assembles it.
#'
#' `overwriteBehavior` is `overwrite`, and the reason here is **not** the one
#' it is right for the outcomes. The body carries the totality of what the
#' round owns on this axis, so overwriting can only blank the round's own two
#' fields — and the blanking is the point: a row that was `existing` and
#' becomes `ambiguous`, which is the renamed-login case, has to lose the
#' username that became false rather than keep it beside a verdict that no
#' longer supports it.
#'
#' @inheritParams register_call
#' @param payload A data frame as `identity_payload()` returns, one row per
#'   record to update. Zero rows is the ordinary quiet round and calls nobody.
#'
#' @return The `register_call()` list plus `scritte`, the number of records
#'   REDCap reports having taken.
#'
#' @keywords internal
register_identity_import <- function(url, token, payload) {
  register_field_import(
    url, token, payload,
    expected = c("record_id", "username", "identity"),
    caller = "register_identity_import",
    reason = paste(
      "What the register was asked and what the round resolved about who it",
      "means must not travel together, and neither may ride with an outcome."
    )
  )
}


#' Send a body REDCap will overwrite, and check it took all of it
#'
#' The transport both writers share, and one copy of it rather than two. What
#' keeps the field families apart is the door each writer fixes — its own
#' column list, refused at the threshold — and not the mechanics of the call,
#' which are the same question asked of the same API. Two copies of the
#' partial-write check would be a place to fix a defect once and leave it
#' standing in the other.
#'
#' @inheritParams register_call
#' @param payload The body, already shaped by its builder.
#' @param expected The exact column names this writer accepts, in order.
#' @param caller The writer's name, so a refusal names the door that refused.
#' @param reason The sentence that says why this body may carry nothing else.
#'
#' @return The `register_call()` list plus `scritte`.
#'
#' @keywords internal
register_field_import <- function(url, token, payload, expected, caller,
                                  reason) {
  if (!is.data.frame(payload) || !identical(names(payload), expected)) {
    stop(
      caller, "(): the body must carry exactly ",
      paste(expected, collapse = ", "), ". ", reason,
      call. = FALSE
    )
  }

  if (nrow(payload) == 0L) {
    return(list(
      ok = TRUE, errors = character(), payload = NULL, scritte = 0L
    ))
  }

  # A missing value would serialize as the string "NA" and land in the register
  # as a word somebody wrote. An empty cell is the absence this means.
  payload[is.na(payload)] <- ""

  answer <- register_call(url, token, list(
    content = "record",
    action = "import",
    type = "flat",
    overwriteBehavior = "overwrite",
    forceAutoNumber = "false",
    returnContent = "count",
    data = as.character(jsonlite::toJSON(payload))
  ))

  if (!isTRUE(answer[["ok"]])) {
    return(c(answer, list(scritte = 0L)))
  }

  taken <- suppressWarnings(as.integer(answer[["payload"]][["count"]]))

  if (is.na(taken) || !identical(taken, nrow(payload))) {
    return(list(
      ok = FALSE,
      errors = "TRASPORTO_REGISTRO_SCRITTURA_PARZIALE",
      payload = answer[["payload"]],
      scritte = if (is.na(taken)) 0L else taken
    ))
  }

  c(answer, list(scritte = taken))
}
