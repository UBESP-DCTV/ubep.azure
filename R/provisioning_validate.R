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
    # REDCap applies `expiration <= TODAY`, so the day written is already out
    # and today is refused too. The comparison uses the client's date while
    # REDCap uses the server's, which runs UTC: at most a one-day boundary,
    # and it errs towards refusing rather than granting.
    if (is.na(parsed) || parsed <= Sys.Date()) {
      errors <- c(errors, "DATO_SCADENZA_NON_VALIDA")
    }
  }

  errors
}
