#' The value of REDCap's user_rights permission that grants management
#'
#' REDCap stores this permission as an integer, and only one value means "may
#' manage the users of this project". Anything else refuses, including a value
#' a future REDCap adds: a third value would have to be read before it is
#' trusted, and reading it as "close enough to one" is how a permission gets
#' widened by an upgrade nobody connected to this file.
#'
#' Measured on 2026-08-14, not assumed: on a REDCap 17.3.3 instance the channel
#' serves, 33 pairs reported this permission and it took exactly two values —
#' 25 ones and 8 zeros. So on the version in exercise there is no third value to
#' decide about, and this constant is a fact rather than a guess. The paragraph
#' above is what happens when that stops being true.
#'
#' @return The integer that grants.
#'
#' @keywords internal
scope_granting_value <- function() {
  1L
}


#' The key three fields make, with a separator that cannot occur in them
#'
#' Same discipline as the register's own key, and for the same reason: joined
#' without a separator, `("edc05", 90, "3a@x")` and `("edc05", 903, "a@x")` read
#' as one string, and a lookup would answer for the wrong pair. A control
#' character occurs in none of the three.
#'
#' @param server,project_id,username The three parts, as character vectors.
#'
#' @return A character vector of keys.
#'
#' @keywords internal
scope_key <- function(server, project_id, username) {
  paste(
    trimws(as.character(server)),
    trimws(as.character(project_id)),
    trimws(as.character(username)),
    sep = "\r"
  )
}


#' Is this cell filled in
#'
#' @param values A vector from a register column.
#'
#' @return A logical vector.
#'
#' @keywords internal
scope_filled <- function(values) {
  text <- trimws(as.character(values))
  !is.na(text) & nzchar(text)
}


#' The rights an instance has to be asked about before a request is applied
#'
#' The scope gate asks whether the person who filed a request may manage the
#' users of the project they filed it for. That question is about the
#' **requester**, not about the person the request is for, so it needs a state
#' read the channel does not otherwise make: `module_state()` answers for the
#' pairs it is given, and the pairs it is given are the grantees.
#'
#' Rows with no server or no project are not asked about. There is nothing to
#' ask — and `validate_request()` already reports the project one. A row with no
#' requester is not asked about either, and is refused by `scope_errors()`
#' instead: an unattributable row cannot be answered by any instance.
#'
#' @param register The register as a data frame, carrying at least `server`,
#'   `project_id` and `requested_by`.
#'
#' @return A data frame with `server`, `project_id` and `username`, one row per
#'   distinct triple. The requester travels under `username` because that is the
#'   name `module_state()` expects in a pair.
#'
#' @keywords internal
scope_pairs <- function(register) {
  stopifnot(
    is.data.frame(register),
    all(c("server", "project_id", "requested_by") %in% names(register))
  )

  askable <- scope_filled(register[["server"]]) &
    scope_filled(register[["project_id"]]) &
    scope_filled(register[["requested_by"]])

  out <- data.frame(
    server = trimws(as.character(register[["server"]]))[askable],
    project_id = trimws(as.character(register[["project_id"]]))[askable],
    username = trimws(as.character(register[["requested_by"]]))[askable],
    stringsAsFactors = FALSE
  )

  out[!duplicated(scope_key(out$server, out$project_id, out$username)), ,
    drop = FALSE
  ]
}


#' Refuse the rows whose requester does not manage the project they ask about
#'
#' The channel applies a request without anyone reading it, so what bounds a
#' request is not review but the requester's own rights. The rule this enforces
#' is worth stating as one sentence, because it is the reason the gate is this
#' one and not a table somebody keeps: **the channel must not let anyone do
#' something they could not already do by hand.** Holding REDCap's user_rights
#' permission on a project is exactly "could have granted this access
#' themselves", so the channel automates a power instead of adding one.
#'
#' Four ways a row is refused, and they are one rule and not four special
#' cases — every one of them is "the permission was not read as granting":
#'
#' - the row carries no requester, so nothing can be attributed to anybody;
#' - the requester holds no rights at all on that project, so there is no row;
#' - the permission was read and does not grant;
#' - the permission could not be read, which is the case that decides the
#'   direction of the whole function. An instance answered by a module too old
#'   to report the permission, a role deleted underneath a row, a column that
#'   read as empty: none of these is a permission, and treating them as one
#'   would widen access exactly when the channel has stopped being able to see.
#'
#' @param register The register as a data frame, carrying at least `record_id`,
#'   `server`, `project_id` and `requested_by`.
#' @param rights The rights read from the instances, as a data frame with
#'   `server`, `project_id`, `username` and `user_rights`. The caller assembles
#'   it from each instance's answer, because a `state` reply names its server
#'   once at the top and not on every row.
#'
#' @return A named list, one entry per refused row, named by `record_id` and
#'   holding `"DATO_AMBITO_NON_AUTORIZZATO"`. Empty when every row is in scope.
#'   The shape matches `register_to_desired()$errors` so the two merge.
#'
#' @keywords internal
scope_errors <- function(register, rights) {
  stopifnot(
    is.data.frame(register),
    all(
      c("record_id", "server", "project_id", "requested_by") %in%
        names(register)
    ),
    is.data.frame(rights)
  )

  # A rights table with no permission column is an instance answered by a
  # module too old to report it. Every row then refuses, which is the loud
  # failure; the quiet one would be granting them all because a column was
  # missing, and nobody re-reads a green.
  columns <- c("server", "project_id", "username", "user_rights")
  readable <- all(columns %in% names(rights)) && nrow(rights) > 0L

  granted <- character()
  if (readable) {
    permission <- suppressWarnings(as.integer(rights[["user_rights"]]))
    grants <- !is.na(permission) & permission == scope_granting_value()
    granted <- scope_key(
      rights[["server"]][grants],
      rights[["project_id"]][grants],
      rights[["username"]][grants]
    )
  }

  askable <- scope_filled(register[["server"]]) &
    scope_filled(register[["project_id"]])
  attributed <- scope_filled(register[["requested_by"]])

  keys <- scope_key(
    register[["server"]],
    register[["project_id"]],
    register[["requested_by"]]
  )
  refused <- askable & (!attributed | !(keys %in% granted))

  ids <- as.character(register[["record_id"]])
  out <- rep(list("DATO_AMBITO_NON_AUTORIZZATO"), sum(refused))
  names(out) <- ids[refused]

  out
}
