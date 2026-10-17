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
#' The fourth refuses like the others and is **addressed differently**, which
#' is the one thing this function says twice. `DATO_` and `TRASPORTO_` are not
#' labels on an error, they are a delivery address: the first closes the row
#' against whoever filed it and mails them, the second keeps it queued and
#' mails us. Someone whose rights row exists and whose permission is
#' unreadable filed a correct request and may well hold the permission — what
#' is broken is inside REDCap, where only IT can reach it. Saying "you are not
#' authorized" there sends the one person who cannot fix it to go and argue.
#'
#' @param register The register as a data frame, carrying at least `record_id`,
#'   `server`, `project_id` and `requested_by`.
#' @param rights The rights read from the instances, as a data frame with
#'   `server`, `project_id`, `username` and `user_rights`. The caller assembles
#'   it from each instance's answer, because a `state` reply names its server
#'   once at the top and not on every row.
#'
#' @return A named list, one entry per refused row, named by `record_id` and
#'   holding `"DATO_AMBITO_NON_AUTORIZZATO"`, or
#'   `"TRASPORTO_PERMESSO_NON_LEGGIBILE"` when the requester has a rights row
#'   on that project whose permission could not be read. Empty when every row
#'   is in scope. The shape matches `register_to_desired()$errors` so the two
#'   merge, and the caller reads the prefix rather than the whole string.
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
  # module too old to report it, and it reads here as a column of NAs: every
  # row then refuses, which is the loud failure. The quiet one would be
  # granting them all because a column was missing, and nobody re-reads a
  # green.
  columns <- c("server", "project_id", "username")
  keyed <- all(columns %in% names(rights)) && nrow(rights) > 0L

  granted <- character()
  unreadable <- character()

  if (keyed) {
    held <- scope_key(
      rights[["server"]], rights[["project_id"]], rights[["username"]]
    )
    permission <- if ("user_rights" %in% names(rights)) {
      suppressWarnings(as.integer(rights[["user_rights"]]))
    } else {
      rep(NA_integer_, length(held))
    }

    granted <- held[!is.na(permission) & permission == scope_granting_value()]
    unreadable <- held[is.na(permission)]
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

  # The refusal is the same; the address on it is not. A permission nobody
  # could read is not a verdict about the requester, and the prefix is what
  # decides who is told and whether the row comes back next round.
  codes <- ifelse(
    attributed & keys %in% unreadable,
    "TRASPORTO_PERMESSO_NON_LEGGIBILE",
    "DATO_AMBITO_NON_AUTORIZZATO"
  )

  ids <- as.character(register[["record_id"]])
  out <- as.list(codes[refused])
  names(out) <- ids[refused]

  out
}


#' Put one line in the register for each person the gate must judge
#'
#' The gate asks of a requester "could you have done this by hand". What the
#' channel executes can have been written by more than one person, and the
#' rule is the same for all of them: **whoever wrote what is executed must be
#' able to do it by hand.** The rights of whoever approves are not checked,
#' because approving is not writing: it adds no power to the change.
#'
#' This turns a register and the people to judge for each of its rows into a
#' register `scope_errors()` can read: one line per row and subject, with
#' `requested_by` set to the subject. A row with nobody to judge stays once,
#' with an empty `requested_by`, so that `scope_errors()` refuses it as not
#' attributed and it does not slip through for lack of a name.
#'
#' @param register The register as a data frame, carrying at least
#'   `record_id`, `server` and `project_id`.
#' @param subjects A list as long as the rows of `register`, each element the
#'   usernames to judge for that row.
#'
#' @return `register` with one line per row and subject, in the order of the
#'   rows and then of the subjects, and `requested_by` equal to the subject.
#'
#' @keywords internal
scope_expand <- function(register, subjects) {
  stopifnot(
    is.data.frame(register),
    all(c("record_id", "server", "project_id") %in% names(register)),
    is.list(subjects), length(subjects) == nrow(register)
  )

  who <- lapply(subjects, function(s) {
    s <- unique(as.character(s))
    if (length(s) == 0L) "" else s
  })
  rows <- rep(seq_len(nrow(register)), lengths(who))

  out <- register[rows, , drop = FALSE]
  out[["requested_by"]] <- as.character(unlist(who, use.names = FALSE))
  rownames(out) <- NULL

  out
}


