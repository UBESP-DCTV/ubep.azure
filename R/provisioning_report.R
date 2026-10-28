#' How far apart an account's two dates may be and still mean "never in"
#'
#' Sixty seconds, decided on 2026-10-15 after one measurement: an account the
#' round created on 2026-10-08 carried `createdDateTime` and
#' `lastPasswordChangeDateTime` equal to the second six days later, and its
#' person said they had not signed in yet. The key is born in the call that
#' makes the account, so the two dates differ only by what Entra takes to
#' write them; the round creates every account with the change of key forced
#' at first sign-in, so a person who has signed in has moved the second date.
#'
#' Confirmed on 2026-10-16 over the enabled accounts of the tenant: the
#' accounts known never to have been used sit at 0 seconds, none falls
#' between 1 and 30, a handful between 31 and 120; an account made by hand on
#' the portal and used once sits at 172.
#'
#' One value, in one place: a later measurement changes it in one line.
#'
#' @return Seconds.
#'
#' @keywords internal
report_tolerance <- function() {
  60
}


#' How many days after its activation a request is asked for a first sign-in
#'
#' Thirty, counted on the calendar in Rome: a request activated on the second
#' day of a month is in the report of the first day of the month after. Every
#' person has between 30 and 61 days before their first mention.
#'
#' @return Days.
#'
#' @keywords internal
report_grace_days <- function() {
  30L
}


#' Move a `AAAA-MM` month by a number of months
#'
#' @param month A month, `"%Y-%m"`.
#' @param by How many months, negative to go back.
#'
#' @return A month, `"%Y-%m"`.
#'
#' @keywords internal
report_shift_month <- function(month, by) {
  stopifnot(is.character(month), length(month) == 1L)
  index <- as.integer(substr(month, 1L, 4L)) * 12L +
    as.integer(substr(month, 6L, 7L)) - 1L + as.integer(by)
  sprintf("%04d-%02d", index %/% 12L, index %% 12L + 1L)
}


#' Which month a run of the report covers, and when it reads
#'
#' The report of the 1st of November covers October: a calendar month in
#' Italian civil time, from the 1st at midnight to the 1st of the next month,
#' excluded. The cut is made in Rome and not in UTC, so a run at 23:30 UTC on
#' the 31st is already in the next month, as it is on the clock of whoever
#' reads the mail.
#'
#' The run is daily, so the month it covers is always the one before the
#' month it runs in: it sends from the 1st on, to whoever has not received
#' that month's report yet. A **forced** month replaces the one the clock
#' gives, for a run by hand that has to show a month that is not over yet;
#' the day stays the real one, since it is what lateness is judged on.
#'
#' @param now When the run reads, any time zone.
#' @param forced A month `"AAAA-MM"` to cover instead, or `NULL`.
#'
#' @return A list with `mese`, the month covered; `forzato`; `giorno`, the
#'   day of the month the run is in, in Rome; `letto`, the reading time as
#'   `"%Y-%m-%d %H:%M"` in Rome; `oggi`, the date in Rome; `prossimo`, the
#'   date of the next report.
#'
#' @keywords internal
report_month <- function(now, forced = NULL) {
  stopifnot(inherits(now, "POSIXct"), length(now) == 1L, !is.na(now))

  rome <- format(now, "%Y-%m-%d %H:%M", tz = "Europe/Rome")

  if (is.null(forced)) {
    covered <- report_shift_month(substr(rome, 1L, 7L), -1L)
  } else {
    if (!is.character(forced) || length(forced) != 1L ||
          !grepl("^[0-9]{4}-(0[1-9]|1[0-2])$", forced)) {
      stop(
        "report_month(): il mese forzato va scritto AAAA-MM, per esempio ",
        "2026-10.",
        call. = FALSE
      )
    }
    covered <- forced
  }

  list(
    mese = covered,
    forzato = !is.null(forced),
    giorno = as.integer(substr(rome, 9L, 10L)),
    letto = rome,
    oggi = as.Date(substr(rome, 1L, 10L)),
    prossimo = as.Date(paste0(report_shift_month(covered, 2L), "-01"))
  )
}


#' Say a month in Italian and in English
#'
#' Written out here rather than asked of the locale, which on the machine is
#' whatever the image ships with and on a laptop whatever its owner chose.
#'
#' @param month A month, `"%Y-%m"`.
#'
#' @return A character vector named `it` and `en`.
#'
#' @keywords internal
report_month_words <- function(month) {
  stopifnot(is.character(month), length(month) == 1L)

  mesi <- c(
    "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio",
    "agosto", "settembre", "ottobre", "novembre", "dicembre"
  )
  number <- as.integer(substr(month, 6L, 7L))
  year <- substr(month, 1L, 4L)

  c(it = paste(mesi[[number]], year), en = paste(month.name[[number]], year))
}


#' Say a day in Italian and in English
#'
#' @param date A `Date`.
#'
#' @return A character vector named `it` and `en`, as in `"1 dicembre 2026"`.
#'
#' @keywords internal
report_day_words <- function(date) {
  stopifnot(inherits(date, "Date"), length(date) == 1L)

  month <- report_month_words(format(date, "%Y-%m"))
  day <- as.integer(format(date, "%d"))
  c(it = paste(day, month[["it"]]), en = paste(day, month[["en"]]))
}


#' When the channel executed a row, from the row's own log
#'
#' The date of activation is the channel's **first** write of `applied_seal`,
#' and not `outcome_at`: the outcome is rewritten at every outcome, so a row
#' that went from `applied` to `transport_error` and back would look activated
#' twice. Only the round writes the seal, and only when it has applied the
#' row; a row executed again after an approved change writes a new one, which
#' is how the report tells a modified request from a new one.
#'
#' The events are filtered here by `record`, whatever REDCap did with the
#' parameter. Measured on 2026-10-16 that `exportLogging` honors it; the
#' filter stays, at no cost, because an instance that ignored it would hand
#' back the whole log, where another row's execution would date this one.
#'
#' The author has to be the channel, the account `log_channel_accounts()`
#' names: the configured `channel_account`, or, without it, whoever wrote the
#' channel's fields. With the account configured, a write of the seal by any
#' other account executed nothing and is ignored, a referent's import
#' included. Without it, when two accounts write those fields the log cannot
#' say which of them executed the row, `log_channel_unknown()`, and the
#' answer is unknown rather than a guess.
#'
#' Only the row that stands now is read. The register reuses record ids: one
#' made for a field test, deleted on 2026-09-01 with the rest and made again
#' as a real request, has both lives in its log, and the old one's seal would
#' date the new request months before it existed, and make its first
#' execution read as a change. `log_of_record()` keeps the row's current life
#' only, from its newest creation on, as for the round, and the channel's
#' account is recognized on that.
#'
#' The stamps stay in the instance's civil time, which is Rome: measured on
#' 2026-09-01, a round at 21:03 UTC is logged at 23:03, and again on
#' 2026-10-16, a first seal logged at 22:04 beside an `outcome_at` of 20:03
#' UTC. A month is then the
#' first seven characters of the stamp, and no conversion can shift a row
#' activated on the last evening of the month into the next one.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param record The record id.
#' @param channel_account The REDCap usernames that hold the register's
#'   token, one or more, or `NULL` when they are not configured, for
#'   `log_channel_accounts()`.
#'
#' @return The stamps of the channel's seal writes, `"%Y-%m-%d %H:%M"` in
#'   Rome, oldest first; `character()` when there is none; `NA_character_`
#'   when the log cannot say.
#'
#' @keywords internal
report_executions <- function(events, record, channel_account = NULL) {
  stopifnot(is.data.frame(events))

  mine <- log_of_record(events, record)
  channel <- log_channel_accounts(events, record, channel_account)
  if (log_channel_unknown(channel, channel_account)) {
    return(NA_character_)
  }

  authors <- trimws(as.character(mine[["username"]]))
  sealed <- log_wrote(mine, "applied_seal") & authors %in% channel &
    nzchar(log_value(mine, "applied_seal"))
  stamps <- trimws(as.character(mine[["timestamp"]][sealed]))

  # A stamp that does not read as one cannot place the row in any month.
  if (!all(log_stamp_reads(stamps))) {
    return(NA_character_)
  }

  sort(stamps)
}


#' Since when the person a row names now has had its access
#'
#' The first execution by the channel after the newest write of `username` in
#' the row's current life. The row's first execution dates the request; this
#' dates the person. They differ when a modification changed `username`: the
#' row was activated for somebody, and the person it names now got the access
#' when the round executed it again. Dated by the row, that person would
#' count months of somebody else's.
#'
#' The newest write of `username` is read from the order of the answer,
#' newest first, like every other reading of the log here; the event that
#' writes it counts as after it, in case one event wrote both. Every
#' `username` write counts, the round's own included: the round writes back
#' the name it resolved, in the same pass and before the seal, so on a row
#' never modified the answer is its first execution.
#'
#' @inheritParams report_executions
#'
#' @return One stamp, `"%Y-%m-%d %H:%M"` in Rome; `character()` when the
#'   username has been written and not executed since; `NA_character_` when
#'   the log cannot say.
#'
#' @keywords internal
report_person_since <- function(events, record, channel_account = NULL) {
  stopifnot(is.data.frame(events))

  mine <- log_of_record(events, record)
  channel <- log_channel_accounts(events, record, channel_account)
  if (log_channel_unknown(channel, channel_account)) {
    return(NA_character_)
  }

  authors <- trimws(as.character(mine[["username"]]))
  sealed <- log_wrote(mine, "applied_seal") & authors %in% channel &
    nzchar(log_value(mine, "applied_seal"))
  moved <- which(log_wrote(mine, "username"))
  if (length(moved) > 0L) {
    sealed <- sealed & seq_len(nrow(mine)) <= moved[[1L]]
  }
  stamps <- trimws(as.character(mine[["timestamp"]][sealed]))

  if (!all(log_stamp_reads(stamps))) {
    return(NA_character_)
  }
  if (length(stamps) == 0L) {
    return(character())
  }
  sort(stamps)[[1L]]
}


#' When the row that stands now was made, from the creation log
#'
#' The same event `log_creators()` names the creator from: the creations
#' asked of REDCap with `logtype = "record_add"`, newest first, so that a
#' record id used twice answers with the life standing now.
#'
#' @param events The creation events, as `register_log()` returns them when
#'   asked with `logtype = "record_add"`.
#' @param records The record ids to answer about.
#'
#' @return A character vector as long as `records`, holding the stamp in the
#'   instance's civil time, `"%Y-%m-%d %H:%M"`, or `""` where no creation
#'   names that row or its stamp does not read as one.
#'
#' @keywords internal
report_born <- function(events, records) {
  stopifnot(is.data.frame(events))

  made <- trimws(as.character(events[["record"]]))
  said <- trimws(as.character(events[["action"]]))
  stamps <- trimws(as.character(events[["timestamp"]]))
  opened <- startsWith(said, "Create record")

  vapply(as.character(records), function(record) {
    hit <- which(made == record & opened)
    if (length(hit) == 0L) {
      return("")
    }
    stamp <- substr(stamps[[hit[[1L]]]], 1L, 16L)
    if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$", stamp)) {
      stamp
    } else {
      ""
    }
  }, character(1), USE.NAMES = FALSE)
}


#' Read a time as Microsoft Graph writes it
#'
#' @param value A string such as `"2026-10-08T09:12:33Z"`, or `""`.
#'
#' @return A `POSIXct` in UTC, `NA` when the value is absent or does not read.
#'
#' @keywords internal
report_graph_time <- function(value) {
  value <- trimws(as.character(value %||% ""))
  if (length(value) != 1L || is.na(value) || !nzchar(value)) {
    return(as.POSIXct(NA, tz = "UTC"))
  }
  as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
}


#' Find an account in the directory, and say whether it is usable
#'
#' Compared without regard to case or to spaces at the edges: a REDCap
#' username and a UPN name the same account in two systems that do not agree
#' on capitals.
#'
#' @param directory A directory frame, as `directory_users()` returns it.
#' @param upn The account's user principal name.
#'
#' @return A list with `stato`, one of `attivo`, `disabilitato`,
#'   `non_trovato` and `non_giudicabile`, and `riga`, the row of the account
#'   in `directory` or `NA`.
#'
#' @keywords internal
report_account <- function(directory, upn) {
  stopifnot(is.data.frame(directory))

  key <- tolower(trimws(as.character(upn %||% "")))
  if (length(key) != 1L || is.na(key) || !nzchar(key)) {
    return(list(stato = "non_trovato", riga = NA_integer_))
  }

  hit <- which(
    tolower(trimws(as.character(directory[["userPrincipalName"]]))) == key
  )
  if (length(hit) == 0L) {
    return(list(stato = "non_trovato", riga = NA_integer_))
  }
  # Entra keeps a UPN unique, so two hits are a sweep this package does not
  # understand, and an account it does not understand is not judged.
  if (length(hit) > 1L) {
    return(list(stato = "non_giudicabile", riga = NA_integer_))
  }

  enabled <- directory[["accountEnabled"]][[hit]]
  stato <- if (is.na(enabled)) {
    "non_giudicabile"
  } else if (isTRUE(enabled)) {
    "attivo"
  } else {
    "disabilitato"
  }
  list(stato = stato, riga = hit)
}


#' Whether a person has signed in to Entra, from the two dates of their key
#'
#' Entra says it with the permission the round already holds, and the report
#' uses it where the server cannot say it better: for the pairs of a server
#' that was not read, and for the deadline of a key that is still the one
#' of the creation. `lastPasswordChangeDateTime` is, in the words of Learn,
#' "the time when this Microsoft Entra user last changed their password or
#' when their password was created", and the round creates every account with
#' `forceChangePasswordNextSignIn`: an account whose key is as old as the
#' account itself is an account nobody has entered.
#'
#' What it cannot see, said where it is decided. A key reset by IT moves the
#' date without anybody signing in, and the person drops out of the verdict.
#' An account that existed long before the request has dates that diverge,
#' and the person never shows, even if they never opened the instance asked
#' for: the signal says "has used the UBEP account", not "has used REDCap".
#' That is why a server that was read decides in its place
#' (`report_server_access()`), and `report_assemble()` asks Entra only when
#' the server did not answer.
#'
#' @param directory A directory frame, as `directory_users()` returns it.
#' @param upn The person's user principal name.
#' @param tolerance Seconds, `report_tolerance()` unless a test says
#'   otherwise.
#'
#' @return One of `mai_entrata` and `entrata`, the two a referent is told
#'   about; or one of the four that go to IT: `disabilitato`, `non_trovato`,
#'   `senza_creazione` (no `createdDateTime`, which Learn says happens to some
#'   accounts created before June 2018) and `non_giudicabile`.
#'
#' @keywords internal
report_first_access <- function(directory, upn,
                                tolerance = report_tolerance()) {
  stopifnot(is.numeric(tolerance), length(tolerance) == 1L)

  account <- report_account(directory, upn)
  if (!identical(account[["stato"]], "attivo")) {
    return(account[["stato"]])
  }

  i <- account[["riga"]]
  created <- report_graph_time(directory[["createdDateTime"]][[i]])
  if (is.na(created)) {
    return("senza_creazione")
  }
  changed <- report_graph_time(directory[["lastPasswordChangeDateTime"]][[i]])
  if (is.na(changed)) {
    return("non_giudicabile")
  }

  apart <- abs(as.numeric(difftime(changed, created, units = "secs")))
  if (apart <= tolerance) "mai_entrata" else "entrata"
}


