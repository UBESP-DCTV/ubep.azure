#' Compare two user names the way REDCap and the register both can be read
#'
#' A REDCap username and a UPN name the same account in two systems that do
#' not agree on capitals, and a name can arrive with blanks at the edges.
#'
#' @param x Character vector of names.
#'
#' @return `x` trimmed and in lower case.
#'
#' @keywords internal
report_name_key <- function(x) {
  tolower(trimws(as.character(x)))
}


#' The date keys an `accounts` entry must carry
#'
#' @return The names of the three dates the report reads, as the module
#'   writes them.
#'
#' @keywords internal
report_account_keys <- function() {
  c("user_firstvisit", "user_lastlogin", "user_lastactivity")
}


#' Read the date of one `accounts` entry
#'
#' @param value A string as the module writes it, `NULL` or `""`.
#'
#' @return A `POSIXct` in UTC, `NA` for an absent date, and `NULL` when the
#'   value is there but does not read.
#'
#' @keywords internal
report_account_time <- function(value) {
  if (is.null(value)) {
    return(as.POSIXct(NA, tz = "UTC"))
  }
  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    return(NULL)
  }
  if (!nzchar(trimws(value))) {
    return(as.POSIXct(NA, tz = "UTC"))
  }

  time <- report_graph_time(value)
  if (is.na(time)) {
    return(NULL)
  }
  time
}


#' Turn the answer of `accounts` into a frame, or refuse it
#'
#' The answer is a reading only if it speaks about everyone who was asked.
#' A missing name read as it stands would be a person who never entered, so
#' an answer that leaves one out, or that is not shaped as the module shapes
#' it, is refused whole: the caller treats the server as not read. An entry
#' that lacks one of the date keys, or has a date that is there but does not
#' read, refuses the answer too, because neither is the same as no date (a key
#' with a null value).
#'
#' Names are compared without regard to case or to spaces at the edges, and
#' the frame carries them that way.
#'
#' @param payload The `payload` of a `module_accounts()` answer.
#' @param asked Character vector of the names that were asked.
#'
#' @return A data frame with `username`, `exists`, `firstvisit`, `lastlogin`
#'   and `lastactivity`, the last three `POSIXct` in UTC with `NA` for an
#'   absent date; `NULL` when the answer is not a reading.
#'
#' @keywords internal
report_accounts_frame <- function(payload, asked) {
  accounts <- payload[["accounts"]]
  if (!is.list(accounts)) {
    return(NULL)
  }

  rows <- lapply(unname(accounts), function(entry) {
    if (!is.list(entry)) {
      return(NULL)
    }
    username <- entry[["username"]]
    exists <- entry[["exists"]]
    if (!is.character(username) || length(username) != 1L ||
          is.na(username) || !nzchar(report_name_key(username))) {
      return(NULL)
    }
    if (!is.logical(exists) || length(exists) != 1L || is.na(exists)) {
      return(NULL)
    }
    # A key that is not there is not a date that is null: it is an answer
    # that does not have the module's shape, and would read as never.
    if (!all(report_account_keys() %in% names(entry))) {
      return(NULL)
    }

    times <- list(
      firstvisit = report_account_time(entry[["user_firstvisit"]]),
      lastlogin = report_account_time(entry[["user_lastlogin"]]),
      lastactivity = report_account_time(entry[["user_lastactivity"]])
    )
    if (any(vapply(times, is.null, logical(1)))) {
      return(NULL)
    }

    c(list(username = report_name_key(username), exists = exists), times)
  })
  if (any(vapply(rows, is.null, logical(1)))) {
    return(NULL)
  }

  asked <- report_name_key(asked)
  asked <- asked[!is.na(asked) & nzchar(asked)]
  answered <- vapply(rows, function(row) row[["username"]], character(1))
  if (!all(asked %in% answered)) {
    return(NULL)
  }

  stamp <- function(field) {
    .POSIXct(
      vapply(rows, function(row) as.numeric(row[[field]]), numeric(1)),
      tz = "UTC"
    )
  }

  data.frame(
    username = answered,
    exists = vapply(rows, function(row) row[["exists"]], logical(1)),
    firstvisit = stamp("firstvisit"),
    lastlogin = stamp("lastlogin"),
    lastactivity = stamp("lastactivity"),
    stringsAsFactors = FALSE
  )
}


