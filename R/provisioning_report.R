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
#' One value, in one place: the next measurement changes it in one line.
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
#' parameter: that `exportLogging` honors it is measured only with the 0.19.0
#' in service, and an instance that ignored it would hand back the whole log,
#' where another row's execution would date this one.
#'
#' The author has to be the channel, which `log_channel_accounts()` names
#' without configuration. When two accounts write the channel's fields the log
#' cannot say which of them executed the row, and the answer is unknown rather
#' than a guess.
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
#' 2026-09-01, a round at 21:03 UTC is logged at 23:03. A month is then the
#' first seven characters of the stamp, and no conversion can shift a row
#' activated on the last evening of the month into the next one.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param record The record id.
#'
#' @return The stamps of the channel's seal writes, `"%Y-%m-%d %H:%M"` in
#'   Rome, oldest first; `character()` when there is none; `NA_character_`
#'   when the log cannot say.
#'
#' @keywords internal
report_executions <- function(events, record) {
  stopifnot(is.data.frame(events))

  mine <- log_of_record(events, record)
  channel <- log_channel_accounts(events, record)
  if (length(channel) > 1L) {
    return(NA_character_)
  }

  authors <- trimws(as.character(mine[["username"]]))
  sealed <- log_wrote(mine, "applied_seal") & authors %in% channel &
    nzchar(log_value(mine, "applied_seal"))
  stamps <- trimws(as.character(mine[["timestamp"]][sealed]))

  # A stamp that does not read as one cannot place the row in any month.
  if (!all(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}", stamps))) {
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
report_person_since <- function(events, record) {
  stopifnot(is.data.frame(events))

  mine <- log_current_life(log_of_record(events, record))
  channel <- log_channel_accounts(mine, record)
  if (length(channel) > 1L) {
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

  if (!all(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}", stamps))) {
    return(NA_character_)
  }
  if (length(stamps) == 0L) {
    return(character())
  }
  sort(stamps)[[1L]]
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
#' Phase 1 of the report reads Entra and nothing else, with the permission the
#' round already holds. `lastPasswordChangeDateTime` is, in the words of Learn,
#' "the time when this Microsoft Entra user last changed their password or
#' when their password was created", and the round creates every account with
#' `forceChangePasswordNextSignIn`: an account whose key is as old as the
#' account itself is an account nobody has entered.
#'
#' What it cannot see, said where it is decided. A key reset by IT moves the
#' date without anybody signing in, and the person drops out of the report
#' (phase 2 removes this). An account that existed long before the request
#' has dates that diverge, and the person never shows, even if they never
#' opened the instance asked for: the signal says "has used the UBEP
#' account", not "has used REDCap".
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


#' The rows a month's report speaks about, with their creator and their date
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
#' IT. `data_motivo` says which of the two ways: `senza_sigillo`, no seal
#' written by the channel; `log_ambiguo`, the channel's fields written by
#' more than one account, so that which one executed the row is unknown. The
#' two send IT to look for different things. A row whose log could not be
#' read is left out, since it cannot be judged on a reading that did not
#' happen; the caller sends nothing on such a day.
#'
#' @param register The register as read.
#' @param creators Who created each row, as `log_creators()` answers, in the
#'   register's order.
#' @param executions One element per row, in the register's order: what
#'   `report_executions()` answered, or `NULL` where the log was not read.
#' @param period What `report_month()` answered.
#' @param since One element per row, what `report_person_since()` answered,
#'   or `NULL` to date the person by the row's first execution.
#'
#' @return The kept rows of `register`, with `creator`, `attivata_il`,
#'   `nel_mese`, `senza_data`, `data_motivo` and `persona_dal` added.
#'
#' @keywords internal
report_rows <- function(register, creators, executions, period,
                        since = NULL) {
  stopifnot(
    is.data.frame(register),
    is.character(creators), length(creators) == nrow(register),
    is.list(executions), length(executions) == nrow(register),
    is.list(period),
    is.null(since) || (is.list(since) && length(since) == nrow(register))
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
  rows[["data_motivo"]] <- ifelse(
    dated, "", ifelse(ambiguous, "log_ambiguo", "senza_sigillo")
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
  rownames(rows) <- NULL
  rows
}


#' Put each row in the report it belongs to
#'
#' A row belongs to **whoever created it**, as the creation log says, and not
#' to `requested_by`, which an import writes as it likes. The report goes to
#' the same person the round asks to approve a change. A person asked for by
#' two referents is in both reports, each with their own rows.
#'
#' Three items, of which phase 1 fills two:
#'
#' - **activated in the month**, one line per request, new or modified. It is
#'   information, and does not count among the things to look at;
#' - **no first sign-in**, one item per person, with every project of theirs:
#'   the requests of that person activated at least `report_grace_days()`
#'   before the reading and not expired, when Entra says nobody has entered the
#'   account (`report_first_access()`). The thirty days run from the later of
#'   two dates, in Italian time: the channel's first execution for the
#'   username the row names now (`report_person_since()`), and the birth of
#'   that account on Entra. A username corrected by a modification, or an
#'   account made again, is not dated by an activation that was somebody
#'   else's. The item carries the earliest of those dates among the person's
#'   requests, how many days and months of thirty days ago it was, and the
#'   dates of the earlier reports of the same referent that named the person;
#' - **no access for more than a year** is phase 2, and the mail says it was
#'   not checked.
#'
#' What has no referent to go to goes to IT, and to nobody else: a row whose
#' creator the log does not name, or whose creator Entra holds disabled, or
#' does not hold, or cannot say; a person whose account is disabled, missing,
#' without a creation date or that cannot otherwise be judged; a row the log
#' does not date. A disabled creator receives nothing.
#'
#' @param rows What `report_rows()` answered.
#' @param directory A directory frame, as `directory_users()` returns it.
#' @param period What `report_month()` answered.
#' @param previous The entries of the earlier months' ledgers, as
#'   `report_ledger_previous()` reads them.
#'
#' A referent whose people went to IT unjudged is told how many, in the
#' report itself: the principle of the all-clear, which must not cover an item
#' nobody measured. `non_giudicati` counts them, a person once: the people of
#' that referent the report could not judge, and those of the rows the log
#' does not date.
#'
#' @return A list with `referenti`, one report per referent named after them,
#'   each a list of `referente`, `attivati` (rows), `senza_primo_accesso`
#'   (people) and `non_giudicati` (a count); `it`, `NULL` when there is
#'   nothing for IT, otherwise a list of `senza_referente` (rows, with
#'   `motivo`), `non_giudicabili` (people, with `referente` and `motivo`) and
#'   `senza_data` (rows); and `senza_creatore`,
#'   how many rows have no referent to go to.
#'
#' @keywords internal
report_assemble <- function(rows, directory, period, previous = list()) {
  stopifnot(
    is.data.frame(rows), is.data.frame(directory), is.list(period),
    is.list(previous)
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
  born <- vapply(username, function(upn) {
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
  start <- ifelse(nzchar(since), pmax(since, born), "")

  days <- rep(NA_integer_, nrow(rows))
  dated <- nzchar(start)
  days[dated] <- as.integer(today - as.Date(substr(start[dated], 1L, 10L)))
  judged <- own & !report_expired(text("expiration"), today) &
    !is.na(days) & days >= report_grace_days()

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

  reported <- function(who, key) {
    dates <- unlist(lapply(previous, function(entry) {
      same <- identical(
        tolower(trimws(as.character(entry[["destinatario"]] %||% ""))),
        tolower(who)
      )
      named <- key %in% tolower(trimws(as.character(
        entry[["senza_primo_accesso"]] %||% character()
      )))
      if (same && named) substr(as.character(entry[["at"]]), 1L, 10L)
    }))
    sort(unique(as.character(dates)))
  }

  referenti <- list()
  non_giudicabili <- list()

  for (who in unique(creator[own])) {
    mine <- own & creator == who

    attivati <- rows[mine & nzchar(text("nel_mese")), , drop = FALSE]
    attivati <- attivati[
      order(attivati[["attivata_il"]], attivati[["record_id"]]), ,
      drop = FALSE
    ]
    rownames(attivati) <- NULL

    people <- list()
    candidates <- which(mine & judged)
    keys <- tolower(username[candidates])
    for (key in unique(keys)) {
      at <- candidates[keys == key]
      at <- at[order(start[at])]
      oldest <- at[[1L]]
      person <- list(
        nome = trimws(paste(
          text("first_name")[[oldest]], text("last_name")[[oldest]]
        )),
        upn = username[[oldest]],
        progetti = projects(at)
      )
      verdict <- report_first_access(directory, username[[oldest]])
      if (identical(verdict, "mai_entrata")) {
        people[[length(people) + 1L]] <- c(person, list(
          attivata_il = substr(start[[oldest]], 1L, 10L),
          giorni = days[[oldest]],
          mesi = days[[oldest]] %/% 30L,
          segnalata = reported(who, key)
        ))
      } else if (!identical(verdict, "entrata")) {
        non_giudicabili[[length(non_giudicabili) + 1L]] <- c(person, list(
          referente = who, motivo = verdict
        ))
      }
    }

    referenti[[who]] <- list(
      referente = who, attivati = attivati, senza_primo_accesso = people
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

  for_it <- nrow(senza_referente) + length(non_giudicabili) + nrow(senza_data)
  it <- if (for_it > 0L) {
    list(
      senza_referente = senza_referente,
      non_giudicabili = non_giudicabili,
      senza_data = senza_data
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
  identity <- value("identity")

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
    ifelse(identity == "created", "Account nuovo.",
           ifelse(identity == "existing", "Account gia' esistente.", ""))
  )
  tail_en <- ifelse(
    modified, "Request modified and applied again this month.",
    ifelse(identity == "created", "New account.",
           ifelse(identity == "existing", "Existing account.", ""))
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
#' @param people The `senza_primo_accesso` of a referent's report.
#' @param unjudged How many of the referent's people went to IT unjudged.
#'
#' @return A list of two character vectors, `it` and `en`.
#'
#' @keywords internal
report_people_lines <- function(people, unjudged = 0L) {
  grace <- report_grace_days()

  each <- lapply(people, function(person) {
    projects <- report_projects_words(person[["progetti"]])
    months <- as.integer(person[["mesi"]])
    earlier <- as.character(person[["segnalata"]] %||% character())
    who <- paste0("   - ", person[["nome"]], ", ", person[["upn"]], ": ")
    list(
      it = c(
        paste0(
          who, "attivata il ", person[["attivata_il"]], ", ",
          person[["giorni"]], " giorni fa; senza primo accesso da ", months,
          if (months == 1L) " mese." else " mesi."
        ),
        paste0(
          "     ", projects[["it"]], ". ",
          if (length(earlier) == 0L) {
            "Prima segnalazione."
          } else {
            paste0(
              "Segnalata anche ", report_join(paste("il", earlier), "e"), "."
            )
          }
        )
      ),
      en = c(
        paste0(
          who, "activated on ", person[["attivata_il"]], ", ",
          person[["giorni"]], " days ago; no first sign-in for ", months,
          if (months == 1L) " month." else " months."
        ),
        paste0(
          "     ", projects[["en"]], ". ",
          if (length(earlier) == 0L) {
            "First report."
          } else {
            paste0("Also reported on ", report_join(earlier, "and"), ".")
          }
        )
      )
    )
  })

  list(
    it = c(
      paste0(
        "1. Senza primo accesso dopo ", grace, " giorni (", length(people),
        ")"
      ),
      paste0(
        "   Hanno l'accesso da almeno ", grace, " giorni e non sono ancora ",
        "entrate con l'account UBEP."
      ),
      unlist(lapply(each, `[[`, "it")),
      if (unjudged > 0L) {
        paste0("   Persone non giudicabili, segnalate a IT: ", unjudged, ".")
      },
      paste0(
        "   Che cosa fare: chiedi alla persona se ha ricevuto il benvenuto e ",
        "la chiave che le hai mandato. Se la chiave e' persa, scrivi a IT: ",
        "la reimposta e la rimanda a te. Se l'accesso non serve piu', metti ",
        "la richiesta a revoked."
      )
    ),
    en = c(
      paste0(
        "1. No first sign-in after ", grace, " days (", length(people), ")"
      ),
      paste0(
        "   They have had access for at least ", grace, " days and have not ",
        "signed in with the UBEP account yet."
      ),
      unlist(lapply(each, `[[`, "en")),
      if (unjudged > 0L) {
        paste0(
          "   People that could not be judged, reported to IT: ", unjudged, "."
        )
      },
      paste0(
        "   What to do: ask the person whether they received the welcome and ",
        "the key you sent them. If the key is lost, write to IT: they reset ",
        "it and send it back to you. If the access is no longer needed, set ",
        "the request to revoked."
      )
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
#' shows in a list of mail without opening anything: `Tutto in ordine` when
#' there is nobody to look at, `N da guardare` otherwise. The mail is plain
#' text, so the verdict is said again on the first line of the body, in
#' capitals. N counts the people listed in full in the items to look at, and
#' not the accesses activated, which are information; in the form to review
#' the anomalies come first and the information after.
#'
#' The year without access is not measured in phase 1, and the mail says so
#' in both forms: an all-clear that covered an item nobody looked at would
#' say something false. For the same reason the people of the referent that
#' went to IT unjudged are counted in a line of their own, which changes
#' neither the verdict nor the number in the subject: those say what was
#' measured.
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
  count <- length(people)
  unjudged <- as.integer(report[["non_giudicati"]] %||% 0L)
  month <- report_month_words(period[["mese"]])
  following <- report_day_words(period[["prossimo"]])
  grace <- report_grace_days()
  activated <- report_activated_lines(report[["attivati"]])
  read <- report_read_words(period)

  if (count == 0L) {
    verdict <- c(it = "Tutto in ordine", en = "All clear")
    items <- list(
      it = c(
        paste0(
          "Persone senza primo accesso dopo ", grace, " giorni: nessuna."
        ),
        if (unjudged > 0L) {
          paste0("Persone non giudicabili, segnalate a IT: ", unjudged, ".")
        },
        "Persone senza accessi da piu' di un anno: non ancora controllato."
      ),
      en = c(
        paste0("People with no first sign-in after ", grace, " days: none."),
        if (unjudged > 0L) {
          paste0(
            "People that could not be judged, reported to IT: ", unjudged, "."
          )
        },
        "People with no access in more than a year: not checked yet."
      )
    )
  } else {
    verdict <- c(
      it = paste(count, "da guardare"), en = paste(count, "to review")
    )
    listed <- report_people_lines(people, unjudged)
    items <- list(
      it = c(
        listed[["it"]], "",
        "2. Senza accessi da piu' di un anno: non ancora controllato."
      ),
      en = c(
        listed[["en"]], "",
        "2. No access in more than a year: not checked yet."
      )
    )
  }

  it <- c(
    toupper(verdict[["it"]]),
    "",
    paste0(
      "Rapporto mensile sulle richieste di accesso a REDCap create da te. ",
      "Mese: ", month[["it"]], "."
    ),
    "",
    items[["it"]],
    "",
    activated[["it"]],
    "",
    paste0(read[["it"]], " Prossimo rapporto: ", following[["it"]], "."),
    "Per domande rispondi a questo messaggio: la risposta arriva a IT."
  )

  en <- c(
    toupper(verdict[["en"]]),
    "",
    paste0(
      "Monthly report on the REDCap access requests you created. ",
      "Month: ", month[["en"]], "."
    ),
    "",
    items[["en"]],
    "",
    activated[["en"]],
    "",
    paste0(read[["en"]], " Next report: ", following[["en"]], "."),
    "For questions, reply to this message: the reply reaches IT."
  )

  list(
    subject = paste0(
      verdict[["it"]], ": accessi REDCap, ", month[["it"]], " / ",
      verdict[["en"]], ": REDCap access, ", month[["en"]]
    ),
    body = paste(c(it, "", "---", "", en), collapse = "\n"),
    forma = if (count == 0L) "in_ordine" else "da_guardare",
    n = count
  )
}


#' Compose the monthly mail to IT
#'
#' One mail, and only when there is something in it: the rows with no
#' referent to send them to, the people the report cannot judge, the rows the
#' log does not date. It has the referents' form to review, and its number
#' counts the rows and people listed. A section with nothing in it is not
#' announced.
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
    creator <- value(orphans, "creator")
    reason <- value(orphans, "motivo")
    because <- list(
      it = ifelse(
        reason == "non_stabilito",
        "Il registro degli eventi non dice chi l'ha creata.",
        paste0("Chi l'ha creata, ", creator, ", ", ifelse(
          reason == "disabilitato", "ha l'account disabilitato su Entra.",
          ifelse(
            reason == "non_trovato", "non risulta su Entra.",
            "ha un account il cui stato non si legge su Entra."
          )
        ))
      ),
      en = ifelse(
        reason == "non_stabilito",
        "The event log does not say who created it.",
        paste0("Its creator, ", creator, ", ", ifelse(
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
    # Two different things to look for: a seal nobody wrote, or a seal written
    # by two accounts, of which only one can be the channel.
    ambiguous <- value(undated, "data_motivo") == "log_ambiguo"
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
            ambiguous,
            paste0(
              "Nel registro degli eventi i campi del canale li scrive piu' ",
              "di un account, e non si sa quale abbia eseguito la riga."
            ),
            paste0(
              "Il registro degli eventi non porta la scrittura del sigillo ",
              "da parte del canale."
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
            ambiguous,
            paste0(
              "In the event log the channel's fields are written by more ",
              "than one account, and which one executed the row is not known."
            ),
            "The event log carries no seal written by the channel."
          ),
          " Referent: ", ifelse(nzchar(creator), creator, "not established"),
          "."
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
    paste(count, "DA GUARDARE"),
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
    paste(count, "TO REVIEW"),
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
      count, " da guardare: rapporto REDCap per IT, ", month[["it"]], " / ",
      count, " to review: REDCap report for IT, ", month[["en"]]
    ),
    body = paste(c(it_body, "", "---", "", en_body), collapse = "\n"),
    forma = "da_guardare",
    n = count
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
#'   `destinatario`, `at` and `senza_primo_accesso`.
#'
#' @keywords internal
report_ledger_read <- function(dir, month, collaudo = FALSE) {
  stopifnot(
    is.character(dir), length(dir) == 1L, nzchar(dir),
    is.character(month), length(month) == 1L
  )

  path <- report_ledger_path(dir, month, collaudo)
  if (!file.exists(path)) {
    return(list(ok = TRUE, errors = character(), invii = list()))
  }

  unreadable <- list(
    ok = FALSE, errors = "RAPPORTO_INVII_ILLEGGIBILI", invii = list()
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
      senza_primo_accesso = as.character(unlist(entry[["senza_primo_accesso"]]))
    )
  })
  if (!all(nzchar(vapply(invii, `[[`, "", "destinatario")))) {
    return(unreadable)
  }

  list(ok = TRUE, errors = character(), invii = invii)
}


#' Read the ledgers of the months before this one
#'
#' @inheritParams report_ledger_read
#'
#' @return A list with `ok`, `errors` and `invii`, the entries of every
#'   earlier month together, oldest month first.
#'
#' @keywords internal
report_ledger_previous <- function(dir, month) {
  stopifnot(is.character(dir), length(dir) == 1L, nzchar(dir))

  if (!dir.exists(dir)) {
    return(list(ok = TRUE, errors = character(), invii = list()))
  }

  months <- sub(
    "[.]json$", "",
    list.files(dir, pattern = "^[0-9]{4}-[0-9]{2}[.]json$")
  )
  earlier <- sort(months[months < month])
  readings <- lapply(earlier, function(m) report_ledger_read(dir, m))

  list(
    ok = all(vapply(readings, `[[`, TRUE, "ok")),
    errors = unique(as.character(unlist(lapply(readings, `[[`, "errors")))),
    invii = unlist(lapply(readings, `[[`, "invii"), recursive = FALSE) %||%
      list()
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
#' @param ledger The ledger as read, from `report_ledger_read()`.
#' @param entry A list of `destinatario`, `at` and `senza_primo_accesso`.
#'
#' @return A list with `ok`, `errors` and `ledger`, the ledger with the entry
#'   when it was written and as it was otherwise.
#'
#' @keywords internal
report_ledger_add <- function(dir, month, ledger, entry, collaudo = FALSE) {
  stopifnot(is.list(ledger), is.list(entry))

  invii <- c(ledger[["invii"]], list(list(
    destinatario = as.character(entry[["destinatario"]]),
    at = as.character(entry[["at"]]),
    senza_primo_accesso = as.character(entry[["senza_primo_accesso"]])
  )))

  # `I()` keeps a list of one address an array, and a list of none `[]`: the
  # reader takes both back as they were.
  json <- jsonlite::toJSON(
    list(
      mese = month,
      invii = lapply(invii, function(e) {
        list(
          destinatario = e[["destinatario"]], at = e[["at"]],
          senza_primo_accesso = I(e[["senza_primo_accesso"]])
        )
      })
    ),
    auto_unbox = TRUE, pretty = TRUE
  )

  if (!report_write_json(report_ledger_path(dir, month, collaudo), json)) {
    return(list(
      ok = FALSE, errors = "RAPPORTO_INVII_NON_SCRITTI", ledger = ledger
    ))
  }

  list(
    ok = TRUE, errors = character(),
    ledger = list(ok = TRUE, errors = character(), invii = invii)
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


#' Run the monthly report once
#'
#' **It reads and sends mail, and nothing else.** It does not write in the
#' register and does not touch Entra: the register is read with the channel's
#' token, the creations and each active row's log with the same calls the
#' round makes, the tenant with the round's sweep. That is what lets it run
#' outside the channel's path, as a job of its own.
#'
#' The job runs every day, because an alarm on logs looks back two days at
#' most and a monthly job cannot be watched by the absence of a record. Every
#' day it reads, computes and leaves a record; from the 1st on it sends the
#' previous month's report to whoever has not received it yet, until the
#' month is complete. The ledger of what left (`report_ledger_read()`) is what
#' tells them apart.
#'
#' A day on which anything it needs could not be read sends nothing: the
#' register, the creations, the directory, any active row's log, the ledgers.
#' A report composed on half a reading would be wrong for somebody, and the
#' next day tries again. Such a day also does not know who is due, so it
#' judges the month on the reports the last whole reading found due, kept
#' beside the ledger (`report_due_read()`); with none on record it says
#' nothing is due, and the alarm on absence is the one that speaks.
#'
#' **The real ledger is written only by a real run**: the post on, nobody
#' redirected, the month the clock gives. A run with the post off sends
#' nothing to record. A redirected run is a field test: recorded in the real
#' ledger, it would make the real month read as sent, and a test at the end
#' of October would leave nothing to leave on the 1st of November. So it keeps
#' a ledger of its own, and is idempotent as the real run is: the timer of a
#' field test does not send everything again every day. A run with a forced
#' month writes nothing at all.
#'
#' The report to IT goes to `copy_to`, the address IT is in copy at on every
#' outcome, under the name `report_it_key()`; the referents' reports go to the
#' creator's account, with `copy_to` in copy.
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
#'
#' @return A list that `report_record()` turns into the record, plus
#'   `rapporti`, one row per report due, for whoever reads a single run.
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
                                copy_to = NULL) {
  stopifnot(
    is.character(graph_token), length(graph_token) == 1L,
    is.character(graph_url), length(graph_url) == 1L,
    is.character(ledger_dir), length(ledger_dir) == 1L, nzchar(ledger_dir),
    is.null(mailer) || is.function(mailer)
  )

  period <- report_month(now, month)
  errors <- character()

  # A redirected run on the real month reads and writes a ledger of its own.
  test_run <- !is.null(redirect_to) && !isTRUE(period[["forzato"]])
  ledger <- report_ledger_read(ledger_dir, period[["mese"]], test_run)
  previous <- report_ledger_previous(ledger_dir, period[["mese"]])
  errors <- c(errors, ledger[["errors"]], previous[["errors"]])

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
  logs_read <- TRUE

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

    # One call per active row, and no window: the first execution can be
    # months old. Today that is one call; past five hundred rows it is worth
    # looking at again.
    executions <- rep(list(NULL), nrow(register))
    since <- rep(list(NULL), nrow(register))
    active <- field("request_status") == "active" &
      field("outcome") == "applied"
    for (i in which(active)) {
      answer <- register_log(register_url, register_token, record = ids[[i]])
      if (isTRUE(answer[["ok"]])) {
        executions[i] <- list(report_executions(answer[["log"]], ids[[i]]))
        since[i] <- list(report_person_since(answer[["log"]], ids[[i]]))
      } else {
        logs_read <- FALSE
        errors <- c(errors, answer[["errors"]])
      }
    }

    rows <- report_rows(register, creators, executions, period, since)
    assembled <- report_assemble(
      rows, sweep[["users"]], period, previous[["invii"]]
    )
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

  complete <- read_whole && isTRUE(ledger[["ok"]]) && isTRUE(previous[["ok"]])
  keeps_ledger <- !is.null(mailer) && !isTRUE(period[["forzato"]])

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
        named <- if (for_it) {
          character()
        } else {
          vapply(
            assembled[["referenti"]][[who]][["senza_primo_accesso"]],
            `[[`, "", "upn"
          )
        }
        written <- report_ledger_add(
          ledger_dir, period[["mese"]], ledger,
          list(
            destinatario = who, at = period[["letto"]],
            senza_primo_accesso = named
          ),
          collaudo = test_run
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
    senza_creatore = as.integer(assembled[["senza_creatore"]]),
    rapporti = data.frame(
      destinatario = due,
      forma = form_of,
      voci = count_of,
      esito = ifelse(
        due %in% sent, "mandato",
        ifelse(due %in% already, "gia_mandato",
               ifelse(due %in% failed, "fallito", "non_mandato"))
      ),
      stringsAsFactors = FALSE
    ),
    errori = unique(errors)
  )
}


#' Whether the month's reports are late
#'
#' From the second day of the month on, with the month not complete. Computed
#' here and not in the query of the alarm, so that a test covers it. A forced
#' run speaks about another month and cannot say the real one is late: it
#' says false, and the next run of the timer says the truth.
#'
#' @param giorno The day of the month the run is in, in Rome.
#' @param completo Whether every report of the month has left.
#' @param forzato Whether the month was forced.
#'
#' @return One logical.
#'
#' @keywords internal
report_late <- function(giorno, completo, forzato) {
  !isTRUE(forzato) && giorno >= 2L && !isTRUE(completo)
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
#' `gia_mandati + mandati == referenti`, on those. A day that cannot read
#' judges the month on the last whole reading, so a reading that fails after
#' the month was sent does not make it late; with no whole reading on record
#' nothing is due, and the month is not called late on a guess.
#' `in_ritardo` is `report_late()`.
#'
#' Phase 1 asks no instance and does not measure the year without access, so
#' `istanze_non_lette` and `voci_senza_accessi` are zero.
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

  referenti <- length(union(due, already))
  completo <- length(already) + length(sent) == referenti

  list(
    at = as.character(esito[["at"]]),
    mese = as.character(esito[["mese"]]),
    giorno_di_invio = length(esito[["pendenti"]]) > 0L,
    registro_letto = isTRUE(esito[["registro_letto"]]),
    directory_letta = isTRUE(esito[["directory_letta"]]),
    istanze_non_lette = 0L,
    posta = isTRUE(posta),
    posta_dirottata = isTRUE(esito[["posta_dirottata"]]),
    referenti = referenti,
    mandati = length(sent),
    gia_mandati = length(already),
    falliti = length(esito[["falliti"]]),
    in_ordine = sum(forms == "in_ordine"),
    da_guardare = sum(forms == "da_guardare"),
    voci_attivati = as.integer(esito[["voci_attivati"]] %||% 0L),
    voci_senza_primo_accesso =
      as.integer(esito[["voci_senza_primo_accesso"]] %||% 0L),
    voci_senza_accessi = 0L,
    senza_creatore = as.integer(esito[["senza_creatore"]] %||% 0L),
    mese_completo = completo,
    in_ritardo = report_late(
      esito[["giorno"]], completo, esito[["forzato"]]
    ),
    errori = as.character(esito[["errori"]] %||% character())
  )
}
