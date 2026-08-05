#' Fingerprints of REDCap surfaces this client has been tested against
#'
#' One row per surface actually measured on a running instance. Rows with an
#' empty fingerprint are dropped: a placeholder must not be able to certify an
#' instance as tested.
#'
#' @return A data frame with `redcap_major` and `fingerprint`.
#'
#' @keywords internal
tested_fingerprints <- function() {
  path <- system.file(
    "extdata", "tested-fingerprints.csv", package = "ubep.azure"
  )
  registry <- readr::read_csv(path, show_col_types = FALSE)

  keep <- !is.na(registry[["fingerprint"]]) &
    registry[["fingerprint"]] != ""

  registry[keep, , drop = FALSE]
}


#' Confirm the instance surface is one we have tested against
#'
#' The major says which code path applies; the fingerprint says whether that
#' path is still the one we tested. An instance can be in the right major and
#' have a changed surface — the case no version comparison can see.
#'
#' Downgrades only: a fingerprint can move an instance from `collaudata` to
#' `non_collaudata`, never the other way. An unknown fingerprint is not a
#' failure, it is a version waiting to be tested, and downgrading is how the
#' system asks for that instead of writing blind.
#'
#' @param payload Parsed module response.
#' @param registry Data frame of tested fingerprints.
#'
#' @return The effective gate, as a single string.
#'
#' @keywords internal
check_fingerprint <- function(payload, registry = tested_fingerprints()) {
  declared <- payload[["version_gate"]]
  if (!identical(declared, "collaudata")) {
    return(declared)
  }

  known <- registry[["fingerprint"]][
    registry[["redcap_major"]] == payload[["redcap_major"]]
  ]

  if (payload[["surface_fingerprint"]] %in% known) {
    "collaudata"
  } else {
    "non_collaudata"
  }
}


#' Report whether the conformance test has been passed on a major
#'
#' The observable fact that declares the phase two write restraint
#' removable. It is deliberately not an intention: in this repository two
#' pieces of "temporary" code survived for years because their removal
#' depended on an event someone had to remember, so this one is a value a
#' test can read.
#'
#' The date is written by the conformance run itself, not by hand.
#'
#' @param major REDCap major version.
#' @param registry Data frame of tested fingerprints.
#'
#' @return A single logical.
#'
#' @keywords internal
conformance_passed <- function(major, registry = tested_fingerprints()) {
  if (!"conformance_passed_on" %in% names(registry)) {
    return(FALSE)
  }

  # A registry with no conformance recorded anywhere is read by
  # readr::read_csv() as an all-NA logical column, not character; coerce
  # explicitly so the comparison below never depends on whether a
  # conformance has ever been recorded. as.character(NA) stays
  # NA_character_, so the "no conformance" branch is unaffected.
  dates <- as.character(
    registry[["conformance_passed_on"]][
      registry[["redcap_major"]] == major
    ]
  )

  any(!is.na(dates) & dates != "")
}