#' Whether an access is past its last day, on a given date
#'
#' REDCap refuses the pair when `expiration` is today or earlier, so the day
#' written is already over.
#'
#' @param expiration The register's `expiration`, `"%Y-%m-%d"` or empty.
#' @param today The date to judge on.
#'
#' @return A logical vector; an empty or unreadable date is not expired.
#'
#' @keywords internal
report_expired <- function(expiration, today) {
  date <- suppressWarnings(
    as.Date(trimws(as.character(expiration)), format = "%Y-%m-%d")
  )
  !is.na(date) & date <= today
}


#' The rows a month's report speaks about, with their owner and their date
#'
#' A row counts while it is an access: `request_status` is `active` and
#' `outcome` is `applied`. The filter is on the request and not on the
#' outcome alone, because a revocation the round carried out closes with
#' `applied` too; and any other outcome is not an access, and has had its own
#' mail already.
#'
#' Of those, a row activated after the month covered waits for the next
#' report, and every other one is kept. `nel_mese` says what the month did to
#' it: `attivata` when its first execution falls in the month, `modificata`
#' when it was executed again in the month after a change, `""` otherwise.
#'
#' A row whose log was read and does not date it is kept with `senza_data`:
#' it is applied and the log does not say since when, which is a question for
#' IT. `data_motivo` says which way: `senza_sigillo`, no seal written by the
#' channel; `log_ambiguo`, without the channel's account configured, the
#' channel's fields written by more than one account, so that which one
#' executed the row is unknown; `orario_illeggibile`, with the account
#' configured, a seal of the channel whose time does not read, the only way
#' an execution leaves the row undated then. They send IT to look for
#' different things. A row whose log could not be read is left out, since it
#' cannot be judged on a reading that did not happen; the caller sends
#' nothing on such a day.
#'
#' @param register The register as read.
#' @param creators Whom each row belongs to, in the register's order: its
#'   owner at the end of the month covered, as `provisioning_report()` reads
#'   it with `log_owner()`, which is the creator `log_creators()` names when
#'   the round never passed the row on; `""` when that is not established.
#'   The name and the `creator` column it fills predate the owner, and stay.
#' @param executions One element per row, in the register's order: what
#'   `report_executions()` answered, or `NULL` where the log was not read.
#' @param period What `report_month()` answered.
#' @param since One element per row, what `report_person_since()` answered,
#'   or `NULL` to date the person by the row's first execution.
#' @param born When each row was made, as `report_born()` answers, in the
#'   register's order; `NULL` when unknown.
#' @param channel_known Whether the channel's account was configured when
#'   `executions` were read: then no second account can blur the log.
#'
#' @return The kept rows of `register`, with `creator`, `attivata_il`,
#'   `nel_mese`, `senza_data`, `data_motivo`, `persona_dal` and `creata_il`
#'   added.
#'
#' @keywords internal
report_rows <- function(register, creators, executions, period,
                        since = NULL, born = NULL, channel_known = FALSE) {
  stopifnot(
    is.data.frame(register),
    is.character(creators), length(creators) == nrow(register),
    is.list(executions), length(executions) == nrow(register),
    is.list(period),
    is.null(since) || (is.list(since) && length(since) == nrow(register)),
    is.null(born) || (is.character(born) && length(born) == nrow(register)),
    is.logical(channel_known), length(channel_known) == 1L,
    !is.na(channel_known)
  )

  field <- function(name) {
    value <- register[[name]]
    if (is.null(value)) {
      return(rep("", nrow(register)))
    }
    value <- trimws(as.character(value))
    value[is.na(value)] <- ""
    value
  }

  month <- period[["mese"]]
  unread <- vapply(executions, is.null, logical(1))
  dated <- vapply(executions, function(stamps) {
    !is.null(stamps) && length(stamps) > 0L && !anyNA(stamps)
  }, logical(1))
  ambiguous <- vapply(executions, function(stamps) {
    !is.null(stamps) && anyNA(stamps)
  }, logical(1))
  stamps <- lapply(seq_along(executions), function(i) {
    if (dated[[i]]) sort(executions[[i]]) else character()
  })
  first <- vapply(stamps, function(s) if (length(s)) s[[1L]] else "", "")
  again <- vapply(stamps, function(s) {
    length(s) > 1L && any(substr(s[-1L], 1L, 7L) == month)
  }, logical(1))

  scope <- field("request_status") == "active" & field("outcome") == "applied"
  keep <- scope & !unread & (!dated | substr(first, 1L, 7L) <= month)

  news <- ifelse(
    dated & substr(first, 1L, 7L) == month, "attivata",
    ifelse(again, "modificata", "")
  )
  creators <- trimws(creators)
  creators[is.na(creators)] <- ""

  rows <- register[keep, , drop = FALSE]
  rows[["creator"]] <- creators[keep]
  rows[["attivata_il"]] <- first[keep]
  rows[["nel_mese"]] <- news[keep]
  rows[["senza_data"]] <- !dated[keep]
  unreadable <- if (channel_known) "orario_illeggibile" else "log_ambiguo"
  rows[["data_motivo"]] <- ifelse(
    dated, "", ifelse(ambiguous, unreadable, "senza_sigillo")
  )[keep]
  person <- if (is.null(since)) {
    first
  } else {
    vapply(since, function(stamps) {
      if (is.null(stamps) || length(stamps) == 0L || anyNA(stamps)) {
        ""
      } else {
        sort(stamps)[[1L]]
      }
    }, character(1))
  }
  rows[["persona_dal"]] <- person[keep]
  made <- if (is.null(born)) rep("", nrow(register)) else trimws(born)
  made[is.na(made)] <- ""
  rows[["creata_il"]] <- made[keep]
  rownames(rows) <- NULL
  rows
}


#' The rows stopped on a disabled account
#'
#' A row that is active and was stopped by the round because the account of its
#' person is disabled: `transport_error` with `TRASPORTO_ACCOUNT_DISATTIVATO`
#' among its codes. `outcome_detail` can carry more than one code, so the code
#' is looked for inside the field and not compared with it. These rows are not
#' in the report, but their people are among the names the report asks the
#' servers for, so that IT can see them.
#'
#' @param register The register, as `register_records()` answers.
#'
#' @return The rows of `register` that are active and stopped on a disabled
#'   account.
#'
#' @keywords internal
report_stopped_rows <- function(register) {
  stopifnot(is.data.frame(register))

  field <- function(name) {
    value <- register[[name]]
    if (is.null(value)) {
      return(rep("", nrow(register)))
    }
    value <- trimws(as.character(value))
    value[is.na(value)] <- ""
    value
  }

  stopped <- field("request_status") == "active" &
    field("outcome") == "transport_error" &
    grepl(
      "TRASPORTO_ACCOUNT_DISATTIVATO", field("outcome_detail"), fixed = TRUE
    )

  rows <- register[stopped, , drop = FALSE]
  rownames(rows) <- NULL
  rows
}


#' The names to ask each server
#'
#' For every server the register has rows on, the usernames of its active and
#' applied rows and of the rows stopped on a disabled account
#' (`report_stopped_rows()`). Blank servers and blank names are left out.
#'
#' @param register The register, as `register_records()` answers.
#'
#' @return A named list: server to the usernames to ask it, without
#'   repetitions.
#'
#' @keywords internal
report_server_asks <- function(register) {
  stopifnot(is.data.frame(register))

  field <- function(data, name) {
    value <- data[[name]]
    if (is.null(value)) {
      return(rep("", nrow(data)))
    }
    value <- trimws(as.character(value))
    value[is.na(value)] <- ""
    value
  }

  applied <- register[
    field(register, "request_status") == "active" &
      field(register, "outcome") == "applied", ,
    drop = FALSE
  ]
  stopped <- report_stopped_rows(register)
  server <- c(field(applied, "server"), field(stopped, "server"))
  username <- c(field(applied, "username"), field(stopped, "username"))
  keep <- nzchar(server) & nzchar(username)

  asks <- split(username[keep], factor(server[keep], unique(server[keep])))
  lapply(asks, unique)
}


