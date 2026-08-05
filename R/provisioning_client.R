#' Call one operation on one instance
#'
#' The only function in the package that speaks to a REDCap server, and the
#' only one that builds the URL. Keeping the base normalization here is what
#' stops the three operations from each carrying their own copy of it.
#'
#' @param server Hostname of the instance, optionally followed by the path
#'   REDCap is mounted under, as in `"host.example.org/redcap"`. The fleet is
#'   not uniform on this point, so the mount cannot be assumed.
#' @param secret Shared secret, sent as the `X-UBEP-Secret` header.
#' @param operation One of `"state"`, `"apply"`, `"revoke"`.
#' @param requests List of requests; empty reads the whole instance.
#' @param dry_run Logical; the module writes only on an explicit `FALSE`.
#' @param registry Tested fingerprints, see `check_fingerprint()`.
#'
#' @return A list with `ok`, `errors`, `payload` and `gate`.
#'
#' @keywords internal
module_call <- function(server,
                        secret,
                        operation,
                        requests = list(),
                        dry_run = TRUE,
                        registry = tested_fingerprints()) {
  stopifnot(
    is.character(server), length(server) == 1L,
    is.logical(dry_run), length(dry_run) == 1L, !is.na(dry_run)
  )

  # A scheme is dropped rather than honoured, so a base handed over as http is
  # corrected instead of silently downgrading the channel: the spec allows TLS
  # only, and this is the one place that builds the URL.
  base <- sub("^[A-Za-z][A-Za-z0-9+.-]*://", "", server)
  base <- sub("/+$", "", base)

  url <- paste0(
    "https://", base,
    "/api/?type=module&prefix=ubep_provisioning&page=api&NOAUTH"
  )

  response <- tryCatch(
    httr2::request(url) |>
      httr2::req_method("POST") |>
      httr2::req_headers(`X-UBEP-Secret` = secret) |>
      httr2::req_body_json(
        list(
          operation = operation,
          dry_run = dry_run,
          requests = requests
        ),
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

  # A dry run counts as a read: it changes nothing, and rollout point 1 is
  # "dry_run only, over everything", which a stricter rule would cancel.
  writing <- !dry_run && operation %in% c("apply", "revoke")

  parsed <- parse_module_response(
    httr2::resp_body_string(response),
    status = httr2::resp_status(response),
    accepted = if (writing) 2L else c(1L, 2L)
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


#' Read the real authorization state from one REDCap instance
#'
#' Everything it returns is re-read state: the channel keeps no local copy,
#' because a copy would only be authoritative if nobody could edit REDCap
#' outside the job, which is neither true nor desirable.
#'
#' The request travels as a JSON body, not in the query string. Two reasons:
#' the assertions of the write operations would not fit in a URL, and in a GET
#' every UPN would land in the access log of each instance on every run. The
#' module declares its page in `no-csrf-pages` so the POST is not rejected —
#' see the spec for why CSRF protection does not apply to this endpoint.
#'
#' @inheritParams module_call
#' @param pairs List of (username, project_id) pairs; empty reads the whole
#'   instance, which is what the audit needs.
#'
#' @return A list with `ok`, `errors`, `payload` and `gate`.
#'
#' @keywords internal
module_state <- function(server,
                         secret,
                         pairs = list(),
                         registry = tested_fingerprints()) {
  requests <- lapply(pairs, function(pair) {
    list(
      username = pair[["username"]],
      project_id = pair[["project_id"]]
    )
  })

  module_call(
    server, secret, "state",
    requests = requests, dry_run = TRUE, registry = registry
  )
}


#' Assert the rights a set of people must hold in a set of projects
#'
#' Always asserts the complete state, never a delta: `updatePrivileges` skips
#' fields it is not given, except the DAG, which it clears instead. A delta
#' would revoke DAGs on every renewal and report success — so the caller must
#' pass everything, not just what changed.
#'
#' `dry_run` defaults to `TRUE`, and the module writes only on an explicit
#' `FALSE`. In a dry run `after` is an intention, not an outcome: REDCap can
#' accept a value, store a different one, and still report success, so a
#' green dry run is not a guarantee that the same call will apply cleanly.
#'
#' A write (`dry_run = FALSE`) must concern a single `project_id` across all
#' `requests`; the module rejects a mixed-project write with `400` and code
#' `INTERNO`, because `PROJECT_ID` is an immutable per-process PHP `define()`
#' that selects which project's log gets the trace, so a write spanning two
#' projects would leave one of them untraced. That gate lives in the module,
#' not here. Reads and dry runs are free to span more than one project.
#'
#' @inheritParams module_call
#'
#' @return A list with `ok`, `errors`, `payload` and `gate`.
#'
#' @keywords internal
module_apply <- function(server,
                         secret,
                         requests,
                         dry_run = TRUE,
                         registry = tested_fingerprints()) {
  module_call(
    server, secret, "apply",
    requests = requests, dry_run = dry_run, registry = registry
  )
}


#' Remove the rights a set of people hold in a set of projects
#'
#' Carries the pair and nothing else: revocation does not care which rights
#' are there, and sending them would suggest it does.
#'
#' A write (`dry_run = FALSE`) must concern a single `project_id` across all
#' `requests`; the module rejects a mixed-project write with `400` and code
#' `INTERNO`, because `PROJECT_ID` is an immutable per-process PHP `define()`
#' that selects which project's log gets the trace, so a write spanning two
#' projects would leave one of them untraced. That gate lives in the module,
#' not here. Reads and dry runs are free to span more than one project.
#'
#' @inheritParams module_call
#'
#' @return A list with `ok`, `errors`, `payload` and `gate`.
#'
#' @keywords internal
module_revoke <- function(server,
                          secret,
                          requests,
                          dry_run = TRUE,
                          registry = tested_fingerprints()) {
  pairs <- lapply(requests, function(request) {
    list(
      username = request[["username"]],
      project_id = request[["project_id"]]
    )
  })

  module_call(
    server, secret, "revoke",
    requests = pairs, dry_run = dry_run, registry = registry
  )
}
