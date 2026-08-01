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


#' Validate a provisioning request
#'
#' Returns the data-error codes of the spec's taxonomy. These are errors that
#' belong to whoever filed the request, not to IT: a request carrying them is
#' badly filled in, not badly transported.
#'
#' Errors that need the instance to be answered — a project, role or DAG that
#' does not exist there — cannot be decided here and are left to the module.
#'
#' @param request A named list, one request as described in the spec.
#'
#' @return A character vector of error codes; empty when the request is valid.
#'
#' @keywords internal
validate_request <- function(request) {
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
    # REDCap needs to keep access open through today). The comparison uses
    # the client's date while REDCap uses the server's, which runs UTC: at
    # most a one-day boundary, and it errs towards refusing rather than
    # granting.
    if (is.na(parsed) || parsed < Sys.Date()) {
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
#' @return The value to store, as `YYYY-MM-DD`.
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
#'
#' @return A list with `errors` and `request`; `request` is `NULL` when
#'   `errors` is not empty.
#'
#' @keywords internal
intake_request <- function(request) {
  errors <- validate_request(request)
  if (length(errors) > 0L) {
    return(list(errors = errors, request = NULL))
  }

  request[["expiration"]] <- to_redcap_expiration(request[["expiration"]])

  list(errors = character(), request = request)
}