#' Put each row in the report it belongs to
#'
#' A row belongs to **its owner**, as the log says, and not to
#' `requested_by`, which an import writes as it likes: the creator, or the
#' referent the round has since passed the row to by writing `owned_by`
#' (`log_owner()`). The column is still called `creator`, from before rows
#' could pass. The owner is the one standing at the end of the month covered,
#' which `provisioning_report()` settles before it gets here. The report goes
#' to the same person the round asks to approve a change. A person asked for
#' by two referents is in both reports, each with their own rows.
#'
#' Three items, of which the report fills two:
#'
#' - **activated in the month**, one line per request, new or modified. It is
#'   information, and does not count among the things to look at. A new one
#'   says whether its account was new: `account` is `nuovo` when Entra made
#'   the account no earlier than the minute the row was made (`creata_il`),
#'   `esistente` when earlier, `""` when either date is missing;
#' - **no first sign-in**, one item per person and server, with the projects
#'   of the person on that server: the requests of that person on that server
#'   activated at least `report_grace_days()` before the reading and not
#'   expired, when the person has never entered the server. The thirty days
#'   run from the later of two dates, in Italian time: the channel's first
#'   execution for the username the row names now (`report_person_since()`),
#'   and the birth of that account on Entra. A username corrected by a
#'   modification, or an account made again, is not dated by an activation
#'   that was somebody else's. The item carries the earliest of those dates
#'   among the requests on that server, how many days and months of thirty
#'   days ago it was, and the dates of the earlier reports of the same
#'   referent that named the person on that server (an earlier entry with an
#'   empty server, written before the server was recorded, names the person
#'   on every server). Who decides "never entered" depends on the server.
#'   One that was read decides (`report_server_access()`: no row, or no first
#'   visit), and Entra does not count, because the server says exactly which
#'   server and is not misled by a key IT has reset; `fonte` is `server`. One
#'   that was not read, for any reason, falls back on the rule of Entra
#'   (`report_first_access()`), and `fonte` is `entra`: the mail says so. The
#'   account's state is the first filter either way, and an account that is
#'   not active goes to IT once for the person. `limite` is the last day the
#'   first sign-in is promised (`mail_first_signin_deadline()`), but only when
#'   the two dates on Entra agree within `report_tolerance()`, that is when
#'   the key is still the one of the creation: otherwise the dates diverge
#'   for the person who entered, for a key reset and for the key the D-31
#'   rule replaced, and a date computed from them would be a guess, so it is
#'   `""`;
#' - **no access for more than a year**, one item per person and server. A
#'   pair is a candidate when its request is active, applied, not expired and
#'   the person has had the access on that server for more than 365 days
#'   (the oldest request there, as for the first sign-in). On a server that
#'   was read, it enters when the person has entered at least once and the
#'   last access (`report_server_access()`) is more than 365 days before the
#'   reading, both as dates in Italian time. It is listed in full the month it
#'   crosses the threshold, and counted in `senza_accessi_gia` after: when an
#'   earlier report of the same referent named it (an entry with an empty
#'   server names it on every server). On a server that was not read the pair
#'   is only counted, per server, in `non_controllati`: Entra says nothing
#'   about it, and an empty item would say "none" about something nobody
#'   measured.
#'
#' What has no referent to go to goes to IT, and to nobody else: a row whose
#' owner the log does not establish (no creation names it, or the log cannot
#' say whom it belongs to, `log_owner()`), or whose owner Entra holds
#' disabled, or does not hold, or cannot say; a person whose account is
#' disabled, missing, without a creation date or that cannot otherwise be
#' judged; a row the log does not date. A disabled owner receives nothing.
#'
#' A referent whose people went to IT without being judged is told how
#' many, in the report itself: the principle of the all-clear, which must not
#' cover an item nobody measured. `non_giudicati` counts them, a person once:
#' the people of that referent the report could not judge, and those of the
#' rows the log does not date.
#'
#' @param rows What `report_rows()` answered.
#' @param directory A directory frame, as `directory_users()` returns it.
#' @param period What `report_month()` answered.
#' @param previous The entries of the earlier months' ledgers, as
#'   `report_ledger_previous()` reads them.
#' @param unread The earlier months whose ledger did not read. A person who
#'   could have been in one of their reports gets `storia_nota` false, and
#'   the mail says nothing about earlier reports rather than something false.
#' @param servers What the readings of the servers answered, as
#'   `report_server_reads()` returns it: a named list, server to
#'   `list(letto = TRUE, conti = <frame>)` or `list(letto = FALSE, motivo)`.
#'   A server that is not there, or that says it was read without a frame of
#'   accounts, is a server that was not read.
#' @param stopped The rows stopped on a disabled account, as
#'   `report_stopped_rows()` answers, or `NULL` for none. They are not in the
#'   referents' reports: IT gets them.
#'
#' @return A list with `referenti`, one report per referent named after them,
#'   each a list of `referente`, `attivati` (rows), `scadenze` (the rows of
#'   the referent that expire after the day of the reading and by the last
#'   day of its month, by date, for information), `senza_primo_accesso`
#'   (pairs of person and server, with `nome`, `upn`, `server`, `progetti`,
#'   `attivata_il`, `giorni`, `mesi`, `segnalata`, `storia_nota`, `fonte` and
#'   `limite`), `senza_accessi` (pairs, with `nome`, `upn`, `server`,
#'   `progetti`, `ultimo`, the day of the last access in Italian time, and
#'   `attivata_il`), `senza_accessi_gia` (how many pairs an earlier report
#'   named and are still without access), `senza_accessi_gia_coppie` (those
#'   pairs, `upn` and `server`, for the ledger) and `non_controllati` (a frame
#'   of `server` and `coppie`), and `non_giudicati` (a count); `it`, `NULL`
#'   when there is
#'   nothing for IT, otherwise a list of `senza_referente` (rows, with
#'   `motivo`), `non_giudicabili` (people, with `referente` and `motivo`),
#'   `senza_data` (rows) and `server_non_letti` (a frame of `server`,
#'   `motivo`, `entra`, how many pairs of that server went into a
#'   referent's report on the strength of Entra, and `non_controllate`, how
#'   many were candidates for the year without access and could not be
#'   checked; one row for each server that was asked and not read, whether
#'   the rows on it are applied or stopped, also with none) and
#'   `disattivati` (the rows of `stopped`, with `entrata`: `"si"` or `"no"`,
#'   whether the person has entered the server, when it was read, `""` when
#'   it was not); and `senza_creatore`, how
#'   many rows have no referent to go to. Since rows can pass, that means
#'   without an established owner and not only without a creator; the name
#'   stays, because it is a column of `UbepRapporto_CL`, and a renamed
#'   column would keep the table's history under one name and the new
#'   records under another.
#'
#' @keywords internal
report_assemble <- function(rows, directory, period, previous = list(),
                            unread = character(), servers = list(),
                            stopped = NULL) {
  stopifnot(
    is.data.frame(rows), is.data.frame(directory), is.list(period),
    is.list(previous), is.character(unread), is.list(servers),
    is.null(stopped) || is.data.frame(stopped)
  )

  text <- function(name) {
    value <- rows[[name]]
    if (is.null(value)) {
      return(rep("", nrow(rows)))
    }
    value <- trimws(as.character(value))
    value[is.na(value)] <- ""
    value
  }

  today <- period[["oggi"]]
  creator <- text("creator")
  activated <- text("attivata_il")
  username <- text("username")
  undated <- as.logical(rows[["senza_data"]] %||% logical(nrow(rows)))

  state <- vapply(creator, function(who) {
    if (!nzchar(who)) {
      return("non_stabilito")
    }
    report_account(directory, who)[["stato"]]
  }, character(1), USE.NAMES = FALSE)
  orphan <- !undated & state != "attivo"
  own <- !undated & state == "attivo"

  # Since when the person the row names now has had the access: the channel's
  # first execution for that username, and not before the account existed.
  # A username changed by a modification, or an account made again, would
  # otherwise be dated by somebody else's activation.
  since <- if (is.null(rows[["persona_dal"]])) {
    activated
  } else {
    text("persona_dal")
  }
  account_born <- vapply(username, function(upn) {
    account <- report_account(directory, upn)
    if (is.na(account[["riga"]])) {
      return("")
    }
    moment <- report_graph_time(
      directory[["createdDateTime"]][[account[["riga"]]]]
    )
    if (is.na(moment)) {
      return("")
    }
    format(moment, "%Y-%m-%d %H:%M", tz = "Europe/Rome")
  }, character(1), USE.NAMES = FALSE)
  start <- ifelse(nzchar(since), pmax(since, account_born), "")

  # Whether the account was new for this request: Entra made it no earlier
  # than the minute the row was made. Not `identity`, which the round turns
  # from `created` to `existing` one round after the creation (measured in
  # production on 2026-10-16), so it would call every account the channel
  # made an old one. Both stamps in Italian time, to the minute, since that
  # is what the log carries; either missing, nothing is said.
  made <- text("creata_il")
  account <- ifelse(
    nzchar(account_born) & nzchar(made),
    ifelse(account_born >= made, "nuovo", "esistente"),
    ""
  )

  days <- rep(NA_integer_, nrow(rows))
  dated <- nzchar(start)
  days[dated] <- as.integer(today - as.Date(substr(start[dated], 1L, 10L)))
  judged <- own & !report_expired(text("expiration"), today) &
    !is.na(days) & days >= report_grace_days()

  # The expirations of the month, for information: after the day of the
  # reading, which is already expired, and up to the last day of its month.
  expires <- suppressWarnings(
    as.Date(text("expiration"), format = "%Y-%m-%d")
  )
  month_end <- as.Date(
    paste0(report_shift_month(format(today, "%Y-%m"), 1L), "-01")
  ) - 1L
  expiring <- !is.na(expires) & expires > today & expires <= month_end

  projects <- function(at) {
    found <- unique(data.frame(
      server = text("server")[at], project_id = text("project_id")[at],
      stringsAsFactors = FALSE
    ))
    number <- suppressWarnings(as.numeric(found[["project_id"]]))
    found <- found[
      order(found[["server"]], number, found[["project_id"]]), ,
      drop = FALSE
    ]
    rownames(found) <- NULL
    found
  }

  # The earlier reports of this referent that named the person on this
  # server, in the list asked for (`senza_primo_accesso` or
  # `senza_accessi`). The pairs of a report that recorded only the person
  # carry an empty server, "all of them".
  reported <- function(who, key, server, of = "senza_primo_accesso") {
    dates <- unlist(lapply(previous, function(entry) {
      same <- identical(
        tolower(trimws(as.character(entry[["destinatario"]] %||% ""))),
        tolower(who)
      )
      pairs <- report_pairs(entry[[of]])
      named <- any(
        tolower(trimws(pairs[["upn"]])) == key &
          trimws(pairs[["server"]]) %in% c(server, "")
      )
      if (same && named) substr(as.character(entry[["at"]]), 1L, 10L)
    }))
    sort(unique(as.character(dates)))
  }

  # What a server says about its people, or why it says nothing. It decides
  # only when it was read whole: the flag and the frame of its accounts. A
  # server the caller did not mention was not asked, which is the same as a
  # module that is not there.
  reading <- function(server) {
    found <- servers[[server]]
    if (is.list(found) && isTRUE(found[["letto"]]) &&
          is.data.frame(found[["conti"]])) {
      return(list(letto = TRUE, conti = found[["conti"]]))
    }
    reason <- if (is.null(found)) {
      "TRASPORTO_ISTANZA_SENZA_MODULO"
    } else {
      found <- found[["motivo"]]
      if (is.character(found) && length(found) == 1L && !is.na(found) &&
            nzchar(found)) {
        found
      } else {
        "INTERNO"
      }
    }
    list(letto = FALSE, motivo = reason)
  }

  # A month's reports leave during the month after, so a person dated before
  # the first day of the month after that could be in them.
  unknown_until <- if (length(unread) > 0L) {
    max(as.Date(paste0(
      vapply(unread, report_shift_month, "", by = 2L), "-01"
    )))
  }

  referenti <- list()
  non_giudicabili <- list()

  for (who in unique(creator[own])) {
    mine <- own & creator == who

    attivati <- rows[mine & nzchar(text("nel_mese")), , drop = FALSE]
    attivati[["account"]] <- account[mine & nzchar(text("nel_mese"))]
    attivati <- attivati[
      order(attivati[["attivata_il"]], attivati[["record_id"]]), ,
      drop = FALSE
    ]
    rownames(attivati) <- NULL

    soon <- rows[mine & expiring, , drop = FALSE]
    soon <- soon[
      order(as.Date(soon[["expiration"]]), soon[["record_id"]]), ,
      drop = FALSE
    ]
    rownames(soon) <- NULL

    people <- list()
    idle <- list()
    idle_before <- report_pairs()
    unchecked <- character()
    candidates <- which(mine & judged)
    keys <- tolower(username[candidates])
    for (key in unique(keys)) {
      of_person <- candidates[keys == key]
      of_person <- of_person[order(start[of_person])]
      oldest <- of_person[[1L]]
      name <- trimws(paste(
        text("first_name")[[oldest]], text("last_name")[[oldest]]
      ))

      # The account's state is the first filter, whatever the server says:
      # nobody is judged on an account Entra holds disabled or cannot read.
      entry <- report_account(directory, username[[oldest]])
      if (!identical(entry[["stato"]], "attivo")) {
        non_giudicabili[[length(non_giudicabili) + 1L]] <- list(
          nome = name, upn = username[[oldest]],
          progetti = projects(of_person),
          referente = who, motivo = entry[["stato"]]
        )
        next
      }

      # Entra's verdict is the same for every server of the person, and is
      # what a server that was not read falls back on.
      verdict <- report_first_access(directory, username[[oldest]])
      limit <- ""
      if (identical(verdict, "mai_entrata")) {
        limit <- mail_first_signin_deadline(
          directory[["createdDateTime"]][[entry[["riga"]]]]
        )
        if (is.na(limit)) {
          limit <- ""
        }
      }

      unjudged <- integer()
      for (server in sort(unique(text("server")[of_person]))) {
        at <- of_person[text("server")[of_person] == server]
        first <- at[[1L]]
        seen <- reading(server)

        # The year without access: a pair active for more than a year, on
        # a server that says when the person last entered. A server that
        # was not read says nothing, and the pair is counted as unchecked.
        if (days[[first]] > 365L) {
          if (!isTRUE(seen[["letto"]])) {
            unchecked <- c(unchecked, server)
          } else {
            access <- report_server_access(
              seen[["conti"]], username[[first]]
            )
            last <- if (identical(access[["stato"]], "entrata")) {
              format(access[["ultimo"]], "%Y-%m-%d", tz = "Europe/Rome")
            }
            if (!is.null(last) &&
                  as.integer(today - as.Date(last)) > 365L) {
              if (length(reported(who, key, server, "senza_accessi")) > 0L) {
                idle_before <- rbind(idle_before, report_pairs(
                  data.frame(
                    upn = username[[first]], server = server,
                    stringsAsFactors = FALSE
                  )
                ))
              } else {
                idle[[length(idle) + 1L]] <- list(
                  nome = name,
                  upn = username[[first]],
                  server = server,
                  progetti = projects(at),
                  ultimo = last,
                  attivata_il = substr(start[[first]], 1L, 10L)
                )
              }
            }
          }
        }

        if (isTRUE(seen[["letto"]])) {
          never <- identical(
            report_server_access(seen[["conti"]], username[[first]])[["stato"]],
            "mai_entrata"
          )
        } else {
          never <- identical(verdict, "mai_entrata")
          if (!never && !identical(verdict, "entrata")) {
            unjudged <- c(unjudged, at)
          }
        }
        if (!never) {
          next
        }

        people[[length(people) + 1L]] <- list(
          nome = name,
          upn = username[[first]],
          server = server,
          progetti = projects(at),
          attivata_il = substr(start[[first]], 1L, 10L),
          giorni = days[[first]],
          mesi = days[[first]] %/% 30L,
          segnalata = reported(who, key, server),
          storia_nota = is.null(unknown_until) ||
            as.Date(substr(start[[first]], 1L, 10L)) >= unknown_until,
          fonte = if (isTRUE(seen[["letto"]])) "server" else "entra",
          limite = limit
        )
      }

      if (length(unjudged) > 0L) {
        non_giudicabili[[length(non_giudicabili) + 1L]] <- list(
          nome = name, upn = username[[oldest]],
          progetti = projects(unjudged),
          referente = who, motivo = verdict
        )
      }
    }

    silent <- sort(unique(unchecked))
    referenti[[who]] <- list(
      referente = who, attivati = attivati, senza_primo_accesso = people,
      scadenze = soon, senza_accessi = idle,
      senza_accessi_gia = nrow(idle_before),
      senza_accessi_gia_coppie = idle_before,
      non_controllati = data.frame(
        server = silent,
        coppie = vapply(silent, function(s) sum(unchecked == s), 0L,
                        USE.NAMES = FALSE),
        stringsAsFactors = FALSE
      )
    )
  }

  for (who in names(referenti)) {
    mine <- Filter(
      function(person) identical(person[["referente"]], who), non_giudicabili
    )
    unjudged <- c(
      tolower(vapply(mine, `[[`, "", "upn")),
      tolower(username[undated & creator == who])
    )
    referenti[[who]][["non_giudicati"]] <- length(unique(unjudged))
  }

  senza_referente <- rows[orphan, , drop = FALSE]
  senza_referente[["motivo"]] <- state[orphan]
  rownames(senza_referente) <- NULL
  senza_data <- rows[undated, , drop = FALSE]
  rownames(senza_data) <- NULL

  # The servers of the rows that were not read, with the pairs of each that
  # went into a referent's report on what Entra says: those are the ones a
  # server could have refuted.
  on_entra <- unlist(lapply(referenti, function(report) {
    found <- Filter(
      function(person) identical(person[["fonte"]], "entra"),
      report[["senza_primo_accesso"]]
    )
    vapply(found, `[[`, "", "server")
  }))
  # Every server the report asked and did not read, whoever the rows are: the
  # applied ones, the stopped ones, or only the readings that were made.
  stopped_servers <- trimws(as.character(stopped[["server"]]))
  asked <- c(names(servers), text("server"), stopped_servers)
  asked <- sort(unique(asked[!is.na(asked) & nzchar(asked)]))
  asked <- asked[!vapply(
    asked, function(server) isTRUE(reading(server)[["letto"]]), logical(1)
  )]
  server_non_letti <- data.frame(
    server = asked,
    motivo = vapply(
      asked, function(server) reading(server)[["motivo"]], "",
      USE.NAMES = FALSE
    ),
    entra = vapply(
      asked, function(server) sum(on_entra == server), 0L,
      USE.NAMES = FALSE
    ),
    non_controllate = vapply(asked, function(server) {
      as.integer(sum(unlist(lapply(referenti, function(report) {
        found <- report[["non_controllati"]]
        found[["coppie"]][found[["server"]] == server]
      }))))
    }, 0L, USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )

  # The rows stopped on a disabled account, with whether the person has ever
  # entered the server of the row: said only by a server that was read.
  disattivati <- stopped %||% data.frame()
  rownames(disattivati) <- NULL
  disattivati[["entrata"]] <- vapply(seq_len(nrow(disattivati)), function(i) {
    seen <- reading(trimws(as.character(disattivati[["server"]][[i]])))
    if (!isTRUE(seen[["letto"]])) {
      return("")
    }
    access <- report_server_access(
      seen[["conti"]], as.character(disattivati[["username"]][[i]])
    )
    if (identical(access[["stato"]], "entrata")) "si" else "no"
  }, "")

  for_it <- nrow(senza_referente) + length(non_giudicabili) +
    nrow(senza_data) + nrow(server_non_letti) + nrow(disattivati)
  it <- if (for_it > 0L) {
    list(
      senza_referente = senza_referente,
      non_giudicabili = non_giudicabili,
      senza_data = senza_data,
      server_non_letti = server_non_letti,
      disattivati = disattivati
    )
  }

  list(
    referenti = referenti, it = it, senza_creatore = nrow(senza_referente)
  )
}


#' Join words the way a sentence lists them
#'
#' @param words A character vector.
#' @param conjunction The word before the last item, `"e"` or `"and"`.
#'
#' @return One string: `"a"`, `"a e b"`, `"a, b e c"`.
#'
#' @keywords internal
report_join <- function(words, conjunction) {
  words <- as.character(words)
  if (length(words) <= 1L) {
    return(paste(words, collapse = ""))
  }
  paste(
    paste(words[-length(words)], collapse = ", "), conjunction,
    words[[length(words)]]
  )
}


#' Say the projects of a person, instance by instance
#'
#' @param projects A frame of `server` and `project_id`, as
#'   `report_assemble()` builds it.
#'
#' @return A character vector named `it` and `en`, as in
#'   `"edc10, progetti 9301 e 9302; edc12, progetto 9303"`.
#'
#' @keywords internal
report_projects_words <- function(projects) {
  servers <- unique(as.character(projects[["server"]]))
  said <- lapply(servers, function(server) {
    ids <- as.character(
      projects[["project_id"]][projects[["server"]] == server]
    )
    many <- length(ids) > 1L
    c(
      it = paste0(
        server, ", ", if (many) "progetti " else "progetto ",
        report_join(ids, "e")
      ),
      en = paste0(
        server, ", ", if (many) "projects " else "project ",
        report_join(ids, "and")
      )
    )
  })
  c(
    it = paste(vapply(said, `[[`, "", "it"), collapse = "; "),
    en = paste(vapply(said, `[[`, "", "en"), collapse = "; ")
  )
}


#' The lines of the accesses activated in the month, in both languages
#'
#' A new request says whether its account was new, from the `account` column
#' `report_assemble()` computes on the date Entra made the account; a
#' modified one says it was modified.
#'
#' @param rows The `attivati` of a referent's report.
#'
#' @return A list of two character vectors, `it` and `en`.
#'
#' @keywords internal
report_activated_lines <- function(rows) {
  count <- nrow(rows)
  if (count == 0L) {
    return(list(
      it = "Accessi attivati nel mese: nessuno.",
      en = "Access granted this month: none."
    ))
  }

  value <- function(name) {
    found <- rows[[name]]
    if (is.null(found)) {
      return(rep("", count))
    }
    found <- trimws(as.character(found))
    found[is.na(found)] <- ""
    found
  }

  name <- trimws(paste(value("first_name"), value("last_name")))
  dag <- value("dag_name")
  expiration <- value("expiration")
  modified <- value("nel_mese") == "modificata"
  account <- value("account")

  line <- function(project, role, group, until, none, tail) {
    paste0(
      "- ", name, ", ", value("username"), ": ", value("server"), ", ",
      project, " ", value("project_id"), ", ", role, " ", value("role_name"),
      ifelse(nzchar(dag), paste0(", ", group, " ", dag), ""), ", ",
      ifelse(nzchar(expiration), paste(until, expiration), none), ".",
      ifelse(nzchar(tail), paste0(" ", tail), "")
    )
  }

  tail_it <- ifelse(
    modified, "Richiesta modificata e rieseguita nel mese.",
    ifelse(account == "nuovo", "Account nuovo.",
           ifelse(account == "esistente", "Account gia' esistente.", ""))
  )
  tail_en <- ifelse(
    modified, "Request modified and applied again this month.",
    ifelse(account == "nuovo", "New account.",
           ifelse(account == "esistente", "Existing account.", ""))
  )

  list(
    it = c(
      paste0("Accessi attivati nel mese (", count, "), per informazione:"),
      line("progetto", "ruolo", "DAG", "scadenza", "senza scadenza", tail_it),
      paste(
        "Non serve fare niente.",
        if (count == 1L) {
          "Se non e' cio' che avevi chiesto,"
        } else {
          "Se uno di questi non e' cio' che avevi chiesto,"
        },
        "metti la richiesta a revoked nel registro."
      )
    ),
    en = c(
      paste0("Access granted this month (", count, "), for information:"),
      line("project", "role", "DAG", "last day", "no end date", tail_en),
      paste(
        "Nothing to do.",
        if (count == 1L) {
          "If it is not what you asked for,"
        } else {
          "If one of these is not what you asked for,"
        },
        "set the request to revoked in the register."
      )
    )
  )
}


#' The lines of the people with no first sign-in, in both languages
#'
#' One entry for each person and server. After the line with the person and
#' the date and the line with the server's projects, an entry says what the
#' referent should know of the account: with a `limite`, that the person has
#' never signed in with the UBEP account and must by that day, the last one,
#' or the account is deactivated (D-31); when that day is already past, that
#' the key handed over may no longer be valid and that a new one is asked for
#' by replying to the mail of the key, which is what the D-31 rule has for an
#' expired key; without a `limite`, only that the person never entered the
#' server, since the dates on Entra no longer tell whether they use the
#' account. An entry read from Entra, because the server did not answer, says
#' so. Without people, the item says "none".
#'
#' @param people The `senza_primo_accesso` of a referent's report.
#' @param period What `report_month()` answered: `oggi` tells whether a
#'   `limite` is past.
#' @param to_it How many of the referent's people went to IT without being
#'   judged.
#'
#' @return A list of two character vectors, `it` and `en`.
#'
#' @keywords internal
report_people_lines <- function(people, period, to_it = 0L) {
  stopifnot(is.list(period))

  grace <- report_grace_days()

  if (length(people) == 0L) {
    return(list(
      it = c(
        paste0("1. Senza primo accesso al server dopo ", grace,
               " giorni: nessuna."),
        if (to_it > 0L) {
          paste0("Persone non giudicabili, segnalate a IT: ", to_it, ".")
        }
      ),
      en = c(
        paste0("1. No first sign-in on the server after ", grace,
               " days: none."),
        if (to_it > 0L) {
          paste0(
            "People that could not be judged, reported to IT: ", to_it, "."
          )
        }
      )
    ))
  }

  today <- format(period[["oggi"]], "%Y-%m-%d")

  each <- lapply(people, function(person) {
    projects <- report_projects_words(person[["progetti"]])
    months <- as.integer(person[["mesi"]])
    earlier <- as.character(person[["segnalata"]] %||% character())
    # A ledger that did not read may hold this person: neither "first" nor
    # "also on" can be said.
    known <- !isFALSE(person[["storia_nota"]])
    who <- paste0("   - ", person[["nome"]], ", ", person[["upn"]], ": ")
    server <- person[["server"]]
    limit <- as.character(person[["limite"]] %||% "")
    from_entra <- identical(person[["fonte"]], "entra")
    past <- nzchar(limit) && limit < today
    list(
      it = c(
        paste0(
          who, "attivata il ", person[["attivata_il"]], ", ",
          person[["giorni"]], " giorni fa; senza primo accesso da ", months,
          if (months == 1L) " mese." else " mesi."
        ),
        paste0(
          "     ", projects[["it"]], ".",
          if (!known) {
            ""
          } else if (length(earlier) == 0L) {
            " Prima segnalazione."
          } else {
            paste0(
              " Segnalata anche ", report_join(paste("il", earlier), "e"), "."
            )
          }
        ),
        if (past) {
          paste0(
            "     Non e' mai entrata con l'account UBEP: la data per il ",
            "primo accesso (", limit, ") e' passata e la chiave consegnata ",
            "puo' non valere piu'. Per averne una nuova, rispondi alla mail ",
            "della chiave."
          )
        } else if (nzchar(limit)) {
          paste0(
            "     Non e' mai entrata con l'account UBEP: deve entrare entro ",
            "il ", limit, ", poi l'account viene disattivato (D-31)."
          )
        } else {
          paste0("     Su ", server, " non e' mai entrata.")
        },
        if (from_entra) {
          "     Letto da Entra: il server non ha risposto."
        }
      ),
      en = c(
        paste0(
          who, "activated on ", person[["attivata_il"]], ", ",
          person[["giorni"]], " days ago; no first sign-in for ", months,
          if (months == 1L) " month." else " months."
        ),
        paste0(
          "     ", projects[["en"]], ".",
          if (!known) {
            ""
          } else if (length(earlier) == 0L) {
            " First report."
          } else {
            paste0(" Also reported on ", report_join(earlier, "and"), ".")
          }
        ),
        if (past) {
          paste0(
            "     Has never signed in with the UBEP account: the date for ",
            "the first sign-in (", limit, ") has passed and the key that was ",
            "handed over may no longer be valid. To get a new one, reply to ",
            "the mail of the key."
          )
        } else if (nzchar(limit)) {
          paste0(
            "     Has never signed in with the UBEP account: must sign in ",
            "by ", limit, ", then the account is deactivated (D-31)."
          )
        } else {
          paste0("     Has never signed in on ", server, ".")
        },
        if (from_entra) {
          "     Read from Entra: the server did not answer."
        }
      )
    )
  })

  list(
    it = c(
      paste0(
        "1. Senza primo accesso al server dopo ", grace, " giorni (",
        length(people), ")"
      ),
      paste0(
        "   Hanno l'accesso a un server da almeno ", grace, " giorni e su ",
        "quel server non sono ancora entrate."
      ),
      unlist(lapply(each, `[[`, "it")),
      if (to_it > 0L) {
        paste0("   Persone non giudicabili, segnalate a IT: ", to_it, ".")
      },
      paste0(
        "   Che cosa fare: chiedi alla persona se ha ricevuto il benvenuto e ",
        "la chiave che le hai mandato, e di entrare nel server indicato. Se ",
        "la chiave e' persa, scrivi a IT: la reimposta e la rimanda a te. Se ",
        "l'accesso a quel server non serve piu', metti la richiesta a revoked."
      )
    ),
    en = c(
      paste0(
        "1. No first sign-in on the server after ", grace, " days (",
        length(people), ")"
      ),
      paste0(
        "   They have had access to a server for at least ", grace, " days ",
        "and have not signed in on that server yet."
      ),
      unlist(lapply(each, `[[`, "en")),
      if (to_it > 0L) {
        paste0(
          "   People that could not be judged, reported to IT: ", to_it, "."
        )
      },
      paste0(
        "   What to do: ask the person whether they received the welcome and ",
        "the key you sent them, and to sign in on the server named. If the ",
        "key is lost, write to IT: they reset it and send it back to you. If ",
        "the access to that server is no longer needed, set the request to ",
        "revoked."
      )
    )
  )
}


#' The lines of the people with no access for more than a year, in both
#' languages
#'
#' One entry for each person and server that crossed the threshold this
#' month, with the project of the person on that server, when the server
#' last saw them and since when they have had the access. The pairs named
#' in an earlier report of the same referent and still without access are
#' counted in a line of their own, not listed again. The pairs on a server
#' that did not answer are counted per server and said not to be checked: an
#' item that covered a server nobody read would say "none" about something
#' nobody measured, so "none" is only said when there is nothing else to say.
#'
#' @param report One referent's report, as `report_assemble()` builds it:
#'   `senza_accessi` (the pairs listed in full), `senza_accessi_gia` (how
#'   many were named before) and `non_controllati` (a frame of `server` and
#'   `coppie`).
#'
#' @return A list of two character vectors, `it` and `en`.
#'
#' @keywords internal
report_idle_lines <- function(report) {
  pairs <- report[["senza_accessi"]] %||% list()
  earlier <- as.integer(report[["senza_accessi_gia"]] %||% 0L)
  unchecked <- report[["non_controllati"]]
  if (is.null(unchecked)) {
    unchecked <- data.frame(
      server = character(), coppie = integer(), stringsAsFactors = FALSE
    )
  }

  if (length(pairs) == 0L && earlier == 0L && nrow(unchecked) == 0L) {
    return(list(
      it = "2. Senza accessi da piu' di un anno: nessuno.",
      en = "2. No access in more than a year: none."
    ))
  }

  each <- lapply(pairs, function(pair) {
    projects <- report_projects_words(pair[["progetti"]])
    who <- paste0("   - ", pair[["nome"]], ", ", pair[["upn"]], ": ")
    list(
      it = c(
        paste0(
          who, "attivata il ", pair[["attivata_il"]], "; ultimo accesso il ",
          pair[["ultimo"]], "."
        ),
        paste0("     ", projects[["it"]], ".")
      ),
      en = c(
        paste0(
          who, "activated on ", pair[["attivata_il"]], "; last access on ",
          pair[["ultimo"]], "."
        ),
        paste0("     ", projects[["en"]], ".")
      )
    )
  })

  count <- as.integer(unchecked[["coppie"]])
  server <- as.character(unchecked[["server"]])

  list(
    it = c(
      paste0("2. Senza accessi da piu' di un anno (", length(pairs), ")"),
      if (length(pairs) > 0L) {
        paste0(
          "   Hanno l'accesso da piu' di un anno e su quel server non ",
          "entrano da piu' di un anno."
        )
      },
      unlist(lapply(each, `[[`, "it")),
      if (earlier > 0L) {
        paste0(
          "   Gia' segnalate nei mesi scorsi e ancora senza accessi: ",
          earlier, "."
        )
      },
      if (nrow(unchecked) > 0L) {
        paste0(
          "   Non controllato per ", count,
          ifelse(count == 1L, " persona su ", " persone su "),
          server, ": il server non ha risposto."
        )
      },
      if (length(pairs) > 0L) {
        paste0(
          "   Che cosa fare: se la persona non lavora piu' su quei ",
          "progetti, metti le richieste a revoked. Se deve restare, non ",
          "serve niente: dal mese prossimo sara' solo contata."
        )
      }
    ),
    en = c(
      paste0("2. No access in more than a year (", length(pairs), ")"),
      if (length(pairs) > 0L) {
        paste0(
          "   They have had access for more than a year and have not ",
          "signed in on that server for more than a year."
        )
      },
      unlist(lapply(each, `[[`, "en")),
      if (earlier > 0L) {
        paste0(
          "   Already reported in earlier months and still without ",
          "access: ", earlier, "."
        )
      },
      if (nrow(unchecked) > 0L) {
        paste0(
          "   Not checked for ", count,
          ifelse(count == 1L, " person on ", " people on "),
          server, ": the server did not answer."
        )
      },
      if (length(pairs) > 0L) {
        paste0(
          "   What to do: if the person no longer works on those projects, ",
          "set the requests to revoked. If they must stay, nothing is ",
          "needed: from next month they will only be counted."
        )
      }
    )
  )
}


#' The lines of the accesses that expire this month, in both languages
#'
#' Information only: it is not an item to look at, and it does not count in
#' the number of the subject. Each expiration is one line with the person,
#' the server, the project and the day, as in the approved draft (`Name:
#' server, progetto N, scade il AAAA-MM-GG.`). Without any, no lines at all,
#' since "none" would be a claim and the item is only a reminder.
#'
#' @param rows The `scadenze` of a referent's report.
#' @param period What `report_month()` answered: the month named is the one
#'   of the reading.
#'
#' @return A list of two character vectors, `it` and `en`; empty without
#'   rows.
#'
#' @keywords internal
report_expiring_lines <- function(rows, period) {
  stopifnot(is.data.frame(rows), is.list(period))

  if (nrow(rows) == 0L) {
    return(list(it = character(), en = character()))
  }

  month <- report_month_words(format(period[["oggi"]], "%Y-%m"))
  each <- function(project, verb) {
    vapply(seq_len(nrow(rows)), function(i) {
      paste0(
        "   - ", trimws(paste(rows[["first_name"]][[i]],
                              rows[["last_name"]][[i]])),
        ": ", rows[["server"]][[i]], ", ", project, " ",
        rows[["project_id"]][[i]], ", ", verb, " ",
        trimws(rows[["expiration"]][[i]]), "."
      )
    }, "")
  }

  list(
    it = c(
      paste0(
        "3. Scadono entro ", sub(" .*", "", month[["it"]]), " (", nrow(rows),
        "), per informazione"
      ),
      each("progetto", "scade il")
    ),
    en = c(
      paste0(
        "3. Expiring by the end of ", sub(" .*", "", month[["en"]]), " (",
        nrow(rows), "), for information"
      ),
      each("project", "expires on")
    )
  )
}


#' Say when the state was read, in both languages
#'
#' @inheritParams report_message
#'
#' @return A list of two strings, `it` and `en`, without the next report.
#'
#' @keywords internal
report_read_words <- function(period) {
  day <- substr(period[["letto"]], 1L, 10L)
  hour <- substr(period[["letto"]], 12L, 16L)
  list(
    it = paste0(
      "Situazione letta il ", day, " alle ", hour, " (ora italiana)."
    ),
    en = paste0("State read on ", day, " at ", hour, " (Italian time).")
  )
}


#' Compose a referent's monthly report
#'
#' Two forms, told apart by the **first word of the subject**, which is what
#' shows in a list of mail without opening anything: `Tutto in ordine: ...`
#' when there is nobody to look at, `Da guardare (N): ...` otherwise, with N
#' in brackets so that the subject does not carry two colons in a row. The
#' mail is plain text, so the verdict is said again on the first line of the
#' body, in capitals (`TUTTO IN ORDINE`, `DA GUARDARE: N`; `ALL CLEAR`,
#' `TO REVIEW: N`): a number right before a numbered list would read as the
#' number of its first item. N counts the people listed in full in the items
#' to look at, a person once even when they are on two servers or in both
#' items (the user name compared without case), and not the accesses
#' activated or the expirations, which are information.
#'
#' The items come in the order of the draft: 1. no first sign-in on the
#' server, 2. no access in more than a year, 3. the expirations of the month
#' (only if there are any), then the accesses activated. In the all-clear
#' form items 1 and 2 say "none" with their number. The people of the
#' referent that went to IT without being judged are counted in a line of
#' their own, which changes neither the verdict nor the number in the
#' subject: those say what was measured.
#'
#' Italian above and English below, as every mail of the channel, since the
#' address says nothing about which one its reader reads.
#'
#' @param report One referent's report, as `report_assemble()` builds it.
#' @param period What `report_month()` answered.
#'
#' @return A list with `subject`, `body`, `forma` (`in_ordine` or
#'   `da_guardare`) and `n`.
#'
#' @keywords internal
report_message <- function(report, period) {
  stopifnot(is.list(report), is.list(period))

  people <- report[["senza_primo_accesso"]] %||% list()
  idle <- report[["senza_accessi"]] %||% list()
  named <- vapply(c(people, idle), function(x) {
    tolower(trimws(as.character(x[["upn"]])))
  }, "")
  count <- length(unique(named))
  unjudged <- as.integer(report[["non_giudicati"]] %||% 0L)
  month <- report_month_words(period[["mese"]])
  following <- report_day_words(period[["prossimo"]])
  first <- report_people_lines(people, period, unjudged)
  second <- report_idle_lines(report)
  expiring <- report_expiring_lines(
    report[["scadenze"]] %||% data.frame(), period
  )
  activated <- report_activated_lines(report[["attivati"]])
  read <- report_read_words(period)

  if (count == 0L) {
    verdict <- c(
      it = "TUTTO IN ORDINE", en = "ALL CLEAR",
      subject_it = "Tutto in ordine", subject_en = "All clear"
    )
  } else {
    verdict <- c(
      it = paste0("DA GUARDARE: ", count), en = paste0("TO REVIEW: ", count),
      subject_it = paste0("Da guardare (", count, ")"),
      subject_en = paste0("To review (", count, ")")
    )
  }

  # The items are apart by a blank line; the expirations only if there are.
  items <- function(language) {
    parts <- list(first[[language]], second[[language]])
    if (length(expiring[[language]]) > 0L) {
      parts <- c(parts, list(expiring[[language]]))
    }
    unlist(lapply(seq_along(parts), function(i) {
      c(if (i > 1L) "", parts[[i]])
    }))
  }

  it <- c(
    verdict[["it"]],
    "",
    paste0(
      "Rapporto mensile sulle richieste di accesso a REDCap di cui sei ",
      "referente. ",
      "Mese: ", month[["it"]], "."
    ),
    "",
    items("it"),
    "",
    activated[["it"]],
    "",
    paste0(read[["it"]], " Prossimo rapporto: ", following[["it"]], "."),
    "Per domande rispondi a questo messaggio: la risposta arriva a IT."
  )

  en <- c(
    verdict[["en"]],
    "",
    paste0(
      "Monthly report on the REDCap access requests you are the referent ",
      "of. ",
      "Month: ", month[["en"]], "."
    ),
    "",
    items("en"),
    "",
    activated[["en"]],
    "",
    paste0(read[["en"]], " Next report: ", following[["en"]], "."),
    "For questions, reply to this message: the reply reaches IT."
  )

  list(
    subject = paste0(
      verdict[["subject_it"]], ": accessi REDCap, ", month[["it"]], " / ",
      verdict[["subject_en"]], ": REDCap access, ", month[["en"]]
    ),
    body = paste(c(it, "", "---", "", en), collapse = "\n"),
    forma = if (count == 0L) "in_ordine" else "da_guardare",
    n = count
  )
}


#' Compose the monthly mail to IT
#'
#' One mail, and only when there is something in it. Five sections, numbered
#' in this order: the rows with no referent to send them to, the people the
#' report cannot judge, the rows the log does not date, the servers that were
#' not read (with the reason, and how many pairs of person and server fell
#' back on Entra or could not be checked for the year without access), and
#' the rows stopped on a disabled account (with whether the person has ever
#' entered the server, when the server was read). It has the referents' form
#' to review, and its number counts the rows, people and servers listed. A
#' section with nothing in it is not announced.
#'
#' @param it The `it` part of what `report_assemble()` answered.
#' @inheritParams report_message
#'
#' @return A list with `subject`, `body`, `forma` and `n`.
#'
#' @keywords internal
report_it_message <- function(it, period) {
  stopifnot(is.list(it), is.list(period))

  month <- report_month_words(period[["mese"]])
  read <- report_read_words(period)

  value <- function(rows, name) {
    found <- rows[[name]]
    if (is.null(found)) {
      return(rep("", nrow(rows)))
    }
    found <- trimws(as.character(found))
    found[is.na(found)] <- ""
    found
  }
  row_words <- function(rows) {
    head <- paste0(
      trimws(paste(value(rows, "first_name"), value(rows, "last_name"))),
      ", ", value(rows, "username"), ": ", value(rows, "server")
    )
    list(
      it = paste0(
        "   - Richiesta ", value(rows, "record_id"), ": ", head, ", progetto ",
        value(rows, "project_id"), "."
      ),
      en = paste0(
        "   - Request ", value(rows, "record_id"), ": ", head, ", project ",
        value(rows, "project_id"), "."
      )
    )
  }

  sections <- list()

  orphans <- it[["senza_referente"]]
  if (!is.null(orphans) && nrow(orphans) > 0L) {
    # The column is still `creator`; what it holds is the row's owner.
    owner <- value(orphans, "creator")
    reason <- value(orphans, "motivo")
    because <- list(
      it = ifelse(
        reason == "non_stabilito",
        "Il registro degli eventi non stabilisce a chi appartiene la riga.",
        paste0("Il referente della riga, ", owner, ", ", ifelse(
          reason == "disabilitato", "ha l'account disabilitato su Entra.",
          ifelse(
            reason == "non_trovato", "non risulta su Entra.",
            "ha un account il cui stato non si legge su Entra."
          )
        ))
      ),
      en = ifelse(
        reason == "non_stabilito",
        "The event log does not establish whom the row belongs to.",
        paste0("The row's referent, ", owner, ", ", ifelse(
          reason == "disabilitato", "has a disabled account on Entra.",
          ifelse(
            reason == "non_trovato", "is not on Entra.",
            "has an account whose state cannot be read on Entra."
          )
        ))
      )
    )
    words <- row_words(orphans)
    sections[[length(sections) + 1L]] <- list(
      n = nrow(orphans),
      it = c(
        paste0(
          "Richieste senza un referente a cui mandare il rapporto (",
          nrow(orphans), ")"
        ),
        paste(words[["it"]], because[["it"]])
      ),
      en = c(
        paste0(
          "Requests with no referent to send the report to (",
          nrow(orphans), ")"
        ),
        paste(words[["en"]], because[["en"]])
      )
    )
  }

  people <- it[["non_giudicabili"]] %||% list()
  if (length(people) > 0L) {
    said <- list(
      disabilitato = c(
        it = "account disabilitato su Entra", en = "account disabled on Entra"
      ),
      non_trovato = c(
        it = "account non trovato su Entra", en = "account not found on Entra"
      ),
      senza_creazione = c(
        it = "data di creazione dell'account assente su Entra",
        en = "no creation date on Entra"
      ),
      non_giudicabile = c(
        it = "stato dell'account o data della chiave non leggibili su Entra",
        en = "account state or key date not readable on Entra"
      )
    )
    lines <- lapply(people, function(person) {
      reason <- said[[person[["motivo"]]]] %||% said[["non_giudicabile"]]
      projects <- report_projects_words(person[["progetti"]])
      who <- paste0("   - ", person[["nome"]], ", ", person[["upn"]], ": ")
      c(
        it = paste0(
          who, reason[["it"]], ". Referente: ", person[["referente"]], "; ",
          projects[["it"]], "."
        ),
        en = paste0(
          who, reason[["en"]], ". Referent: ", person[["referente"]], "; ",
          projects[["en"]], "."
        )
      )
    })
    sections[[length(sections) + 1L]] <- list(
      n = length(people),
      it = c(
        paste0(
          "Persone che il rapporto non sa giudicare (", length(people), ")"
        ),
        vapply(lines, `[[`, "", "it")
      ),
      en = c(
        paste0("People the report cannot judge (", length(people), ")"),
        vapply(lines, `[[`, "", "en")
      )
    )
  }

  undated <- it[["senza_data"]]
  if (!is.null(undated) && nrow(undated) > 0L) {
    creator <- value(undated, "creator")
    # Different things to look for: a seal nobody wrote, a seal written by
    # two accounts of which only one can be the channel (without the
    # account configured), or a seal of the channel whose time does not read.
    reason <- value(undated, "data_motivo")
    words <- row_words(undated)
    sections[[length(sections) + 1L]] <- list(
      n = nrow(undated),
      it = c(
        paste0(
          "Richieste senza data di attivazione nel registro degli eventi (",
          nrow(undated), ")"
        ),
        paste0(
          "   Risultano eseguite, ma il registro degli eventi non dice da ",
          "quando."
        ),
        paste0(
          words[["it"]], " ",
          ifelse(
            reason == "log_ambiguo",
            paste0(
              "Nel registro degli eventi i campi del canale li scrive piu' ",
              "di un account, e non si sa quale abbia eseguito la riga."
            ),
            ifelse(
              reason == "orario_illeggibile",
              paste0(
                "Il registro degli eventi porta una scrittura del sigillo da ",
                "parte del canale con un orario che non si legge."
              ),
              paste0(
                "Il registro degli eventi non porta la scrittura del sigillo ",
                "da parte del canale."
              )
            )
          ),
          " Referente: ", ifelse(nzchar(creator), creator, "non stabilito"),
          "."
        )
      ),
      en = c(
        paste0(
          "Requests with no date of activation in the event log (",
          nrow(undated), ")"
        ),
        paste0(
          "   They are on record as applied, but the event log does not say ",
          "since when."
        ),
        paste0(
          words[["en"]], " ",
          ifelse(
            reason == "log_ambiguo",
            paste0(
              "In the event log the channel's fields are written by more ",
              "than one account, and which one executed the row is not known."
            ),
            ifelse(
              reason == "orario_illeggibile",
              paste0(
                "The event log holds a seal written by the channel at a time ",
                "that does not read."
              ),
              "The event log carries no seal written by the channel."
            )
          ),
          " Referent: ", ifelse(nzchar(creator), creator, "not established"),
          "."
        )
      )
    )
  }

  unread <- it[["server_non_letti"]]
  if (!is.null(unread) && nrow(unread) > 0L) {
    said <- list(
      TRASPORTO_CONTRATTO_DISALLINEATO = c(
        it = "modulo non aggiornato", en = "module not updated"
      ),
      TRASPORTO_NON_RAGGIUNGIBILE = c(
        it = "non raggiungibile", en = "not reachable"
      ),
      TRASPORTO_SEGRETO_NON_LEGGIBILE = c(
        it = "segreto non leggibile", en = "secret not readable"
      ),
      TRASPORTO_SEGRETO_RIFIUTATO = c(
        it = "segreto rifiutato dal server", en = "secret refused by the server"
      ),
      TRASPORTO_ISTANZA_SENZA_MODULO = c(
        it = "assente dall'inventario delle istanze col modulo",
        en = "not in the inventory of the instances with the module"
      )
    )
    reason <- value(unread, "motivo")
    why <- lapply(reason, function(code) {
      said[[code]] %||% c(
        it = paste("errore", code), en = paste("error", code)
      )
    })
    fallen <- as.integer(unread[["entra"]])
    unchecked <- as.integer(unread[["non_controllate"]])
    server <- value(unread, "server")
    sections[[length(sections) + 1L]] <- list(
      n = nrow(unread),
      it = c(
        paste0("Server non letti (", nrow(unread), ")"),
        paste0(
          "   - ", server, ": ", vapply(why, `[[`, "", "it"), ". ",
          "Coppie persona-server ricadute su Entra: ", fallen, "; ",
          "non controllate per l'anno senza accessi: ", unchecked, "."
        )
      ),
      en = c(
        paste0("Servers not read (", nrow(unread), ")"),
        paste0(
          "   - ", server, ": ", vapply(why, `[[`, "", "en"), ". ",
          "Person-server pairs that fell back on Entra: ", fallen, "; ",
          "not checked for the year without access: ", unchecked, "."
        )
      )
    )
  }

  stopped <- it[["disattivati"]]
  if (!is.null(stopped) && nrow(stopped) > 0L) {
    entered <- value(stopped, "entrata")
    server <- value(stopped, "server")
    words <- row_words(stopped)
    sections[[length(sections) + 1L]] <- list(
      n = nrow(stopped),
      it = c(
        paste0(
          "Richieste ferme su un account disattivato (", nrow(stopped), ")"
        ),
        paste0(
          words[["it"]],
          ifelse(entered == "si", paste0(
            " La persona e' gia' entrata su ", server, "."
          ), ifelse(entered == "no", paste0(
            " La persona non e' mai entrata su ", server, "."
          ), " Il server non ha risposto."))
        )
      ),
      en = c(
        paste0(
          "Requests stopped on a disabled account (", nrow(stopped), ")"
        ),
        paste0(
          words[["en"]],
          ifelse(entered == "si", paste0(
            " The person has entered ", server, "."
          ), ifelse(entered == "no", paste0(
            " The person has never entered ", server, "."
          ), " The server did not answer."))
        )
      )
    )
  }

  count <- sum(vapply(sections, `[[`, 0L, "n"))
  numbered <- function(lang) {
    unlist(lapply(seq_along(sections), function(i) {
      lines <- sections[[i]][[lang]]
      c(paste0(i, ". ", lines[[1L]]), lines[-1L], "")
    }))
  }

  it_body <- c(
    paste0("DA GUARDARE: ", count),
    "",
    paste0(
      "Rapporto mensile per IT: le richieste di accesso a REDCap che il ",
      "rapporto ai referenti non copre. Mese: ", month[["it"]], "."
    ),
    "",
    numbered("it"),
    read[["it"]]
  )
  en_body <- c(
    paste0("TO REVIEW: ", count),
    "",
    paste0(
      "Monthly report for IT: the REDCap access requests the report to the ",
      "referents does not cover. Month: ", month[["en"]], "."
    ),
    "",
    numbered("en"),
    read[["en"]]
  )

  list(
    subject = paste0(
      "Da guardare (", count, "): rapporto REDCap per IT, ", month[["it"]],
      " / To review (", count, "): REDCap report for IT, ", month[["en"]]
    ),
    body = paste(c(it_body, "", "---", "", en_body), collapse = "\n"),
    forma = "da_guardare",
    n = count
  )
}


#' Compose the report of a month that did not leave on time
#'
#' The report of a month lost, sent by the first run that can send. It says
#' it is late and which month it covers, in the subject and on the first
#' line, and carries the accesses activated in that month, read from the log
#' as always. The people to look at depend on the state of today, and would
#' be the same in every late report: they are only in the report of the
#' month covered by the run, which this one points to.
#'
#' @param attivati The `attivati` of a referent's report for the month lost,
#'   rows, or an empty data frame for none.
#' @param period What `report_month()` answered for the run, the month it
#'   covers being the one this report points to.
#' @param month The month lost, `"AAAA-MM"`.
#'
#' @return A list with `subject`, `body`, `forma` (`in_ritardo`) and `n`
#'   (zero: nobody is listed to look at).
#'
#' @keywords internal
report_late_message <- function(attivati, period, month) {
  stopifnot(
    is.data.frame(attivati), is.list(period),
    is.character(month), length(month) == 1L
  )

  late <- report_month_words(month)
  current <- report_month_words(period[["mese"]])
  activated <- report_activated_lines(attivati)
  read <- report_read_words(period)

  it <- c(
    paste0("IN RITARDO, ", toupper(late[["it"]])),
    "",
    paste0(
      "Rapporto mensile sulle richieste di accesso a REDCap di cui sei ",
      "referente. Mese: ", late[["it"]], ". Questo rapporto e' partito in ",
      "ritardo: porta solo gli accessi attivati in quel mese."
    ),
    paste0(
      "Le persone da guardare sono nel rapporto di ", current[["it"]],
      ", il piu' recente."
    ),
    "",
    activated[["it"]],
    "",
    read[["it"]],
    "Per domande rispondi a questo messaggio: la risposta arriva a IT."
  )
  en <- c(
    paste0("LATE, ", toupper(late[["en"]])),
    "",
    paste0(
      "Monthly report on the REDCap access requests you are the referent ",
      "of. Month: ", late[["en"]], ". This report left late: it carries ",
      "only the accesses granted in that month."
    ),
    paste0(
      "The people to review are in the report of ", current[["en"]],
      ", the latest."
    ),
    "",
    activated[["en"]],
    "",
    read[["en"]],
    "For questions, reply to this message: the reply reaches IT."
  )

  list(
    subject = paste0(
      "In ritardo, ", late[["it"]], ": accessi REDCap / Late, ",
      late[["en"]], ": REDCap access"
    ),
    body = paste(c(it, "", "---", "", en), collapse = "\n"),
    forma = "in_ritardo",
    n = 0L
  )
}


#' The name the report to IT goes under in the ledger
#'
#' Parentheses are not allowed in a REDCap username, so no referent can ever
#' be recorded under the same name.
#'
#' @return One string.
#'
#' @keywords internal
report_it_key <- function() {
  "(IT)"
}


#' Where a month's ledger of sent reports lives
#'
#' A redirected run keeps a ledger of its own, beside the real one: a field
#' test is then as idempotent as the real thing, and does not send everything
#' again every day, without making the real month read as sent.
#'
#' @param dir The job's state directory.
#' @param month The month covered, `"AAAA-MM"`.
#' @param collaudo Whether the ledger is a redirected run's.
#'
#' @return A path.
#'
#' @keywords internal
report_ledger_path <- function(dir, month, collaudo = FALSE) {
  file.path(dir, paste0(month, if (isTRUE(collaudo)) ".collaudo", ".json"))
}


#' The people a report named, as the ledger keeps them
#'
#' A person and a server, one row each: the same person can be named for one
#' server and not for another, and a repeated sentence about "reported
#' before" has to tell them apart.
#'
#' @param x A data frame of `upn` and `server`, or `NULL` for none.
#'
#' @return A data frame of `upn` and `server`, both character.
#'
#' @keywords internal
report_pairs <- function(x = NULL) {
  if (is.null(x) || nrow(x) == 0L) {
    return(data.frame(
      upn = character(), server = character(), stringsAsFactors = FALSE
    ))
  }
  data.frame(
    upn = as.character(x[["upn"]]), server = as.character(x[["server"]]),
    stringsAsFactors = FALSE
  )
}


#' Read one of the lists of people of a ledger entry
#'
#' An entry written by the 0.22.0 holds the people as an array of addresses,
#' with no server: they read with an empty `server`, "all of the person's
#' servers". An entry from now on holds an array of `{upn, server}`. A list
#' that is absent reads as none.
#'
#' @param x What `jsonlite::fromJSON(simplifyVector = FALSE)` made of it.
#'
#' @return A data frame of `upn` and `server`, or `NULL` when it is neither
#'   shape: the ledger does not read.
#'
#' @keywords internal
report_ledger_pairs <- function(x) {
  if (is.null(x)) {
    return(report_pairs())
  }
  if (is.character(x)) {
    x <- as.list(x)
  }
  if (!is.list(x)) {
    return(NULL)
  }

  rows <- lapply(x, function(item) {
    if (is.character(item) && length(item) == 1L) {
      return(c(upn = item, server = ""))
    }
    if (is.list(item) && is.character(item[["upn"]]) &&
          length(item[["upn"]]) == 1L) {
      server <- item[["server"]] %||% ""
      if (is.character(server) && length(server) == 1L) {
        return(c(upn = item[["upn"]], server = server))
      }
    }
    NULL
  })
  if (any(vapply(rows, is.null, logical(1)))) {
    return(NULL)
  }

  report_pairs(data.frame(
    upn = vapply(rows, `[[`, "", "upn"),
    server = vapply(rows, `[[`, "", "server"), stringsAsFactors = FALSE
  ))
}


#' Read a month's ledger of sent reports
#'
#' The ledger is the trace of an event that otherwise leaves none: for each
#' report of the month, when it left and which people it named as having no
#' first sign-in. It is what keeps a report from leaving twice when the daily
#' run tries again, and what the next months read to say a person was
#' reported before. It is not a copy of the state the channel re-reads, which
#' decision 4 of the channel forbids: nothing of the register or of Entra is
#' kept in it.
#'
#' A file that does not read is not read as empty. Read as empty, it would
#' send every report of the month a second time; read as an error, the run
#' sends nothing and says why.
#'
#' @param dir The job's state directory.
#' @param month The month covered, `"AAAA-MM"`.
#' @param collaudo Whether to read a redirected run's ledger.
#'
#' @return A list with `ok`, `errors` and `invii`, one list per report sent:
#'   `destinatario`, `at`, and `senza_primo_accesso` and `senza_accessi`, the
#'   people it named, each a data frame of `upn` and `server`; and
#'   `collaudo`, so that whoever adds to it writes it back where it was
#'   read.
#'
#' @keywords internal
report_ledger_read <- function(dir, month, collaudo = FALSE) {
  stopifnot(
    is.character(dir), length(dir) == 1L, nzchar(dir),
    is.character(month), length(month) == 1L
  )

  collaudo <- isTRUE(collaudo)
  path <- report_ledger_path(dir, month, collaudo)
  if (!file.exists(path)) {
    return(list(
      ok = TRUE, errors = character(), invii = list(), collaudo = collaudo
    ))
  }

  unreadable <- list(
    ok = FALSE, errors = "RAPPORTO_INVII_ILLEGGIBILI", invii = list(),
    collaudo = collaudo
  )
  parsed <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) NULL,
    warning = function(w) NULL
  )
  if (!is.list(parsed) || is.null(names(parsed)) ||
        !identical(parsed[["mese"]], month) ||
        !is.list(parsed[["invii"]]) ||
        !all(vapply(parsed[["invii"]], is.list, logical(1)))) {
    return(unreadable)
  }

  invii <- lapply(parsed[["invii"]], function(entry) {
    list(
      destinatario = scalar_as_character(entry[["destinatario"]]),
      at = scalar_as_character(entry[["at"]]),
      senza_primo_accesso = report_ledger_pairs(entry[["senza_primo_accesso"]]),
      senza_accessi = report_ledger_pairs(entry[["senza_accessi"]])
    )
  })
  tables <- unlist(lapply(invii, function(entry) {
    list(entry[["senza_primo_accesso"]], entry[["senza_accessi"]])
  }), recursive = FALSE)
  if (!all(nzchar(vapply(invii, `[[`, "", "destinatario"))) ||
        !all(vapply(tables, is.data.frame, logical(1)))) {
    return(unreadable)
  }

  list(ok = TRUE, errors = character(), invii = invii, collaudo = collaudo)
}


