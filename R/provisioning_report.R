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
#' Thirty, counted on the calendar in Rome: a request activated on the 2nd is
#' in the report of the 1st of the month after. Every person has between 30
#' and 61 days before their first mention.
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
#' round already holds. `lastPasswordChangeDateTime` is, in Learn's words,
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
