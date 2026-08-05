#' Interpret a response from the provisioning module
#'
#' Recognizes the response by its shape, never by its status code. A module
#' that is installed but disabled answers HTTP 200 with a plain sentence, so a
#' client that inferred success from the status would fail inside the JSON
#' parser, reporting an error that does not name the cause.
#'
#' Shape checking does not stop at "did it parse": a bare literal is valid JSON
#' and `jsonlite` turns it into a scalar, so the payload must also be an object.
#'
#' @param body Raw response body.
#' @param status HTTP status code.
#' @param accepted Integer vector of contract versions this call tolerates.
#'   Reads pass both, a write passes only the one that can enforce the surface
#'   handshake — a module that predates it would accept the write and simply
#'   ignore the declaration.
#'
#' @return A list with `ok`, `errors` and `payload`.
#'
#' @keywords internal
parse_module_response <- function(body, status, accepted = c(1L, 2L)) {
  empty <- list(ok = FALSE, errors = character(), payload = NULL)

  payload <- tryCatch(
    jsonlite::fromJSON(body, simplifyVector = FALSE),
    error = function(e) NULL,
    warning = function(w) NULL
  )

  if (is.null(payload) || !is.list(payload)) {
    return(utils::modifyList(empty, list(errors = "TRASPORTO_MODULO_ASSENTE")))
  }

  # The shape is checked before the coercion, never after it. The declared
  # value arrives from JSON and may be anything, and `as.integer()` hides two
  # malformed shapes rather than rejecting them: it collapses a one-element
  # list to a scalar, so `[2]` would read as 2, and it truncates silently, so
  # 2.9 would read as 2. Both would then be accepted as a valid contract —
  # which is the one outcome this check exists to prevent.
  raw <- payload[["contract_version"]]
  well_formed <- is.numeric(raw) && length(raw) == 1L &&
    !is.na(raw) && raw == trunc(raw)

  if (!well_formed || !as.integer(raw) %in% as.integer(accepted)) {
    return(utils::modifyList(
      empty,
      list(errors = "TRASPORTO_CONTRATTO_DISALLINEATO", payload = payload)
    ))
  }

  reported <- vapply(
    payload[["errors"]] %||% list(),
    function(error) as.character(error[["code"]]),
    character(1)
  )
  if (length(reported) > 0L) {
    return(utils::modifyList(
      empty, list(errors = reported, payload = payload)
    ))
  }

  if (!identical(as.integer(status), 200L)) {
    # The module names what went wrong whenever it knows. A failing status with
    # no cause in the body is the module misbehaving, not the request.
    return(utils::modifyList(
      empty, list(errors = "INTERNO", payload = payload)
    ))
  }

  list(ok = TRUE, errors = character(), payload = payload)
}