#' Read the ledgers of the months before this one
#'
#' They serve one sentence, the earlier reports that named a person, and a
#' broken one must not stop every month after it. An unreadable month is
#' named in `illeggibili`, under `RAPPORTO_STORICO_ILLEGGIBILE`, and the
#' readable ones are read all the same.
#'
#' @inheritParams report_ledger_read
#'
#' @return A list with `ok`, false when a month did not read; `errors`;
#'   `invii`, the entries of every readable earlier month together, oldest
#'   month first; and `illeggibili`, the months that did not read.
#'
#' @keywords internal
report_ledger_previous <- function(dir, month) {
  stopifnot(is.character(dir), length(dir) == 1L, nzchar(dir))

  if (!dir.exists(dir)) {
    return(list(
      ok = TRUE, errors = character(), invii = list(),
      illeggibili = character()
    ))
  }

  months <- sub(
    "[.]json$", "",
    list.files(dir, pattern = "^[0-9]{4}-[0-9]{2}[.]json$")
  )
  earlier <- sort(months[months < month])
  readings <- lapply(earlier, function(m) report_ledger_read(dir, m))
  read <- vapply(readings, `[[`, TRUE, "ok")

  list(
    ok = all(read),
    errors = if (all(read)) character() else "RAPPORTO_STORICO_ILLEGGIBILE",
    invii = unlist(lapply(readings, `[[`, "invii"), recursive = FALSE) %||%
      list(),
    illeggibili = earlier[!read]
  )
}


