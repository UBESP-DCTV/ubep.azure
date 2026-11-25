#' Compose the user principal name used as REDCap username
#'
#' The UPN is not a mailbox: it is the identity the person authenticates with,
#' and it doubles as the REDCap username because the instances are configured
#' with `oauth2_azure_ad_username_attribute = userPrincipalName`. The address
#' someone can actually be reached at travels separately, as `contact_email`.
#'
#' Normalization is delegated to `clean_string()`, which already lowercases,
#' squishes, turns spaces into dots and transliterates accents to ASCII.
#'
#' @param first_name,last_name Person's names, in any casing or accenting.
#' @param domain Tenant domain.
#'
#' @return A single string.
#'
#' @keywords internal
compose_upn <- function(first_name, last_name, domain = "ubep.unipd.it") {
  stopifnot(
    is.character(first_name), length(first_name) == 1L,
    is.character(last_name), length(last_name) == 1L
  )

  local_part <- paste(
    clean_string(first_name),
    clean_string(last_name),
    sep = "."
  )
  local_part <- stringr::str_replace_all(local_part, "\\.+", ".")

  paste0(local_part, "@", domain)
}


#' The date on which REDCap judges an expiration
#'
#' REDCap denies access when `expiration <= TODAY`, and its TODAY is the
#' date of the PHP of the instance, which runs in `Europe/Rome` (measured on
#' 2026-10-22; edc03 does not set it and runs UTC). The machine of the round
#' runs UTC, so between 22:00 and 24:00 UTC (23:00 and 24:00 in winter) its
#' date is the day before Rome's. The gate on the referent's permission and
#' the last day of a request are compared with this date, not with
#' `Sys.Date()`. On edc03 the date in Rome is the later of the two, and in
#' that stretch the gate refuses a few hours before REDCap would: the
#' direction that does not grant.
#'
#' @param now The instant, `Sys.time()` by default.
#'
#' @return A `Date`, the day of `now` in Rome.
#'
#' @keywords internal
redcap_today <- function(now = Sys.time()) {
  as.Date(format(now, "%Y-%m-%d", tz = "Europe/Rome"))
}


#' Validate a provisioning request
#'
#' Returns the data-error codes of the spec's taxonomy. These are errors that
#' belong to whoever filed the request, not to IT: a request carrying them is
#' badly filled in, not badly transported.
#'
#' Errors that need the instance to be answered — a project, role or DAG that
#' does not exist there — cannot be decided here and are left to the module.
#'
#' A last day of access in the past is refused on a request that would write
#' a new one, and only there. A request the round carried out and nobody
#' changed since had a valid last day when it was carried out: its passing is
#' the expiration REDCap applies on the access, decided on 2026-11-10, and
#' refusing it sent the referent to write a date that has not passed, or none,
#' which reopened the access the expiration had closed. A value that is not a
#' date is refused either way.
#'
#' @param request A named list, one request as described in the spec.
#' @param executed Whether the round carried this request out and nobody
#'   changed it since: the channel's seal is there and has not moved.
#' @param today REDCap's date, the one in Rome, `redcap_today()` by default.
#'   The round computes it once, from the instant it started, and passes it
#'   down, so that every row is judged on the same day.
#'
#' @return A character vector of error codes; empty when the request is valid.
#'
#' @keywords internal
validate_request <- function(request, executed = FALSE,
                             today = redcap_today()) {
  stopifnot(
    is.logical(executed), length(executed) == 1L, !is.na(executed),
    inherits(today, "Date"), length(today) == 1L, !is.na(today)
  )

  errors <- character()

  upn <- request[["username"]]
  if (
    is.null(upn) || !is.character(upn) || length(upn) != 1L ||
      !grepl("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", upn)
  ) {
    errors <- c(errors, "DATO_UTENTE_NON_VALIDO")
  }

  project_id <- request[["project_id"]]
  if (
    is.null(project_id) || length(project_id) != 1L ||
      is.na(suppressWarnings(as.integer(project_id)))
  ) {
    errors <- c(errors, "DATO_PROGETTO_INESISTENTE")
  }

  expiration <- request[["expiration"]]
  if (!is.null(expiration) && !is.na(expiration)) {
    parsed <- suppressWarnings(as.Date(expiration, format = "%Y-%m-%d"))
    # A last day of access in the past is refused; today is a valid last day
    # (the intake conversion below stores it as tomorrow, which is what
    # REDCap needs to keep access open through today). Today is REDCap's,
    # the date in Rome (`redcap_today()`): the machine of the round runs
    # UTC, and between 22:00 and 24:00 UTC its date is the day before, which
    # would accept a last day REDCap has already closed. A request already
    # carried out keeps its last day once it has passed: the date is the one
    # the round wrote, not a new one.
    if (is.na(parsed) || (!executed && parsed < today)) {
      errors <- c(errors, "DATO_SCADENZA_NON_VALIDA")
    }
  }

  errors
}


#' Convert a last day of access into the value REDCap stores
#'
#' REDCap denies access when `expiration <= TODAY`, so the day it holds is
#' already out. A request that says "access until 31 December" therefore has
#' to be stored as 1 January. It is a one day error, which is to say the kind
#' nobody sees until it concerns the last day of a study.
#'
#' @param last_day Last day of access, as `YYYY-MM-DD`.
#'
#' @return The value to store, as `YYYY-MM-DD`; `NULL` when `last_day` is
#'   `NULL` or `NA`, i.e. when the request carries no expiration at all.
#'
#' @keywords internal
to_redcap_expiration <- function(last_day) {
  if (is.null(last_day) || is.na(last_day)) {
    return(NULL)
  }

  as.character(as.Date(last_day, format = "%Y-%m-%d") + 1L)
}


#' Take a request in, validated and normalized, or not at all
#'
#' The single door into the pure layer. Validation and the expiration
#' conversion happen together because separating them would leave a way to
#' get a valid request that was never converted, and the way to get the
#' conversion wrong is to forget it.
#'
#' From here on every component — the diff, `apply`, `before` and `after` —
#' speaks the value REDCap stores. The request speaks what a person means.
#'
#' @param request A named list, one request as described in the spec.
#' @param executed Whether the round carried this request out and nobody
#'   changed it since, for `validate_request()`. The conversion is the same:
#'   the round compares the instance with the value REDCap stores.
#' @param today REDCap's date, for `validate_request()`.
#'
#' @return A list with `errors` and `request`; `request` is `NULL` when
#'   `errors` is not empty.
#'
#' @keywords internal
intake_request <- function(request, executed = FALSE,
                           today = redcap_today()) {
  errors <- validate_request(request, executed = executed, today = today)
  if (length(errors) > 0L) {
    return(list(errors = errors, request = NULL))
  }

  # When to_redcap_expiration() returns NULL, `[[<-` removes "expiration"
  # from `request` rather than storing an explicit NULL. Consumers should
  # test with `is.null(request[["expiration"]])`, not
  # `"expiration" %in% names(request)`: the former is true either way, the
  # latter only if the key happens to still be there.
  request[["expiration"]] <- to_redcap_expiration(request[["expiration"]])

  list(errors = character(), request = request)
}
