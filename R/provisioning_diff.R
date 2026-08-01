#' Compare the desired state with the real one
#'
#' The engine of the channel, and the one piece that decides what will actually
#' happen. Pure: no network, no state of its own.
#'
#' The unit of comparison is the (user, project) pair, not the user: the same
#' person may legitimately hold different rights in different projects, and
#' REDCap stores one row per pair.
#'
#' A field wanted absent but present in reality is an update, never a noop.
#' That follows from `apply` asserting the full state rather than a delta, so
#' a DAG nobody asked for has to show up as a difference instead of being
#' tolerated.
#'
#' @param desired List of validated requests.
#' @param actual List of rows as returned by the module's `state`.
#'
#' @return A data frame with one row per pair.
#'
#' @keywords internal
provisioning_diff <- function(desired, actual) {
  fields <- c("role_name", "dag_name", "expiration")
  key_of <- function(x) paste0(x[["username"]], "\r", x[["project_id"]])

  # A JSON null, an absent field and NA all mean "not set"; collapsing them
  # here is what keeps `identical()` a sound test of sameness below.
  normalise <- function(x) {
    values <- lapply(fields, function(field) {
      value <- x[[field]]
      if (is.null(value) || length(value) == 0L || is.na(value)) {
        NULL
      } else {
        as.character(value)
      }
    })
    names(values) <- fields
    values
  }

  absent <- function() {
    values <- vector("list", length(fields))
    names(values) <- fields
    values
  }

  desired_by <- desired
  names(desired_by) <- vapply(desired, key_of, character(1))
  actual_by <- actual
  names(actual_by) <- vapply(actual, key_of, character(1))

  keys <- union(names(desired_by), names(actual_by))

  rows <- lapply(keys, function(key) {
    want <- desired_by[[key]]
    have <- actual_by[[key]]
    before <- if (is.null(have)) absent() else normalise(have)
    after <- if (is.null(want)) absent() else normalise(want)

    action <- if (is.null(want)) {
      "revocato"
    } else if (is.null(have)) {
      "creato"
    } else if (identical(before, after)) {
      "noop"
    } else {
      "aggiornato"
    }

    reference <- if (is.null(want)) have else want
    data.frame(
      username = as.character(reference[["username"]]),
      project_id = as.integer(reference[["project_id"]]),
      action = action,
      before = I(list(before)),
      after = I(list(after)),
      stringsAsFactors = FALSE
    )
  })

  if (length(rows) == 0L) {
    # Same columns as a populated result: the audit binds one frame per server,
    # and a server with nothing to report must not change the shape.
    return(data.frame(
      username = character(),
      project_id = integer(),
      action = character(),
      before = I(list()),
      after = I(list()),
      stringsAsFactors = FALSE
    ))
  }

  do.call(rbind, rows)
}