#' Write a file of the state directory whole, or leave the old one
#'
#' Written beside its final name and moved over it, so a run killed halfway
#' leaves the old file or the new one, and not half of either.
#'
#' @param path Where the file lives.
#' @param json The content.
#'
#' @return Whether the file now holds `json`.
#'
#' @keywords internal
report_write_json <- function(path, json) {
  dir <- dirname(path)
  temporary <- tempfile("rapporto-", tmpdir = dir, fileext = ".tmp")
  written <- tryCatch(
    {
      dir.create(dir, recursive = TRUE, showWarnings = FALSE)
      writeLines(json, temporary, useBytes = TRUE)
      file.rename(temporary, path)
    },
    error = function(e) FALSE,
    warning = function(w) FALSE
  )
  if (!isTRUE(written)) {
    unlink(temporary)
  }
  isTRUE(written)
}


#' Where a month's list of the reports due is kept
#'
#' @inheritParams report_ledger_read
#'
#' @return A path.
#'
#' @keywords internal
report_due_path <- function(dir, month) {
  file.path(dir, paste0(month, ".dovuti.json"))
}


#' Read which reports the last whole reading of a month found due
#'
#' A day that cannot read the register, the directory or a row's log does not
#' know who is due, and judging the month on that would make a month already
#' sent look late, or a late one look done. So every run that reads whole
#' keeps the list of the reports due beside the ledger, and a run that cannot
#' judges on it. Who is due, and nothing about them: the list holds the names
#' the ledger holds.
#'
#' @inheritParams report_ledger_read
#'
#' @return A list with `ok`, `errors` and `dovuti`, `NULL` when no whole
#'   reading of the month is on record.
#'
#' @keywords internal
report_due_read <- function(dir, month) {
  path <- report_due_path(dir, month)
  if (!file.exists(path)) {
    return(list(ok = TRUE, errors = character(), dovuti = NULL))
  }

  parsed <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) NULL,
    warning = function(w) NULL
  )
  if (!is.list(parsed) || is.null(names(parsed)) ||
        !identical(parsed[["mese"]], month) ||
        !is.list(parsed[["dovuti"]])) {
    return(list(
      ok = FALSE, errors = "RAPPORTO_DOVUTI_ILLEGGIBILI", dovuti = NULL
    ))
  }

  list(
    ok = TRUE, errors = character(),
    dovuti = as.character(unlist(parsed[["dovuti"]]))
  )
}


