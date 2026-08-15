#' The directory fields the sweep asks for, and the columns it hands back
#'
#' One list, read twice: it builds the `$select` and it names the columns of
#' the frame. Two copies would be a map between two sets of names, which is
#' where this package keeps finding its worst bugs — and here the drift would
#' be silent in the worst direction, because a field asked for and not read
#' looks exactly like an account that does not carry it.
#'
#' `User.ReadBasic.All` would have been the narrower permission and is not
#' enough for this list: it carries neither `officeLocation`, `otherMails`,
#' `createdDateTime` nor `userType`, which are the four the resolution decides
#' on. The select list is therefore also the reason `User.Read.All` is the
#' permission asked for.
#'
#' @return A character vector of Graph field names, in the order the frame's
#'   columns take.
#'
#' @keywords internal
directory_fields <- function() {
  c(
    "id", "userPrincipalName", "mail", "otherMails", "officeLocation",
    "jobTitle", "createdDateTime", "accountEnabled", "userType"
  )
}


#' Turn parsed Graph user records into a frame of one row per account
#'
#' Every column keeps the type the wire gives it, which is not the same as
#' guessing one. Eight of the nine fields arrive as strings and stay character,
#' with a field the record does not carry becoming `""` rather than `NA` — the
#' absence is what it means, and 1.170 accounts of the tenant have no
#' `officeLocation`. `accountEnabled` is a JSON boolean and stays logical:
#' carried as the string `"FALSE"` it would be a value every `if ()` reads as
#' false and every `nzchar()` reads as present. `otherMails` is the one field
#' that is an array on the wire and stays a list column, because collapsing it
#' would leave the resolution splitting it back apart on a separator no rule
#' says an address cannot contain.
#'
#' @param users The parsed `value` array, a list of one list per account.
#'
#' @return A data frame with one row per account and the columns
#'   `directory_fields()` names, in that order.
#'
#' @keywords internal
directory_frame <- function(users) {
  scalars <- setdiff(directory_fields(), c("otherMails", "accountEnabled"))

  columns <- lapply(scalars, function(field) {
    vapply(
      users,
      function(user) scalar_as_character(user[[field]]),
      character(1)
    )
  })
  names(columns) <- scalars

  columns[["otherMails"]] <- I(lapply(
    users,
    function(user) as.character(unlist(user[["otherMails"]]))
  ))

  # An account whose `accountEnabled` is absent is not an account that is
  # disabled, and NA is the only value that says so without deciding.
  columns[["accountEnabled"]] <- vapply(
    users,
    function(user) {
      value <- user[["accountEnabled"]]
      if (is.null(value) || length(value) != 1L) NA else as.logical(value)
    },
    logical(1)
  )

  columns_frame(columns[directory_fields()])
}


#' Say what went wrong, and hand back no directory at all
#'
#' A half-read sweep is not a small sweep. Every account on a page that did not
#' arrive is missing, and a missing account resolves to `absent`, which is the
#' verdict that opens the creation branch — so partial rows escaping from here
#' would turn a transport failure into duplicate people. `users` is `NULL` on
#' every failure for that reason, and it is what keeps "I could not ask"
#' distinguishable from "nobody is there".
#'
#' @param code The transport code, one of the `TRASPORTO_DIRECTORY_*` family.
#' @param payload Anything worth keeping for a diagnosis, or `NULL`.
#'
#' @return A list with `ok`, `errors`, `payload` and `users`.
#'
#' @keywords internal
directory_failure <- function(code, payload = NULL) {
  list(ok = FALSE, errors = code, payload = payload, users = NULL)
}


