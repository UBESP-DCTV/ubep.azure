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

  # req_body_form() marks every scalar with base::I() so url_query_build()
  # does not re-flatten it at render time; the marker plays no role beyond
  # that (req_body_render() re-derives the wire body from the raw values
  # regardless of it, verified against this httr2 version). Left in place, it
  # makes every element compare unequal to a plain character scalar under
  # waldo, which is what a caller inspecting the body -- this package's own
  # tests included -- reasonably expects to hold.
  request$body$data <- lapply(request$body$data, function(value) {
    class(value) <- setdiff(class(value), "AsIs")
    value
  })

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
    vapply(records, function(record) {
      value <- record[[field]]
      if (is.null(value) || length(value) != 1L) "" else as.character(value)
    }, character(1))
  })
  names(columns) <- fields

  do.call(
    data.frame,
    c(columns, list(stringsAsFactors = FALSE, check.names = FALSE))
  )
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
    vapply(fields, function(field) {
      value <- field[[key]]
      if (is.null(value) || length(value) != 1L) "" else as.character(value)
    }, character(1))
  })
  names(columns) <- names(map)

  do.call(
    data.frame,
    c(columns, list(stringsAsFactors = FALSE, check.names = FALSE))
  )
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