#' Keep which reports a whole reading of a month found due
#'
#' @inheritParams report_ledger_read
#' @param due The names of the reports due, as the ledger records them.
#' @param at When the reading was made, `"%Y-%m-%d %H:%M"` in Rome.
#'
#' @return A list with `ok` and `errors`.
#'
#' @keywords internal
report_due_write <- function(dir, month, due, at) {
  json <- jsonlite::toJSON(
    list(mese = month, letto = at, dovuti = I(as.character(due))),
    auto_unbox = TRUE, pretty = TRUE
  )
  if (report_write_json(report_due_path(dir, month), json)) {
    list(ok = TRUE, errors = character())
  } else {
    list(ok = FALSE, errors = "RAPPORTO_DOVUTI_NON_SCRITTI")
  }
}


#' Add one sent report to a month's ledger
#'
#' Written after the send and never before, as the channel writes into the
#' register only after the message left: the price accepted is a report sent
#' twice when the write fails, never one that is lost. The file is replaced
#' whole, `report_write_json()`.
#'
#' @inheritParams report_ledger_read
#' @param ledger The ledger as read, from `report_ledger_read()`, which also
#'   says whether it is a redirected run's.
#' @param entry A list of `destinatario`, `at`, and `senza_primo_accesso` and
#'   `senza_accessi`, each a data frame of `upn` and `server`, or absent.
#'
#' @return A list with `ok`, `errors` and `ledger`, the ledger with the entry
#'   when it was written and as it was otherwise.
#'
#' @keywords internal
report_ledger_add <- function(dir, month, ledger, entry) {
  stopifnot(is.list(ledger), is.list(entry))
  collaudo <- isTRUE(ledger[["collaudo"]])

  invii <- c(ledger[["invii"]], list(list(
    destinatario = as.character(entry[["destinatario"]]),
    at = as.character(entry[["at"]]),
    senza_primo_accesso = report_pairs(entry[["senza_primo_accesso"]]),
    senza_accessi = report_pairs(entry[["senza_accessi"]])
  )))

  # A table is an array of `{upn, server}` objects, and an empty one `[]`: the
  # reader takes both back as they were.
  json <- jsonlite::toJSON(
    list(
      mese = month,
      invii = lapply(invii, function(e) {
        list(
          destinatario = e[["destinatario"]], at = e[["at"]],
          senza_primo_accesso = e[["senza_primo_accesso"]],
          senza_accessi = e[["senza_accessi"]]
        )
      })
    ),
    auto_unbox = TRUE, pretty = TRUE, dataframe = "rows"
  )

  if (!report_write_json(report_ledger_path(dir, month, collaudo), json)) {
    return(list(
      ok = FALSE, errors = "RAPPORTO_INVII_NON_SCRITTI", ledger = ledger
    ))
  }

  list(
    ok = TRUE, errors = character(),
    ledger = list(
      ok = TRUE, errors = character(), invii = invii, collaudo = collaudo
    )
  )
}


#' The first month the monthly report covers
#'
#' A month before it was never due, and is not recovered whatever the state
#' directory holds.
#'
#' @return A month, `"AAAA-MM"`.
#'
#' @keywords internal
report_first_month <- function() {
  "2026-10"
}