#' Fetch one page of the directory
#'
#' The answer is recognized by its shape and by its status, the way the
#' register's client does it and for the same reason: an endpoint that is not
#' the one meant can answer 200 with something that is not JSON, and a client
#' that inferred success from the status would fail inside the parser reporting
#' a cause that is not the cause.
#'
#' @inheritParams directory_users
#' @param url The page to read: the first one this package builds, every one
#'   after it a continuation Graph handed back.
#'
#' @return A list with `ok`, `errors` and `payload`, the last being the parsed
#'   body on success.
#'
#' @keywords internal
directory_page <- function(token, url) {
  response <- tryCatch(
    httr2::request(url) |>
      httr2::req_method("GET") |>
      # Not `req_headers(Authorization = ...)`: this marks the header redacted,
      # so the token is a weak reference inside the request object and cannot
      # be spilled by printing it, by a condition carrying it, or by anything
      # that dumps a request while diagnosing a failed round.
      httr2::req_auth_bearer_token(token) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform(),
    error = function(e) NULL
  )

  if (is.null(response)) {
    return(directory_failure("TRASPORTO_DIRECTORY_NON_RAGGIUNGIBILE"))
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
    return(directory_failure("TRASPORTO_DIRECTORY_RISPOSTA_INATTESA"))
  }

  if (!identical(as.integer(httr2::resp_status(response)), 200L)) {
    # Graph's `code` is the machine-readable half and the one a diagnosis
    # wants: `Authorization_RequestDenied` says the consent was never given,
    # `Request_UnsupportedQuery` says the query is wrong, and the two send
    # whoever reads them to different places. Both halves are scrubbed of the
    # token first: Graph does not echo it today, and relying on that would be
    # trusting the other end to keep our credential.
    error <- payload[["error"]]
    scrub <- function(value) {
      gsub(token, "", as.character(value %||% ""), fixed = TRUE)
    }
    return(directory_failure(
      "TRASPORTO_DIRECTORY_RIFIUTATO",
      payload = list(
        code = scrub(error[["code"]]),
        message = scrub(error[["message"]])
      )
    ))
  }

  # Two questions, and the second is the one that earns its place. An absent
  # `value` and an empty one are already distinguishable with `is.null()` —
  # measured, because the comment here first claimed otherwise: an empty JSON
  # array parses to `list()`, which is not `NULL`. What `is.null()` does not
  # catch is a `value` that is present and is not an array, and that is the
  # shape a wrong endpoint answers with. Read as a page it would be walked
  # field by field and come out as a directory of nobody, reported clean —
  # which the resolution acts on, because "nobody matched" opens the creation
  # branch for every row.
  if (!("value" %in% names(payload)) || !is.list(payload[["value"]])) {
    return(directory_failure("TRASPORTO_DIRECTORY_RISPOSTA_INATTESA"))
  }

  list(ok = TRUE, errors = character(), payload = payload)
}


