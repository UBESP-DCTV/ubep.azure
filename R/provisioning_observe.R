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


#' Build the record a run leaves behind
#'
#' The channel keeps no copy of the state it reconciles, so a run leaves no
#' other trace: this record is it. That is not in tension with "no local store
#' of the state" — what that forbids is a copy of what can be re-read, and a
#' run log is the only evidence of an event that leaves none.
#'
#' It carries `letture_riuscite` because the alarm on absence fires on the lack
#' of a record with at least one successful read. Were it to say only "the
#' process started", a job that started, failed against every instance and
#' exited would satisfy the alarm — a detector the fault can meet, which is the
#' shape of defect this project has already found twice.
#'
#' `major_singleton` is the condition the two clauses on retiring compatibility
#' branches rest on. Nothing observed it before this.
#'
#' @param observations Rows from `observe_instance()`, bound together.
#' @param at When the run finished, as `YYYY-MM-DD HH:MM`. Passed in rather
#'   than read here so the record stays a pure function of what was observed.
#'
#' @return A named list, ready to be serialized as one JSON object.
#'
#' @keywords internal
run_record <- function(observations, at) {
  stopifnot(
    is.data.frame(observations),
    is.character(at), length(at) == 1L
  )

  # `unique(sort(x))` drops NA on its own; naming the intent here rather than
  # reaching for stats::na.omit avoids an Imports entry for one call.
  distinct <- function(values) {
    values <- values[!is.na(values)]
    sort(unique(values))
  }

  reached <- observations[["raggiungibile"]]
  majors <- distinct(observations[["redcap_major"]][reached])

  list(
    at = at,
    istanze = nrow(observations),
    letture_riuscite = sum(reached),
    irraggiungibili = sum(!reached),
    major_in_flotta = as.integer(majors),
    major_singleton = length(majors) == 1L,
    impronte_superficie = distinct(observations[["surface_fingerprint"]]),
    impronte_allowlist = distinct(observations[["allowlist_fingerprint"]]),
    coppie_scadute = sum(observations[["scadute"]], na.rm = TRUE),
    coppie_totali = sum(observations[["coppie"]], na.rm = TRUE)
  )
}


#' Serialize a run record, keeping list-valued fields as arrays
#'
#' `auto_unbox` collapses a one-element vector into a scalar, which is right
#' for the counters and wrong for everything that is semantically a list: a
#' fleet with a single instance would emit a string where the alert query
#' expects an array, and the fault would stay hidden until the day only one
#' instance answers.
#'
#' This is the same length-one array trap the client already met on the request
#' side, where the declared fingerprints had to be sent as a list because the
#' registry holds one row. Same trap, other end of the wire.
#'
#' @param record What `run_record()` returned.
#'
#' @return A JSON string, one object.
#'
#' @keywords internal
run_record_json <- function(record) {
  stopifnot(is.list(record))

  as_array <- c(
    "major_in_flotta",
    "impronte_superficie",
    "impronte_allowlist",
    "senza_modulo"
  )

  for (field in intersect(as_array, names(record))) {
    record[[field]] <- I(record[[field]])
  }

  as.character(
    jsonlite::toJSON(record, auto_unbox = TRUE, null = "null", digits = NA)
  )
}