#' The months whose reports did not all leave, from the first one covered
#'
#' A month is lost when its ledger of sent reports lacks any of the reports
#' its list of the reports due holds, or when no list is on record: a month
#' the job never read whole. The report to IT (`report_it_key()`) is not
#' counted, because what it carries is the state of today and the report to
#' IT of the month the run covers carries it. A ledger or a list that does
#' not read leaves its month out, as it would send blind, and says why.
#'
#' @param dir The job's state directory.
#' @param month The month the run covers: the months checked are those from
#'   `report_first_month()`, or from the oldest month the directory holds a
#'   ledger or a list of, whichever is later, up to it, excluded. A directory
#'   with none recovers nothing.
#'
#' @return A list with `ok`, false when a ledger or a list did not read;
#'   `errors`, `RAPPORTO_INVII_ILLEGGIBILI` and `RAPPORTO_DOVUTI_ILLEGGIBILI`;
#'   and `mesi`, the lost months oldest first, each a list of `mese`,
#'   `dovuti` (as kept, `NULL` when none is) and `ledger` (as
#'   `report_ledger_read()` answered).
#'
#' @keywords internal
report_lost_months <- function(dir, month) {
  stopifnot(
    is.character(dir), length(dir) == 1L, nzchar(dir),
    is.character(month), length(month) == 1L
  )

  # Not before the oldest month the directory holds a file of: a directory
  # lost or made again has nothing to recover, and would otherwise send a
  # late report for every month since the first. A month missing between two
  # that have files is still recovered. A redirected run's files do not count.
  files <- if (dir.exists(dir)) {
    list.files(dir, pattern = "^[0-9]{4}-[0-9]{2}([.]dovuti)?[.]json$")
  } else {
    character()
  }
  if (length(files) == 0L) {
    return(list(ok = TRUE, errors = character(), mesi = list()))
  }

  candidates <- character()
  candidate <- max(report_first_month(), min(substr(files, 1L, 7L)))
  while (candidate < month) {
    candidates <- c(candidates, candidate)
    candidate <- report_shift_month(candidate, 1L)
  }

  lost <- list()
  errors <- character()
  for (m in candidates) {
    due <- report_due_read(dir, m)
    ledger <- report_ledger_read(dir, m)
    errors <- c(errors, due[["errors"]], ledger[["errors"]])
    if (!isTRUE(due[["ok"]]) || !isTRUE(ledger[["ok"]])) {
      next
    }
    sent <- vapply(ledger[["invii"]], `[[`, "", "destinatario")
    left <- setdiff(due[["dovuti"]], c(sent, report_it_key()))
    if (is.null(due[["dovuti"]]) || length(left) > 0L) {
      lost[[length(lost) + 1L]] <- list(
        mese = m, dovuti = due[["dovuti"]], ledger = ledger
      )
    }
  }

  list(ok = length(errors) == 0L, errors = unique(errors), mesi = lost)
}


#' Send the late reports of one month lost
#'
#' Each report that left is written in the ledger of its month, as if it had
#' left on time, with the date of the run and the two tables empty: what it
#' named is not what the month after reads back. A ledger that cannot be
#' written stops the month, as in the month the run covers, and what it did
#' not try counts as failed.
#'
#' @param batch What `provisioning_report()` composed for one lost month:
#'   `mese`, `ledger`, `pendenti` (who has not received it) and `rapporti`
#'   (their messages, by name).
#' @param mailer,copy_to As in `provisioning_report()`; IT is in copy.
#' @param complete Whether the run read whole and the ledger of the month it
#'   covers read too. Without it nothing leaves, the reports count as failed,
#'   and the late ones are tried again on the next run.
#' @param dir The job's state directory.
#' @param at When the run read, `"%Y-%m-%d %H:%M"` in Rome.
#'
#' @return A list with `rapporti`, a data frame of `mese`, `destinatario`
#'   and `esito` (`mandato`, `fallito` or `non_mandato`), and `errors`.
#'
#' @keywords internal
report_recover <- function(batch, mailer, complete, copy_to, dir, at) {
  who <- batch[["pendenti"]]
  outcome <- rep("non_mandato", length(who))
  errors <- character()
  ledger <- batch[["ledger"]]

  if (!is.null(mailer) && !complete) {
    outcome[] <- "fallito"
  }
  if (!is.null(mailer) && complete) {
    for (k in seq_along(who)) {
      answer <- report_deliver(
        mailer, to = who[[k]], cc = copy_to,
        message = batch[["rapporti"]][[who[[k]]]]
      )
      if (!isTRUE(answer[["ok"]])) {
        outcome[[k]] <- "fallito"
        errors <- c(errors, answer[["errors"]])
        next
      }
      outcome[[k]] <- "mandato"

      written <- report_ledger_add(
        dir, batch[["mese"]], ledger,
        list(destinatario = who[[k]], at = at)
      )
      if (!isTRUE(written[["ok"]])) {
        errors <- c(errors, written[["errors"]])
        outcome[-seq_len(k)] <- "fallito"
        break
      }
      ledger <- written[["ledger"]]
    }
  }

  list(
    rapporti = data.frame(
      mese = rep(batch[["mese"]], length(who)), destinatario = who,
      esito = outcome, stringsAsFactors = FALSE
    ),
    errors = errors
  )
}


#' Hand one report to the mailer, redirected when asked
#'
#' @param mailer `function(to, cc, subject, body)` returning `ok` and `errors`.
#' @param to,cc Who the report is for, and who in copy.
#' @param message What `report_message()` or `report_it_message()` composed.
#' @param redirect_to One address replacing every recipient, or `NULL`.
#'
#' @return A list with `ok` and `errors`.
#'
#' @keywords internal
report_deliver <- function(mailer, to, cc, message, redirect_to = NULL) {
  if (is.null(to) || length(to) != 1L || is.na(to) || !nzchar(to)) {
    return(list(ok = FALSE, errors = "POSTA_SENZA_DESTINATARIO"))
  }

  body <- message[["body"]]
  if (!is.null(redirect_to)) {
    body <- mail_redirect_note(body, to, cc)
    to <- redirect_to
    cc <- NULL
  }

  # A mailer that throws is a post that did not answer, and the run goes on
  # to leave its record rather than dying without one.
  tryCatch(
    mailer(to = to, cc = cc, subject = message[["subject"]], body = body),
    error = function(e) {
      list(ok = FALSE, errors = "TRASPORTO_POSTA_NON_RAGGIUNGIBILE")
    }
  )
}


#' Whom each row belonged to as a month ended
#'
#' The owner is read on the row's log cut at midnight in Rome between the
#' last day of the month and the first of the next: `before` cuts the writes
#' of `owned_by` only, and without the channel's account a second account
#' writing a channel field after it would still make the row ambiguous. A
#' stamp that does not read stays, and the owner is unknown, as on the whole
#' log. A row whose log was not read keeps its creator.
#'
#' @param logs One element per row, in the register's order: the row's log,
#'   or `NULL` where it was not read.
#' @param ids The rows' record ids.
#' @param creators Whom each row was made by, as `log_creators()` names them.
#' @param month The month covered, `"AAAA-MM"`.
#' @param channel_account As in `provisioning_report()`.
#'
#' @return A character vector, one owner for each row, `""` where none is
#'   established.
#'
#' @keywords internal
report_owners <- function(logs, ids, creators, month, channel_account = NULL) {
  stopifnot(
    is.list(logs), is.character(ids), is.character(creators),
    length(logs) == length(ids), length(creators) == length(ids),
    is.character(month), length(month) == 1L
  )

  month_end <- paste0(report_shift_month(month, 1L), "-01 00:00")
  owners <- creators
  for (i in seq_along(logs)) {
    log <- logs[[i]]
    if (is.null(log)) {
      next
    }
    stamps <- trimws(as.character(log[["timestamp"]]))
    upto <- log[
      !log_stamp_reads(stamps) | substr(stamps, 1L, 16L) < month_end, ,
      drop = FALSE
    ]
    owner <- log_owner(
      upto, ids[[i]], creators[[i]], channel_account, before = month_end
    )
    owners[[i]] <- if (is.na(owner)) "" else owner
  }
  owners
}