#' Read the whole directory of the tenant
#'
#' The only function in the package that speaks to Microsoft Graph, and the
#' only one that builds its URL. It does one thing: it sweeps, and it decides
#' nothing — no normalization, no exclusion of guests, no comparison. Those are
#' pure and live elsewhere.
#'
#' **It sweeps rather than filters, and that is a measurement and not a
#' preference.** `officeLocation` — where the historical flow put the contact
#' address, and where 6.494 accounts still carry it — is not filterable
#' server-side at all: Graph answers `Request_UnsupportedQuery`. `mail`, which
#' would be filterable, is `null` on 6.412 accounts out of 7.664, so the
#' obvious attribute is empty on exactly the population to be found. Measured
#' on 2026-08-15 the whole sweep costs 8 pages and 3,5 seconds, which is less
#' than the round that consumes it. It is also decision 4 of the channel's
#' design obtained by construction rather than by discipline: no local copy of
#' the state, the real one is re-read every round.
#'
#' Reading in full has a property a server-side filter would not have given:
#' the comparison is ours, so it can normalize. It has to — 74 accounts carry
#' the address with spaces at the edges, and an `eq` would have missed them in
#' silence, reporting `absent` for people who exist.
#'
#' @param token A Graph access token, sent as a bearer credential in the
#'   `Authorization` header and never in the URL. The managed identity holds
#'   `User.Read.All` and `User.Create`, and neither can modify, disable or
#'   delete an existing account.
#' @param base_url The Graph endpoint, as in `"host.example.org/v1.0"`. It is
#'   an argument and not a constant in this file: this repository is public,
#'   and an endpoint written in is an endpoint published. A scheme is dropped
#'   rather than honored, so a base handed over as http is corrected instead of
#'   sending a bearer token in clear.
#'
#' @return A list with `ok`, `errors` and `payload`, shaped like the other
#'   adapters because it answers the same kind of question, plus `users`, the
#'   frame. "I could not ask" stays distinguishable from "nobody is there":
#'   the first is `ok = FALSE` with `users` `NULL`, the second is `ok = TRUE`
#'   with zero rows.
#'
#' @keywords internal
directory_users <- function(token, base_url) {
  stopifnot(
    is.character(token), length(token) == 1L, nzchar(token),
    is.character(base_url), length(base_url) == 1L, nzchar(base_url)
  )

  base <- sub("^[A-Za-z][A-Za-z0-9+.-]*://", "", base_url)
  base <- sub("/+$", "", base)

  endpoint <- paste0("https://", base)
  url <- paste0(
    endpoint,
    "/users?$select=", paste(directory_fields(), collapse = ","),
    "&$top=999"
  )

  pages <- list()

  repeat {
    answer <- directory_page(token, url)

    if (!isTRUE(answer[["ok"]])) {
      return(answer)
    }

    pages[[length(pages) + 1L]] <- answer[["payload"]][["value"]]

    continuation <- answer[["payload"]][["@odata.nextLink"]]
    if (is.null(continuation)) {
      break
    }

    # The measured sweep is 8 pages over 7.664 accounts, so this ceiling is
    # more than ten times the real shape and cannot be reached by growth. It
    # exists because a server that keeps handing back a continuation would
    # otherwise produce the failure this project can least afford to diagnose:
    # a round that never returns leaves no record at all, and
    # `ubep-canale-assenza` then reports "the channel is not running" while the
    # channel is running very hard.
    if (length(pages) >= 100L) {
      return(directory_failure("TRASPORTO_DIRECTORY_PAGINE_SENZA_FINE"))
    }

    if (!same_endpoint(continuation, endpoint)) {
      return(directory_failure("TRASPORTO_DIRECTORY_PAGINA_ALTROVE"))
    }

    # Followed as given and never rebuilt: the skiptoken carries the select and
    # the page size with it, and a URL reassembled here would quietly restart
    # the sweep from the top of a differently-shaped query.
    url <- continuation
  }

  records <- unlist(pages, recursive = FALSE)
  if (is.null(records)) {
    records <- list()
  }

  list(
    ok = TRUE,
    errors = character(),
    payload = records,
    users = directory_frame(records)
  )
}


#' Is this continuation still the endpoint the caller named?
#'
#' A continuation is a URL the other end chooses, and following it blindly
#' means handing an application credential to whatever host it names. The
#' comparison is on the parsed host and not on a prefix of the string, because
#' `https://graph.example.org@elsewhere.example.net/` starts with the right
#' text and resolves to the wrong machine. The scheme is checked too: a
#' continuation offered over plain HTTP would put the bearer token on the wire
#' in clear.
#'
#' Fails closed on anything it cannot parse, which is the only safe direction
#' for a question whose wrong answer is a leaked credential.
#'
#' @param continuation The `@odata.nextLink` Graph handed back.
#' @param endpoint The base this package built its first URL from.
#'
#' @return `TRUE` only when the continuation is https and on the same host.
#'
#' @keywords internal
same_endpoint <- function(continuation, endpoint) {
  parsed <- tryCatch(
    list(
      next_page = httr2::url_parse(continuation),
      base = httr2::url_parse(endpoint)
    ),
    error = function(e) NULL
  )

  if (is.null(parsed)) {
    return(FALSE)
  }

  identical(parsed[["next_page"]][["scheme"]], "https") &&
    !is.null(parsed[["next_page"]][["hostname"]]) &&
    identical(
      parsed[["next_page"]][["hostname"]],
      parsed[["base"]][["hostname"]]
    )
}