#' Bring the refusals of the several subjects of a row back to one
#'
#' The other half of `scope_expand()`: `scope_errors()` answers per line, so a
#' row judged on several people comes back once for each of them who is
#' refused. The row is one, and so is its answer. A permission nobody could
#' read decides it, because that refusal is not a verdict about anybody and
#' keeps the row queued; otherwise the row is refused as not authorized.
#'
#' @param refused What `scope_errors()` returned for an expanded register: a
#'   named list, names repeated.
#'
#' @return A named list, one entry per `record_id`, in the order each first
#'   appears, holding `"TRASPORTO_PERMESSO_NON_LEGGIBILE"` when any of its
#'   codes is that and `"DATO_AMBITO_NON_AUTORIZZATO"` otherwise.
#'
#' @keywords internal
scope_merge <- function(refused) {
  stopifnot(is.list(refused))

  ids <- unique(names(refused))
  codes <- vapply(ids, function(id) {
    mine <- unlist(refused[names(refused) == id])
    if ("TRASPORTO_PERMESSO_NON_LEGGIBILE" %in% mine) {
      "TRASPORTO_PERMESSO_NON_LEGGIBILE"
    } else {
      "DATO_AMBITO_NON_AUTORIZZATO"
    }
  }, character(1L))

  out <- as.list(codes)
  names(out) <- ids

  out
}


#' Judge at the gate a revocation somebody other than its creator made
#'
#' The second half of the exception `change_needs_approval()` makes for a
#' revocation, the half only an instance can answer. The round holds the row
#' provisionally until it knows who manages the project, and this is where it
#' finds out.
#'
#' The question is the gate's own, asked of different people. A revocation
#' stands on the authority of whoever had a hand in it, so each of them is
#' asked "could you have done this by hand", which for a removal is "do you
#' hold User Rights on this project". The creator is asked only when the
#' creator is one of them: a creator who no longer manages the project does
#' not stop a manager from removing somebody, since the manager could have
#' done it in REDCap anyway.
#'
#' Three answers. A permission that could not be read is ours, as on the
#' ordinary gate, and keeps the row queued. A creator who had a hand in it and
#' does not manage the project is refused as the creator's own change would
#' be. Anybody else who does not manage it puts the row back under the common
#' rule: it waits for the creator.
#'
#' @param row The row, one line of the register as the gate reads it.
#' @param authors Who has a hand in the change, as `log_pending_authors()`
#'   answers.
#' @param owner Who the row belongs to: the creator, or the referent it passed
#'   to.
#' @param sealed Whether the row carries the seal of an execution.
#' @param rights The rights the instance reported, as `round_rights()` builds
#'   them.
#'
#' @return `""` when the revocation stands; `"held"` when it waits for the
#'   creator; otherwise the refusal code, as `scope_errors()` gives it.
#'
#' @keywords internal
scope_withdrawal <- function(row, authors, owner, sealed, rights) {
  stopifnot(
    is.data.frame(row), nrow(row) == 1L, is.character(authors),
    is.character(owner), length(owner) == 1L, is.data.frame(rights)
  )

  owner <- trimws(owner)
  subjects <- unique(trimws(authors))
  if (anyNA(subjects) || !all(nzchar(subjects)) || length(subjects) == 0L) {
    return("held")
  }

  asked <- data.frame(
    record_id = subjects,
    server = rep(as.character(row[["server"]]), length(subjects)),
    project_id = rep(as.character(row[["project_id"]]), length(subjects)),
    requested_by = subjects,
    stringsAsFactors = FALSE
  )
  refused <- scope_errors(asked, rights)
  if ("TRASPORTO_PERMESSO_NON_LEGGIBILE" %in% unlist(refused)) {
    return("TRASPORTO_PERMESSO_NON_LEGGIBILE")
  }
  if (owner %in% names(refused)) {
    return("DATO_AMBITO_NON_AUTORIZZATO")
  }

  managers <- setdiff(subjects, names(refused))
  waits <- change_needs_approval(
    authors, owner, sealed = sealed, revocation = TRUE, managers = managers
  )
  if (waits) "held" else ""
}