#' Run the monthly report once
#'
#' **It reads and sends mail, and nothing else.** It does not write in the
#' register and does not touch Entra: the register is read with the channel's
#' token, the creations and each active row's log with the same calls the
#' round makes, the tenant with the round's sweep. That is what lets it run
#' outside the channel's path, as a job of its own.
#'
#' It also asks the instances, `accounts` only, through `report_server_reads()`:
#' once the register and the directory have read whole, each server the
#' register has rows on is asked for the people of those rows, the rows stopped
#' on a disabled account included. A server that is not read stops nothing
#' and is not an error: it is counted in `istanze_non_lette`, and the report
#' goes on without what that server would have said.
#'
#' The job runs every day, because an alarm on logs looks back two days at
#' most and a monthly job cannot be watched by the absence of a record. Every
#' day it reads, computes and leaves a record; from the 1st on it sends the
#' previous month's report to whoever has not received it yet, until the
#' month is complete. The ledger of what left (`report_ledger_read()`) is what
#' tells them apart.
#'
#' A day on which anything it needs could not be read sends nothing: the
#' register, the creations, the directory, any active row's log, the month's
#' ledger. An earlier month's ledger that does not read stops nothing: the
#' people it could hold are told without their earlier reports.
#' A report composed on half a reading would be wrong for somebody, and the
#' next day tries again. Such a day also does not know who is due, so it
#' judges the month on the reports the last whole reading found due, kept
#' beside the ledger (`report_due_read()`); with none on record it says
#' nothing is due, and the alarm on absence is the one that speaks.
#'
#' On the 1st the run moves on to the month just ended. A month whose reports
#' did not all leave is not given up: the first run that can send (read whole,
#' the post on) sends the late reports of those months first, oldest first,
#' each saying it is late and carrying the accesses activated in its own month
#' (`report_late_message()`), and then the report of the month covered. The
#' months checked are those from `report_first_month()` up to the month
#' covered, excluded (`report_lost_months()`); a month with no list of the
#' reports due kept takes the referents of today for it, and keeps them. The
#' report to IT is not recovered, since it carries the state of today. Each
#' late report that leaves is written in the ledger of its month. While a
#' month is still missing a report after the round, the record carries
#' `RAPPORTO_MESE_PRECEDENTE_INCOMPLETO`, and `in_ritardo` is true.
#'
#' **The real ledger is written only by a real run**: the post on, nobody
#' redirected, the month the clock gives. A run with the post off sends
#' nothing to record. A redirected run is a field test: recorded in the real
#' ledger, it would make the real month read as sent, and a test at the end
#' of October would leave nothing to leave on the 1st of November. So it keeps
#' a ledger of its own, and is idempotent as the real run is: the timer of a
#' field test does not send everything again every day. A run with a forced
#' month writes nothing at all. Neither of the two recovers a month lost: a
#' late report that went to the test address would be written in the real
#' ledger of its month, and its referent would never receive it.
#'
#' The report to IT goes to `copy_to`, the address IT is in copy at on every
#' outcome, under the name `report_it_key()`; the referents' reports go to the
#' owner's account, with `copy_to` in copy.
#'
#' A row goes to its owner as the month covered ended, at midnight in Rome
#' between its last day and the next month's first, and not to its owner on
#' the day of the run: `log_owner()` reads the row's log cut at that moment,
#' so a write after it, of `owned_by` or of any other field of the channel,
#' changes nothing. The month's reports
#' leave over several days, until each referent has had theirs, and who is
#' due must not change from one attempt to the next (decided on 2026-10-17):
#' read on the day, a row passed on the 3rd would move from one referent's
#' report to the other referent's between two attempts, after one of the two
#' had left.
#' Without `channel_account`, `NULL`, no write of `owned_by` is believed and
#' every row stays with its creator.
#'
#' @param register_url,register_token The register's host and API token.
#' @param graph_token,graph_url The Microsoft Graph access token and endpoint.
#'   Neither has a default, as in the round: an empty one is a directory that
#'   could not be read, and the record says so.
#' @param ledger_dir The job's state directory, where the ledgers live.
#' @param now When the run reads. The month, the day and the hour the mail
#'   says it read at all come from here.
#' @param month A month `"AAAA-MM"` to cover instead of the one the clock
#'   gives, for a run by hand; `NULL` otherwise.
#' @param mailer `function(to, cc, subject, body)` returning `ok` and
#'   `errors`, or `NULL` for no post.
#' @param redirect_to One address replacing every recipient, or `NULL`.
#' @param copy_to The address of IT: in copy on the referents' reports, and
#'   the recipient of the report to IT.
#' @param channel_account The REDCap username that holds the register's
#'   token, the account the round writes with, or more than one while the
#'   token changes hands. With it, only their writes of `owned_by` pass a row
#'   to another referent and only their seals date a row, and what any other
#'   account wrote in the channel's fields is ignored; with `NULL`, the
#'   default, every row belongs to its creator, and the channel is whoever
#'   wrote its fields. The runner reads it from `UBEP_CANALE_UTENTE`, a list
#'   separated by commas, which it requires.
#' @param hosts,secrets Named character vectors, server name to host and to
#'   the secret of its module. A server missing from either, or with an `NA`
#'   secret, is not read.
#'
#' @return A list that `report_record()` turns into the record, plus
#'   `rapporti`, one row per report due and per late report, with the `mese`
#'   it covers, for whoever reads a single run; `server`, what
#'   `report_server_reads()` answered for each server asked; `recuperati`,
#'   the late reports tried (a data frame of `mese`, `destinatario` and
#'   `esito`, `mandato` or `fallito`); and `mesi_persi`, the months still
#'   missing a report after the round.
#'
#' @keywords internal
provisioning_report <- function(register_url,
                                register_token,
                                graph_token,
                                graph_url,
                                ledger_dir,
                                now = Sys.time(),
                                month = NULL,
                                mailer = NULL,
                                redirect_to = NULL,
                                copy_to = NULL,
                                channel_account = NULL,
                                hosts = character(),
                                secrets = character()) {
  stopifnot(
    is.character(graph_token), length(graph_token) == 1L,
    is.character(graph_url), length(graph_url) == 1L,
    is.character(ledger_dir), length(ledger_dir) == 1L, nzchar(ledger_dir),
    is.null(mailer) || is.function(mailer),
    channel_account_valid(channel_account),
    is.character(hosts), is.character(secrets)
  )

  period <- report_month(now, month)
  errors <- character()

  # A redirected run on the real month reads and writes a ledger of its own.
  test_run <- !is.null(redirect_to) && !isTRUE(period[["forzato"]])
  ledger <- report_ledger_read(ledger_dir, period[["mese"]], test_run)
  previous <- report_ledger_previous(ledger_dir, period[["mese"]])
  errors <- c(errors, ledger[["errors"]], previous[["errors"]])

  # The months lost: a real run is the only one that recovers them, and the
  # ones still lost after its round are said in the record. A forced or a
  # redirected run would write a report that went elsewhere into the real
  # ledger of a month, and the referent would never receive it.
  recover <- !test_run && !isTRUE(period[["forzato"]])
  lost <- if (recover) {
    report_lost_months(ledger_dir, period[["mese"]])
  } else {
    list(ok = TRUE, errors = character(), mesi = list())
  }
  errors <- c(errors, lost[["errors"]])

  # The register and its creations, asked as the round asks them: the
  # creations in one call and with no window, since a record is created once.
  reading <- register_records(register_url, register_token)
  creations <- NULL
  if (isTRUE(reading[["ok"]])) {
    creations <- register_log(
      register_url, register_token, logtype = "record_add"
    )
  }
  errors <- c(errors, reading[["errors"]], creations[["errors"]])
  register_read <- isTRUE(reading[["ok"]]) && isTRUE(creations[["ok"]])

  sweep <- if (nzchar(graph_url) && nzchar(graph_token)) {
    directory_users(graph_token, graph_url)
  } else {
    list(
      ok = FALSE, errors = "TRASPORTO_DIRECTORY_SENZA_ENDPOINT", users = NULL
    )
  }
  directory_read <- isTRUE(sweep[["ok"]])
  if (!directory_read) {
    errors <- c(errors, sweep[["errors"]])
  }

  assembled <- list(referenti = list(), it = NULL, senza_creatore = 0L)
  batches <- list()
  logs_read <- TRUE
  servers <- list()
  unread_servers <- 0L

  if (register_read && directory_read) {
    register <- reading[["records"]]
    ids <- as.character(register[["record_id"]] %||% character())
    field <- function(name) {
      value <- register[[name]] %||% rep("", nrow(register))
      value <- trimws(as.character(value))
      value[is.na(value)] <- ""
      value
    }
    creators <- log_creators(creations[["log"]], ids)
    born <- report_born(creations[["log"]], ids)

    # One call per active row, and no window: the first execution can be
    # months old. Today that is one call; past five hundred rows it is worth
    # looking at again.
    executions <- rep(list(NULL), nrow(register))
    since <- rep(list(NULL), nrow(register))
    logs <- rep(list(NULL), nrow(register))
    active <- field("request_status") == "active" &
      field("outcome") == "applied"
    for (i in which(active)) {
      answer <- register_log(register_url, register_token, record = ids[[i]])
      if (isTRUE(answer[["ok"]])) {
        executions[i] <- list(
          report_executions(answer[["log"]], ids[[i]], channel_account)
        )
        since[i] <- list(
          report_person_since(answer[["log"]], ids[[i]], channel_account)
        )
        logs[i] <- list(answer[["log"]])
      } else {
        logs_read <- FALSE
        errors <- c(errors, answer[["errors"]])
      }
    }

    # The servers are asked after the register and the directory have read
    # whole, for the people of the rows it has on each. A server that is not
    # read is not an error and is not a reading that failed: it is counted,
    # and the pairs of that server fall back on what the directory says.
    servers <- report_server_reads(
      report_server_asks(register), hosts, secrets
    )
    unread_servers <- sum(!vapply(servers, `[[`, NA, "letto"))

    # The owner as the month covered ended, and not today's. The rows whose
    # log is not read keep their creator: none of them enters the report.
    channel_known <- !is.null(channel_account)
    rows <- report_rows(
      register,
      report_owners(logs, ids, creators, period[["mese"]], channel_account),
      executions, period, since, born, channel_known = channel_known
    )
    assembled <- report_assemble(
      rows, sweep[["users"]], period, previous[["invii"]],
      previous[["illeggibili"]], servers = servers,
      stopped = report_stopped_rows(register)
    )

    # The reports of the months lost, from the same readings and the owners
    # as each of those months ended. What a late report carries is the month's
    # activations: the rest is today's state, and the report of the month
    # covered carries it.
    for (item in if (logs_read) lost[["mesi"]] else list()) {
      lost_period <- period
      lost_period[["mese"]] <- item[["mese"]]
      lost_period[["prossimo"]] <- as.Date(
        paste0(report_shift_month(item[["mese"]], 2L), "-01")
      )
      lost_assembled <- report_assemble(
        report_rows(
          register,
          report_owners(logs, ids, creators, item[["mese"]], channel_account),
          executions, lost_period, since, born, channel_known = channel_known
        ),
        sweep[["users"]], lost_period
      )

      # Who is due: the list kept when the month was read whole, otherwise the
      # referents of today for that month, which are kept from now on.
      due_then <- item[["dovuti"]]
      if (is.null(due_then)) {
        due_then <- names(lost_assembled[["referenti"]]) %||% character()
        kept <- report_due_write(
          ledger_dir, item[["mese"]], due_then, period[["letto"]]
        )
        errors <- c(errors, kept[["errors"]])
      }
      due_then <- setdiff(due_then, report_it_key())
      owed <- setdiff(
        due_then, vapply(item[["ledger"]][["invii"]], `[[`, "", "destinatario")
      )
      batches[[length(batches) + 1L]] <- list(
        mese = item[["mese"]], ledger = item[["ledger"]], pendenti = owed,
        rapporti = stats::setNames(lapply(owed, function(who) {
          report_late_message(
            lost_assembled[["referenti"]][[who]][["attivati"]] %||%
              data.frame(),
            period, item[["mese"]]
          )
        }), owed)
      )
    }
  }

  reports <- lapply(assembled[["referenti"]], report_message, period = period)
  if (!is.null(assembled[["it"]])) {
    reports[[report_it_key()]] <- report_it_message(assembled[["it"]], period)
  }

  # Who is due: today's reading when it is whole, and kept for the days that
  # are not; otherwise the last whole reading's. A forced run speaks about a
  # month that is not the real one, and keeps nothing.
  read_whole <- register_read && directory_read && logs_read
  if (read_whole) {
    due <- names(reports) %||% character()
    if (!isTRUE(period[["forzato"]])) {
      kept <- report_due_write(
        ledger_dir, period[["mese"]], due, period[["letto"]]
      )
      errors <- c(errors, kept[["errors"]])
    }
  } else {
    known <- report_due_read(ledger_dir, period[["mese"]])
    errors <- c(errors, known[["errors"]])
    due <- known[["dovuti"]] %||% character()
  }
  already <- vapply(ledger[["invii"]], `[[`, "", "destinatario")
  pending <- setdiff(due, already)

  # Only the covered month's ledger stops the post: without it a report could
  # leave twice. The earlier ones serve "reported before" and nothing else.
  complete <- read_whole && isTRUE(ledger[["ok"]])
  keeps_ledger <- !is.null(mailer) && !isTRUE(period[["forzato"]])

  # The months lost go first, oldest first, and a failure there does not stop
  # the month covered. What is still missing afterwards is said in the record.
  recovered <- data.frame(
    mese = character(), destinatario = character(), esito = character(),
    stringsAsFactors = FALSE
  )
  late_table <- recovered
  for (batch in batches) {
    answer <- report_recover(
      batch, mailer, complete, copy_to, ledger_dir, period[["letto"]]
    )
    errors <- c(errors, answer[["errors"]])
    late_table <- rbind(late_table, answer[["rapporti"]])
  }
  recovered <- late_table[late_table[["esito"]] != "non_mandato", ,
                          drop = FALSE]
  rownames(recovered) <- NULL
  still_lost <- vapply(lost[["mesi"]], function(item) {
    m <- item[["mese"]]
    !(m %in% vapply(batches, `[[`, "", "mese")) ||
      any(late_table[["esito"]][late_table[["mese"]] == m] != "mandato")
  }, NA)
  lost_months <- vapply(lost[["mesi"]], `[[`, "", "mese")[still_lost]
  if (length(lost_months) > 0L) {
    errors <- c(errors, "RAPPORTO_MESE_PRECEDENTE_INCOMPLETO")
  }

  sent <- character()
  failed <- character()

  if (!is.null(mailer) && length(pending) > 0L && !complete) {
    failed <- pending
  }

  if (!is.null(mailer) && complete) {
    for (k in seq_along(pending)) {
      who <- pending[[k]]
      for_it <- identical(who, report_it_key())
      answer <- report_deliver(
        mailer,
        to = if (for_it) copy_to else who,
        cc = if (for_it) NULL else copy_to,
        message = reports[[who]],
        redirect_to = redirect_to
      )
      if (!isTRUE(answer[["ok"]])) {
        failed <- c(failed, who)
        errors <- c(errors, answer[["errors"]])
        next
      }
      sent <- c(sent, who)

      if (keeps_ledger) {
        # The pairs the report named, person and server: the next months read
        # them back to say "also reported on".
        people <- if (for_it) {
          list()
        } else {
          assembled[["referenti"]][[who]][["senza_primo_accesso"]]
        }
        named <- data.frame(
          upn = vapply(people, `[[`, "", "upn"),
          server = vapply(people, `[[`, "", "server"),
          stringsAsFactors = FALSE
        )
        # The year without access: the pairs listed in full and those that
        # were named before and are still there, which the next month needs
        # to go on counting them.
        idle <- if (for_it) {
          list()
        } else {
          assembled[["referenti"]][[who]][["senza_accessi"]]
        }
        idle_named <- rbind(
          report_pairs(data.frame(
            upn = vapply(idle, `[[`, "", "upn"),
            server = vapply(idle, `[[`, "", "server"),
            stringsAsFactors = FALSE
          )),
          report_pairs(
            assembled[["referenti"]][[who]][["senza_accessi_gia_coppie"]]
          )
        )
        written <- report_ledger_add(
          ledger_dir, period[["mese"]], ledger,
          list(
            destinatario = who, at = period[["letto"]],
            senza_primo_accesso = named, senza_accessi = idle_named
          )
        )
        # A ledger that cannot be written would make every later report of
        # this run a duplicate tomorrow: the run stops sending, and what it
        # did not try counts as not sent.
        if (!isTRUE(written[["ok"]])) {
          errors <- c(errors, written[["errors"]])
          failed <- c(failed, pending[-seq_len(k)])
          break
        }
        ledger <- written[["ledger"]]
      }
    }
  }

  forms <- vapply(reports, `[[`, "", "forma", USE.NAMES = FALSE)
  # One row per report due, also when the due ones come from an earlier
  # reading and today composed none of them.
  composed <- match(due, names(reports))
  form_of <- ifelse(is.na(composed), "", forms[composed])
  count_of <- ifelse(
    is.na(composed), NA_integer_,
    vapply(reports, `[[`, 0L, "n", USE.NAMES = FALSE)[composed]
  )

  list(
    at = format(now, "%Y-%m-%d %H:%M", tz = "UTC"),
    mese = period[["mese"]],
    forzato = isTRUE(period[["forzato"]]),
    giorno = period[["giorno"]],
    registro_letto = register_read,
    directory_letta = directory_read,
    letture_complete = complete,
    server = servers,
    istanze_non_lette = as.integer(unread_servers),
    posta_dirottata = !is.null(redirect_to),
    dovuti = due,
    gia = already,
    pendenti = pending,
    mandati = sent,
    falliti = failed,
    forme = forms,
    voci_attivati = sum(vapply(
      assembled[["referenti"]], function(r) nrow(r[["attivati"]]), 0L
    )),
    voci_senza_primo_accesso = sum(vapply(
      assembled[["referenti"]],
      function(r) length(r[["senza_primo_accesso"]]), 0L
    )),
    voci_senza_accessi = sum(vapply(
      assembled[["referenti"]],
      function(r) length(r[["senza_accessi"]]), 0L
    )),
    senza_creatore = as.integer(assembled[["senza_creatore"]]),
    recuperati = recovered,
    mesi_persi = lost_months,
    rapporti = rbind(
      data.frame(
        mese = late_table[["mese"]],
        destinatario = late_table[["destinatario"]],
        forma = rep("in_ritardo", nrow(late_table)),
        voci = rep(0L, nrow(late_table)),
        esito = late_table[["esito"]],
        stringsAsFactors = FALSE
      ),
      data.frame(
        mese = rep(period[["mese"]], length(due)),
        destinatario = due,
        forma = form_of,
        voci = count_of,
        esito = ifelse(
          due %in% sent, "mandato",
          ifelse(due %in% already, "gia_mandato",
                 ifelse(due %in% failed, "fallito", "non_mandato"))
        ),
        stringsAsFactors = FALSE
      )
    ),
    errori = unique(errors)
  )
}


#' Whether the month's reports are late
#'
#' From the second day of the month on, with the month not complete, or while
#' a month lost still misses a report. Computed here and not in the query of
#' the alarm, so that a test covers it. A forced run speaks about another
#' month and cannot say the real one is late: it says false, and the next run
#' of the timer says the truth.
#'
#' @param giorno The day of the month the run is in, in Rome.
#' @param completo Whether every report of the month has left.
#' @param forzato Whether the month was forced.
#' @param persi How many months lost still miss a report.
#'
#' @return One logical.
#'
#' @keywords internal
report_late <- function(giorno, completo, forzato, persi = 0L) {
  !isTRUE(forzato) && ((giorno >= 2L && !isTRUE(completo)) || persi > 0L)
}


#' Build the record the monthly report leaves behind
#'
#' The columns are those of its own table, `UbepRapporto_CL`, and only those:
#' the job has a table of its own rather than a discriminating column in the
#' round's or the observer's, whose rules read the last record without asking
#' who wrote it. Every column is present on every run, zeroed when there is
#' nothing to count, because the rule on the incomplete record counts them.
#'
#' `referenti` counts the reports of the month, the one to IT included: those
#' due, as today's reading or the last whole one found them, and those the
#' ledger says left on earlier days. `mese_completo` is the design's
#' `gia_mandati + mandati == referenti`, on those, and `mandati` there are the
#' reports of the month covered only: the late reports of the months lost
#' count in `mandati` and `falliti` of the record, and not in the completeness
#' of the month, which a recovery of two of three would otherwise make look
#' whole. A day that cannot read
#' judges the month on the last whole reading, so a reading that fails after
#' the month was sent does not make it late; with no whole reading on record
#' nothing is due, and the month is not called late on a guess.
#' `in_ritardo` is `report_late()`: from day 2 with the month not complete,
#' or while a month lost still misses a report (`mesi_persi`).
#'
#' `istanze_non_lette` counts the servers the report asked and could not read.
#' `voci_senza_accessi` counts the pairs of person and server listed in full
#' for the year without access: those already named in an earlier report and
#' those on a server not read are not in it.
#'
#' Names and codes only, and never a person: the record is shipped to a
#' workspace and kept.
#'
#' @param esito What `provisioning_report()` returned.
#' @param posta Whether the run was allowed to send. No fallback, as in the
#'   round's record: a caller that forgot it would report the post as off.
#'
#' @return A named list, ready for `run_record_json()`.
#'
#' @keywords internal
report_record <- function(esito, posta) {
  stopifnot(
    is.list(esito),
    is.logical(posta), length(posta) == 1L, !is.na(posta)
  )

  due <- as.character(esito[["dovuti"]] %||% character())
  already <- as.character(esito[["gia"]] %||% character())
  sent <- as.character(esito[["mandati"]] %||% character())
  forms <- as.character(esito[["forme"]] %||% character())
  recovered <- as.character(esito[["recuperati"]][["esito"]])

  referenti <- length(union(due, already))
  completo <- length(already) + length(sent) == referenti

  list(
    at = as.character(esito[["at"]]),
    mese = as.character(esito[["mese"]]),
    giorno_di_invio = length(esito[["pendenti"]]) > 0L,
    registro_letto = isTRUE(esito[["registro_letto"]]),
    directory_letta = isTRUE(esito[["directory_letta"]]),
    istanze_non_lette = as.integer(esito[["istanze_non_lette"]] %||% 0L),
    posta = isTRUE(posta),
    posta_dirottata = isTRUE(esito[["posta_dirottata"]]),
    referenti = referenti,
    mandati = length(sent) + sum(recovered == "mandato"),
    gia_mandati = length(already),
    falliti = length(esito[["falliti"]]) + sum(recovered == "fallito"),
    in_ordine = sum(forms == "in_ordine"),
    da_guardare = sum(forms == "da_guardare"),
    voci_attivati = as.integer(esito[["voci_attivati"]] %||% 0L),
    voci_senza_primo_accesso =
      as.integer(esito[["voci_senza_primo_accesso"]] %||% 0L),
    voci_senza_accessi = as.integer(esito[["voci_senza_accessi"]] %||% 0L),
    senza_creatore = as.integer(esito[["senza_creatore"]] %||% 0L),
    mese_completo = completo,
    in_ritardo = report_late(
      esito[["giorno"]], completo, esito[["forzato"]],
      persi = length(esito[["mesi_persi"]])
    ),
    errori = as.character(esito[["errori"]] %||% character())
  )
}
