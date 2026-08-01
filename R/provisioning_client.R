#' Read the real authorization state from one REDCap instance
#'
#' The only function in the package that speaks to a REDCap server. Everything
#' it returns is re-read state: the channel keeps no local copy, because a copy
#' would only be authoritative if nobody could edit REDCap outside the job,
#' which is neither true nor desirable.
#'
#' The request travels as a JSON body, not in the query string. Two reasons:
#' the assertions of the write operations would not fit in a URL, and in a GET
#' every UPN would land in the access log of each instance on every run. The
#' module declares its page in `no-csrf-pages` so the POST is not rejected —
#' see the spec for why CSRF protection does not apply to this endpoint.
#'
#' @param server Hostname of the instance.
#' @param secret Shared secret, sent as the `X-UBEP-Secret` header.
#' @param pairs List of (username, project_id) pairs; empty reads the whole
#'   instance, which is what the audit needs.
#' @param registry Tested fingerprints, see `check_fingerprint()`.
#'
#' @return A list with `ok`, `errors`, `payload` and `gate`.
#'
#' @keywords internal
module_state <- function(server,
                         secret,
                         pairs = list(),
                         registry = tested_fingerprints()) {
  stopifnot(is.character(server), length(server) == 1L)

  url <- paste0(
    "https://", server,
    "/api/?type=module&prefix=ubep_provisioning&page=api&NOAUTH"
  )

  requests <- lapply(pairs, function(pair) {
    list(
      username = pair[["username"]],
      project_id = pair[["project_id"]]
    )
  })

  response <- tryCatch(
    httr2::request(url) |>
      httr2::req_method("POST") |>
      httr2::req_headers(`X-UBEP-Secret` = secret) |>
      httr2::req_body_json(
        list(operation = "state", requests = requests),
        auto_unbox = TRUE
      ) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform(),
    error = function(e) NULL
  )

  if (is.null(response)) {
    return(list(
      ok = FALSE,
      errors = "TRASPORTO_NON_RAGGIUNGIBILE",
      payload = NULL,
      gate = NA_character_
    ))
  }

  parsed <- parse_module_response(
    httr2::resp_body_string(response),
    status = httr2::resp_status(response)
  )

  # No payload means no major and no fingerprint, so any gate here would be
  # invented. NA says "not established".
  gate <- if (is.null(parsed[["payload"]])) {
    NA_character_
  } else {
    check_fingerprint(parsed[["payload"]], registry)
  }

  c(parsed, list(gate = gate))
}