#' Read the accounts of the people of each server
#'
#' Asks every server in `asks` for the names it was given and says, for each,
#' whether it was read. A server that was not read is not an error: the
#' report goes on and the pairs of that server fall back on what the directory
#' says. The reason is a code, one of `TRASPORTO_ISTANZA_SENZA_MODULO` (the
#' server has no host), `TRASPORTO_SEGRETO_NON_LEGGIBILE` (no secret, or an
#' `NA`), the first code of the failed `module_accounts()`, or `INTERNO` when
#' the answer is not a reading (see [report_accounts_frame()]).
#'
#' Blank and missing names are not asked: `module_accounts()` lets them pass.
#'
#' @param asks Named list: server name to the user names to ask it.
#' @param hosts Named character vector: server name to host.
#' @param secrets Named character vector: server name to secret.
#'
#' @return A named list with one element per server of `asks`:
#'   `list(letto = TRUE, conti = <frame>)` or
#'   `list(letto = FALSE, motivo = <code>)`.
#'
#' @keywords internal
report_server_reads <- function(asks, hosts, secrets) {
  lookup <- function(values, server) {
    if (!server %in% names(values)) {
      return(NA_character_)
    }
    value <- values[[server]]
    if (!is.character(value) || length(value) != 1L || is.na(value) ||
          !nzchar(value)) {
      return(NA_character_)
    }
    value
  }

  reads <- lapply(names(asks), function(server) {
    host <- lookup(hosts, server)
    if (is.na(host)) {
      return(list(letto = FALSE, motivo = "TRASPORTO_ISTANZA_SENZA_MODULO"))
    }
    secret <- lookup(secrets, server)
    if (is.na(secret)) {
      return(list(letto = FALSE, motivo = "TRASPORTO_SEGRETO_NON_LEGGIBILE"))
    }

    usernames <- trimws(as.character(asks[[server]]))
    usernames <- usernames[!is.na(usernames) & nzchar(usernames)]

    answer <- module_accounts(host, secret, usernames)
    if (!isTRUE(answer[["ok"]])) {
      codes <- as.character(answer[["errors"]])
      return(list(
        letto = FALSE,
        motivo = if (length(codes) > 0L) codes[[1L]] else "INTERNO"
      ))
    }

    conti <- report_accounts_frame(answer[["payload"]], usernames)
    if (is.null(conti)) {
      return(list(letto = FALSE, motivo = "INTERNO"))
    }
    list(letto = TRUE, conti = conti)
  })

  names(reads) <- names(asks)
  reads
}


#' Say whether a person has ever entered a server, and when last
#'
#' A person is `mai_entrata` when the server has no row for her, when the row
#' says the account does not exist, or when she has no first visit. Otherwise
#' she is `entrata`, and the last access is the more recent of `lastlogin` and
#' `lastactivity`, or `firstvisit` when both are absent. The name is found
#' without regard to case or to spaces at the edges.
#'
#' @param conti A frame as [report_accounts_frame()] returns it.
#' @param upn The person's user principal name.
#'
#' @return A list with `stato`, `mai_entrata` or `entrata`, and `ultimo`, a
#'   `POSIXct` in UTC, `NA` for `mai_entrata`.
#'
#' @keywords internal
report_server_access <- function(conti, upn) {
  stopifnot(is.data.frame(conti))

  never <- list(stato = "mai_entrata", ultimo = as.POSIXct(NA, tz = "UTC"))

  key <- report_name_key(upn %||% "")
  if (length(key) != 1L || is.na(key) || !nzchar(key)) {
    return(never)
  }
  hit <- which(report_name_key(conti[["username"]]) == key)
  if (length(hit) == 0L) {
    return(never)
  }

  row <- conti[hit[[1L]], , drop = FALSE]
  if (!isTRUE(row[["exists"]]) || is.na(row[["firstvisit"]])) {
    return(never)
  }

  seen <- c(row[["lastlogin"]], row[["lastactivity"]])
  seen <- seen[!is.na(seen)]
  ultimo <- if (length(seen) > 0L) max(seen) else row[["firstvisit"]]

  list(stato = "entrata", ultimo = ultimo)
}
