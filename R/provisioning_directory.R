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
#' `givenName` and `surname` are here because the resolution refuses a match
#' whose name diverges from the one the request declares, and it cannot refuse
#' on a field the sweep never asked for. They were missing from the plan's
#' select, which was written before that confirmation was traced through; the
#' historical flow populates both, through `-GivenName` and `-Surname` in
#' `ps1_creators.R`.
#'
#' @return A character vector of Graph field names, in the order the frame's
#'   columns take.
#'
#' @keywords internal
directory_fields <- function() {
  c(
    "id", "userPrincipalName", "givenName", "surname", "mail", "otherMails",
    "officeLocation", "jobTitle", "createdDateTime", "accountEnabled",
    "userType"
  )
}


#' Draw the credential an account is born with
#'
#' One credential per person, and there is no batch to be the password of: the
#' historical flow put a single one at the top of a generated `.ps1` and fifteen
#' people shared it, in a file that outlived the act. Here the property is
#' obtained by construction rather than by discipline, because the credential is
#' drawn inside the call that creates the account.
#'
#' **Drawn from `openssl` and not from `sample()`**, which is the one thing
#' about it worth a paragraph. R seeds its own generator from the clock and the
#' process id; this round runs on a timer at six known times a day, so an
#' attacker who knows the schedule is searching a space rather than guessing a
#' secret. What that buys them is not the account's data — it is the enrollment
#' of their own second factor on an account created enabled and with none, which
#' is the tenant's whole defense. `openssl` costs nothing to depend on: `httr2`
#' already does.
#'
#' `generate_password()` is deliberately left alone. It feeds the deprecated
#' `.ps1` path, where the credential is written into a file that survives in a
#' shared folder, and predictability is the least of that one's problems.
#'
#' @param length How many characters. The default clears the floor Entra sets
#'   by a wide margin, and the four classes below are guaranteed one each
#'   because the policy asks for three of them.
#'
#' @return A single string.
#'
#' @keywords internal
directory_credential <- function(length = 24L) {
  stopifnot(is.numeric(length), length(length) == 1L, length >= 8L)

  classes <- list(
    letters, LETTERS, as.character(0:9),
    strsplit("!@#$%^&*()-_=+", "")[[1]]
  )
  pool <- unlist(classes)

  draw <- function(from, n) {
    if (n == 0L) {
      return(character())
    }
    from[floor(openssl::rand_num(n) * length(from)) + 1L]
  }

  guaranteed <- vapply(classes, function(class) draw(class, 1L), character(1))
  chars <- c(guaranteed, draw(pool, as.integer(length) - length(guaranteed)))

  # Shuffled from the same source. A permutation drawn from R's generator would
  # put the four guaranteed characters at positions somebody could work out,
  # which is a smaller hole than a predictable pool and a hole all the same.
  paste(chars[order(openssl::rand_num(length(chars)))], collapse = "")
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


#' The endpoint this package talks to, from the base it was handed
#'
#' One place builds the URL for both calls. A scheme is dropped rather than
#' honored, so a base handed over as http is corrected instead of sending a
#' bearer token in clear — and it is corrected once, where two copies would be
#' the place to fix that in one call and leave it standing in the other.
#'
#' @inheritParams directory_users
#'
#' @return The endpoint, always https and with no trailing slash.
#'
#' @keywords internal
directory_endpoint <- function(base_url) {
  base <- sub("^[A-Za-z][A-Za-z0-9+.-]*://", "", base_url)
  paste0("https://", sub("/+$", "", base))
}


#' Say what went wrong creating an account, and hand back no credential
#'
#' The credential is `NULL` on every failure, and that is the whole reason this
#' exists rather than a list literal at four call sites: a credential
#' traveling beside a failure is a secret nobody will ever use, kept for an
#' account that may not exist.
#'
#' A creation that failed after Graph accepted it — a timeout on the way back —
#' leaves an account whose credential this round has just discarded. It is the
#' honest cost of not keeping one: the next round finds the account by its
#' surname and contact address and writes `created`, and whoever needs to let
#' that person in resets it once. Keeping a secret for a creation we cannot
#' confirm is worse in the direction that matters.
#'
#' @param code The transport code, one of the `TRASPORTO_CREAZIONE_*` family.
#' @param payload Anything worth keeping for a diagnosis, or `NULL`.
#'
#' @return A list with `ok`, `errors`, `payload`, `credential` and `upn`.
#'
#' @keywords internal
creation_failure <- function(code, payload = NULL) {
  list(
    ok = FALSE, errors = code, payload = payload,
    credential = NULL, upn = NULL
  )
}


#' Create on Entra the account a request needs and nobody has
#'
#' The second and last thing this package does on Microsoft Graph, and it does
#' one thing: it creates. `User.Create` is what it runs under, and that
#' permission cannot modify an existing account, reset a credential, disable or
#' delete — which is why the round can hold it without holding everything else.
#'
#' **It does not compose the name it creates.** The UPN is an argument, and the
#' caller takes it from the verdict that found it free. Composing it again here
#' would be two paths to one answer: the day somebody hands a domain to the
#' resolution and not to this, the round would check that one name is free and
#' create another — a UPN nobody has checked for a collision, which is the
#' failure this whole sub-project is about.
#'
#' **`givenName` and `surname` are in the body because the criterion is the
#' surname.** They are not decoration and they are not in the plan's list, which
#' predates the reversal of 2026-08-15: an account created without a surname is
#' an account the next sweep cannot find, while the UPN it would compose is now
#' taken — so the row comes back `collision`, and the round would have created
#' the person and then told them for ever that their name is another person's.
#'
#' **No `jobTitle` and no `officeLocation`.** The first is a live mechanism and
#' not a fossil — 2.828 accounts carry the serialized authorization, 254 of them
#' created in 2026 — so what has to be armed is the not-inheriting, and a guard
#' does it. The second is the legacy carrier of the contact address: read for as
#' long as accounts carry it, written never again.
#'
#' @inheritParams directory_users
#' @param request The register row, read only for `first_name`, `last_name` and
#'   `contact_email`.
#' @param upn The name to create, which the resolution found free.
#'
#' @return A list with `ok`, `errors`, `payload`, `upn`, and `credential` — the
#'   one the account was born with, present only on success. It leaves by the
#'   return value and by no other road: not the register, not the telemetry
#'   record, not standard output.
#'
#' @keywords internal
directory_create_user <- function(token, base_url, request, upn) {
  stopifnot(
    is.character(token), length(token) == 1L, nzchar(token),
    is.character(base_url), length(base_url) == 1L, nzchar(base_url),
    is.list(request),
    is.character(upn), length(upn) == 1L, nzchar(upn)
  )

  field <- function(name) {
    trimws(as.character(request[[name]] %||% ""))
  }
  credential <- directory_credential()

  profile <- list(forceChangePasswordNextSignIn = TRUE)
  profile[["password"]] <- credential

  body <- list(
    accountEnabled = TRUE,
    displayName = trimws(paste(field("first_name"), field("last_name"))),
    givenName = field("first_name"),
    surname = field("last_name"),
    mailNickname = sub("@.*$", "", upn),
    userPrincipalName = upn,
    otherMails = list(field("contact_email")),
    passwordProfile = profile
  )

  response <- tryCatch(
    httr2::request(paste0(directory_endpoint(base_url), "/users")) |>
      httr2::req_method("POST") |>
      httr2::req_auth_bearer_token(token) |>
      httr2::req_body_json(body, auto_unbox = TRUE) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform(),
    error = function(e) NULL
  )

  if (is.null(response)) {
    return(creation_failure("TRASPORTO_CREAZIONE_NON_RAGGIUNGIBILE"))
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
    return(creation_failure("TRASPORTO_CREAZIONE_RISPOSTA_INATTESA"))
  }

  status <- as.integer(httr2::resp_status(response))

  if (!identical(status, 201L)) {
    error <- payload[["error"]]
    scrub <- function(value) {
      gsub(token, "", as.character(value %||% ""), fixed = TRUE)
    }
    # A throttle says "not now", a refusal says "not you", and only one of them
    # passes by itself. Nothing sleeps here: a round that waited inside itself
    # might not return, and a round that does not return leaves no record at
    # all -- at which point the alarm on absence reports that the channel is
    # not running while it is running very hard. The next round is four hours
    # away and re-reads reality anyway.
    return(creation_failure(
      if (identical(status, 429L)) {
        "TRASPORTO_CREAZIONE_RIMANDATA"
      } else {
        "TRASPORTO_CREAZIONE_RIFIUTATA"
      },
      payload = list(
        code = scrub(error[["code"]]), message = scrub(error[["message"]])
      )
    ))
  }

  list(
    ok = TRUE, errors = character(), payload = payload,
    credential = credential, upn = upn
  )
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

  endpoint <- directory_endpoint(base_url)
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
