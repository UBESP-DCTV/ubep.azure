#' Audit the whole fleet against the desired state
#'
#' Re-reads reality on every run rather than keeping a copy of it, then diffs.
#' Surfaces the three drifts nobody sees today: accesses present in REDCap that
#' no request asked for, assignments requested and since vanished, and
#' expirations that passed without effect.
#'
#' A server that cannot be reached becomes a row, not an exception: one
#' instance being down must not hide the state of the others.
#'
#' Because `state` reports `redcap_major` and `surface_fingerprint`, the audit
#' learns the set of majors in the fleet for free. That set is what the two
#' clauses on retiring compatibility branches rest on.
#'
#' @param servers Character vector of hostnames.
#' @param secrets Named character vector of per-server secrets.
#' @param desired List of validated requests, each carrying the `server` it
#'   belongs to.
#'
#' @return A data frame, one row per (server, user, project).
#'
#' @keywords internal
provisioning_audit <- function(servers, secrets, desired) {
  stopifnot(is.character(servers), all(servers %in% names(secrets)))

  blank_row <- function(server, major, gate, errors) {
    data.frame(
      server = server,
      redcap_major = major,
      gate = gate,
      username = NA_character_,
      project_id = NA_integer_,
      action = NA_character_,
      errors = errors,
      stringsAsFactors = FALSE
    )
  }

  per_server <- lapply(servers, function(server) {
    state <- module_state(server, secrets[[server]])

    if (!isTRUE(state[["ok"]])) {
      return(blank_row(
        server,
        NA_integer_,
        state[["gate"]] %||% NA_character_,
        paste(state[["errors"]], collapse = ",")
      ))
    }

    major <- as.integer(state[["payload"]][["redcap_major"]])
    actual <- state[["payload"]][["results"]]
    # The same username can exist on several instances with different rights,
    # so a request is only relevant to the server it names.
    wanted <- Filter(
      function(request) identical(request[["server"]], server),
      desired
    )
    diff <- provisioning_diff(wanted, actual)

    if (nrow(diff) == 0L) {
      return(blank_row(server, major, state[["gate"]], NA_character_))
    }

    data.frame(
      server = server,
      redcap_major = major,
      gate = state[["gate"]],
      username = diff[["username"]],
      project_id = diff[["project_id"]],
      action = diff[["action"]],
      errors = NA_character_,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, per_server)
}
