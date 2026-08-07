#' Turn one instance's `state` reply into a single observation row
#'
#' Pure: no network. The v1 of the job observes and does not compare, so this
#' never touches `provisioning_diff()`. That is not a disabled write path but a
#' missing comparison: with no register, every real pair would be classified
#' `revocato`, so the diff is not dangerous but empty of information — while
#' version, gate, reachability and expirations are properties of reality alone
#' and are available now.
#'
#' A server that cannot be reached becomes a row rather than an exception, for
#' the same reason `provisioning_audit()` does it: one instance being down must
#' not hide the state of the others.
#'
#' `scadute` counts pairs REDCap should already be refusing. It is the one of
#' the three drifts that needs no desired state, and the boundary is inclusive
#' because REDCap denies on `expiration <= TODAY` — the day written is already
#' interdicted.
#'
#' @param server The instance name.
#' @param state What `module_state()` returned: a list with `ok`, `errors`,
#'   `payload` and `gate`.
#' @param today The date expirations are compared against. Injected rather than
#'   read from the clock so a fixture cannot turn red on a calendar date for a
#'   reason unrelated to the code.
#'
#' @return A one-row data frame.
#'
#' @keywords internal
observe_instance <- function(server, state, today = Sys.Date()) {
  stopifnot(is.character(server), length(server) == 1L, is.list(state))

  reached <- isTRUE(state[["ok"]])

  row <- data.frame(
    server = server,
    raggiungibile = reached,
    redcap_version = NA_character_,
    redcap_major = NA_integer_,
    version_gate = state[["gate"]] %||% NA_character_,
    surface_fingerprint = NA_character_,
    allowlist_fingerprint = NA_character_,
    coppie = NA_integer_,
    scadute = NA_integer_,
    senza_scadenza = NA_integer_,
    errori = paste(state[["errors"]], collapse = ","),
    stringsAsFactors = FALSE
  )

  if (!reached) {
    return(row)
  }

  payload <- state[["payload"]]
  results <- payload[["results"]] %||% list()

  # A JSON null arrives as NULL and an absent field as NULL too; both mean "no
  # expiration", which is a different fact from "expired" and is counted apart.
  expirations <- vapply(
    results,
    function(pair) as.character(pair[["expiration"]] %||% NA_character_),
    character(1)
  )
  parsed <- suppressWarnings(as.Date(expirations))

  row[["redcap_version"]] <- as.character(payload[["redcap_version"]])
  row[["redcap_major"]] <- as.integer(payload[["redcap_major"]])
  row[["surface_fingerprint"]] <- as.character(payload[["surface_fingerprint"]])
  # Absent on modules older than the release that introduced it. Tolerated in
  # reading for the same reason the contract version is: refusing would blind
  # the audit on the instances a rollout is behind on.
  row[["allowlist_fingerprint"]] <- as.character(
    payload[["allowlist_fingerprint"]] %||% NA_character_
  )
  row[["coppie"]] <- length(results)
  row[["scadute"]] <- sum(!is.na(parsed) & parsed <= today)
  row[["senza_scadenza"]] <- sum(is.na(parsed))
  row[["errori"]] <- NA_character_

  row
}
