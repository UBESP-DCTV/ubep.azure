#' The suppression lists of the mail service
#'
#' SendGrid keeps five lists of addresses per user. Four of them **suppress**:
#' a send to an address on them answers 202 and does not leave, so the
#' channel counts as delivered a message nobody receives. The fifth,
#' *Blocks*, does not: measured on 2026-11-10, a block does not stop the next
#' send, which may get through. So the four are judged as a state (the
#' address is on the list today) and *Blocks* only as an event (an entry
#' created in the last hours).
#'
#' One list for the reader, the matcher and the mail to IT, so the path the
#' API is asked on and the name the console shows cannot drift apart.
#'
#' @return A data frame with `lista`, the path under `/v3/suppression/` and
#'   the name the code uses; `nome`, the name the console shows; and
#'   `sopprime`, whether a send to an address on it is dropped.
#'
#' @keywords internal
suppression_lists <- function() {
  data.frame(
    lista = c(
      "bounces", "blocks", "spam_reports", "invalid_emails", "unsubscribes"
    ),
    nome = c(
      "Bounces", "Blocks", "Spam Reports", "Invalid Emails",
      "Global Unsubscribes"
    ),
    sopprime = c(TRUE, FALSE, TRUE, TRUE, TRUE),
    stringsAsFactors = FALSE
  )
}


#' Read the suppression lists of the mail service, whole
#'
#' **It only reads.** A `GET` on each of the five lists of
#' `suppression_lists()`, page by page, with a key whose only rights are
#' those reads: no `/mail/send`, no `DELETE`. Taking an address off a list is
#' a gesture IT makes by hand in the console, after correcting what made it
#' bounce (decided on 2026-11-12). A guard in `test-runner-guardie.R` holds
#' this function to that.
#'
#' The key goes in the `Authorization` header and nowhere else, as in
#' `mail_send()`. A failure is an outcome and not an exception, with the
#' service's own words on the standard error, which is the journal of the
#' unit: on 2026-08-27 the same refusal by IP Access Management answered 403
#' on one endpoint and 401 on another.
#'
#' Each request waits thirty seconds at most, and a time out is a failure
#' like any other: the reading comes before the report, and must not hold it.
#'
#' The first failure stops the reading: a list read in part is not a list
#' read, and nothing that follows would change that. A failure on the first
#' page of a list is `TRASPORTO_SOPPRESSIONI_NON_LEGGIBILI` (the network, a
#' key refused or revoked, an address not admitted); a failure on a later
#' page, or a list that never ends, is `TRASPORTO_SOPPRESSIONI_INCOMPLETE`.
#' The list ends at the first page that comes back empty, and not at the
#' first shorter than `limit`: the ceiling per page is the documentation's
#' and not measured, and a service that hands back fewer entries than asked
#' would otherwise close the list after its first page with the reading said
#' whole. One request more per list, five a day. The next page starts after
#' the entries received, not after `limit`. A list that reaches `max_pages`
#' without an empty page is a reading that failed, not a list cut short.
#'
#' The parameters `limit` and `offset`, the ceiling of 500 entries per page
#' and the shape of an entry (`email`, `created` in seconds since the epoch,
#' `reason` where the list has one) are those of SendGrid's documentation of
#' the v3 API as read on 2026-11-12, not yet measured: the first reading on
#' the machine says whether the service agrees.
#'
#' @param api_key The read-only key, which the runner reads from Key Vault.
#' @param limit Entries per page.
#' @param max_pages Pages per list, the empty one included, past which the
#'   list is taken as one that never ends. Bounces held a few hundred entries
#'   in November 2026: 200 pages are 100.000 entries at 500 a page, 20.000 at
#'   100.
#'
#' @return A list with `ok`, `errors` and `voci`, a data frame of `lista`,
#'   `email`, `creata` (POSIXct, UTC) and `motivo`, every entry of the five
#'   lists when `ok`, none otherwise.
#'
#' @keywords internal
suppression_read <- function(api_key, limit = 500L, max_pages = 200L) {
  stopifnot(
    is.character(api_key), length(api_key) == 1L, nzchar(api_key),
    is.numeric(limit), length(limit) == 1L, limit >= 1L,
    is.numeric(max_pages), length(max_pages) == 1L, max_pages >= 1L
  )

  none <- suppression_entries()
  failed <- function(code) {
    list(ok = FALSE, errors = code, voci = none)
  }

  read <- list()
  for (list_name in suppression_lists()[["lista"]]) {
    offset <- 0L
    page <- 0L
    repeat {
      page <- page + 1L
      code <- if (page == 1L) {
        "TRASPORTO_SOPPRESSIONI_NON_LEGGIBILI"
      } else {
        "TRASPORTO_SOPPRESSIONI_INCOMPLETE"
      }
      if (page > max_pages) {
        message(
          "Le soppressioni non finiscono: ", list_name, " ha piu' di ",
          max_pages, " pagine."
        )
        return(failed("TRASPORTO_SOPPRESSIONI_INCOMPLETE"))
      }

      response <- tryCatch(
        httr2::request(
          paste0("https://api.sendgrid.com/v3/suppression/", list_name)
        ) |>
          httr2::req_method("GET") |>
          httr2::req_url_query(limit = limit, offset = offset) |>
          httr2::req_headers(Authorization = paste("Bearer", api_key)) |>
          # The reading comes before the report, in a oneshot unit with no
          # start timeout: a service that takes the connection and does not
          # answer would hold the report and its record for good. A page of
          # 500 entries is a few tens of kilobytes, answered in about a
          # second; thirty seconds is that with a wide margin, and a page
          # that takes longer fails the reading like any other failure.
          httr2::req_timeout(30) |>
          httr2::req_error(is_error = function(resp) FALSE) |>
          httr2::req_perform(),
        error = function(e) {
          message(
            "Le soppressioni non si leggono (", list_name, ", pagina ", page,
            "): ", conditionMessage(e)
          )
          NULL
        }
      )
      if (is.null(response)) {
        return(failed(code))
      }

      if (!identical(httr2::resp_status(response), 200L)) {
        said <- tryCatch(
          httr2::resp_body_string(response),
          error = function(e) ""
        )
        message(
          "Le soppressioni non si leggono (", list_name, ", pagina ", page,
          ", HTTP ", httr2::resp_status(response), "): ",
          if (nzchar(said)) {
            substr(gsub("[[:space:]]+", " ", said), 1L, 500L)
          } else {
            "nessun corpo nella risposta"
          }
        )
        return(failed(code))
      }

      entries <- tryCatch(
        httr2::resp_body_json(response, simplifyVector = FALSE),
        error = function(e) NULL
      )
      # An array, possibly empty, and nothing else: an object here is an
      # answer of another shape, and reading it as no entries would say the
      # list is empty.
      if (!is.list(entries) || !is.null(names(entries))) {
        message(
          "Le soppressioni non si leggono (", list_name, ", pagina ", page,
          "): la risposta non e' un elenco."
        )
        return(failed(code))
      }

      if (length(entries) == 0L) {
        break
      }
      read[[length(read) + 1L]] <- suppression_entries(entries, list_name)
      offset <- offset + length(entries)
    }
  }

  voci <- do.call(rbind, c(list(none), read))
  rownames(voci) <- NULL
  list(ok = TRUE, errors = character(), voci = voci)
}


#' Turn the entries of one page into rows
#'
#' @param entries The parsed array, a list of one list per entry.
#' @param list_name The list they come from.
#'
#' @return A data frame of `lista`, `email`, `creata` and `motivo`; with no
#'   arguments, the empty one.
#'
#' @keywords internal
suppression_entries <- function(entries = list(), list_name = character()) {
  text <- function(entry, field) {
    value <- entry[[field]]
    if (is.null(value) || length(value) != 1L || is.na(value)) {
      return("")
    }
    as.character(value)
  }
  created <- vapply(entries, function(entry) {
    value <- entry[["created"]]
    if (is.numeric(value) && length(value) == 1L) as.numeric(value) else NA
  }, numeric(1))

  data.frame(
    lista = rep(list_name, length(entries)),
    email = vapply(entries, text, "", field = "email"),
    creata = as.POSIXct(created, origin = "1970-01-01", tz = "UTC"),
    motivo = vapply(entries, text, "", field = "reason"),
    stringsAsFactors = FALSE
  )
}


#' The addresses of the channel that a suppression would silence
#'
#' Three classes, as the design of 2026-11-12 names them:
#'
#' - `casella_it`: the address of IT (`UBEP_POSTA_COPIA`), in copy on every
#'   outcome and the recipient of what has nowhere else to go. It does not
#'   depend on the register and is there whenever the address is;
#' - `referente`: whom the channel sends keys, outcomes and reports to, the
#'   owners of the rows that are not revoked. A superset that asks for no
#'   reading of its own: the owner the log names today (`log_owner()`) where
#'   the report read the row's log, plus `owned_by` and the creator
#'   (`log_creators()`) of every `active` row. One address too many costs at
#'   most a notice on an address that works with the register;
#' - `recapito`: where the channel writes to the person of each `active`
#'   row. The recipients of the access message as the round computes them,
#'   with the same function (`mail_access_recipients()`, fed by
#'   `directory_mailboxes()` on the row's `username`), so that a correction of
#'   those recipients holds here without touching this code; plus
#'   *Contact e-mail* when the channel created the account (`identity`
#'   `created`), the only case in which the welcome went there. An internal
#'   contact on an account the channel did not create is the UPN, and the
#'   channel no longer writes to it.
#'
#' The IT approvers are not here: they are REDCap usernames the channel never
#' writes to. Nor is the address replies reach, which a reply leaves from
#' the program of whoever replies, nor `requested_by`, which the channel does
#' not write to.
#'
#' @param register The register as read, or `NULL` when it was not read.
#' @param creators,owners As long as the register: who created each row
#'   (`log_creators()`), and its owner as the log names it today, `""` or
#'   `NA` where it does not.
#' @param directory The directory frame, or `NULL` when it was not read.
#' @param copy_to The address of IT, or `NULL`.
#' @param domain The tenant's verified domain, as `identity_internal()` takes
#'   it.
#'
#' @return A list with `destinatari`, a data frame of `indirizzo` (as
#'   written), `classe` and `record_id` (`""` for the address of IT), and
#'   `classi`, the classes that could be computed: `casella_it` with an
#'   address of IT, the other two with the register and the directory read.
#'
#' @keywords internal
suppression_recipients <- function(register, creators, owners, directory,
                                   copy_to, domain = "ubep.unipd.it") {
  stopifnot(
    is.null(register) || is.data.frame(register),
    is.null(directory) || is.data.frame(directory),
    is.null(copy_to) || (is.character(copy_to) && length(copy_to) == 1L)
  )

  rows <- list()
  add <- function(address, class, record) {
    address <- trimws(as.character(address))
    keep <- !is.na(address) & nzchar(address)
    if (any(keep)) {
      rows[[length(rows) + 1L]] <<- data.frame(
        indirizzo = address[keep], classe = class,
        record_id = rep(record, length.out = length(address))[keep],
        stringsAsFactors = FALSE
      )
    }
  }

  classes <- character()
  if (!is.null(copy_to) && !is.na(copy_to) && nzchar(trimws(copy_to))) {
    classes <- "casella_it"
    add(copy_to, "casella_it", "")
  }

  if (!is.null(register) && !is.null(directory)) {
    stopifnot(
      length(creators) == nrow(register), length(owners) == nrow(register)
    )
    classes <- c(classes, "referente", "recapito")
    field <- function(name) {
      value <- register[[name]]
      if (is.null(value)) {
        return(rep("", nrow(register)))
      }
      value <- trimws(as.character(value))
      value[is.na(value)] <- ""
      value
    }
    ids <- field("record_id")
    active <- field("request_status") == "active"
    owners <- as.character(owners)
    owners[is.na(owners)] <- ""

    for (i in which(active)) {
      add(
        c(owners[[i]], field("owned_by")[[i]], as.character(creators[[i]])),
        "referente", ids[[i]]
      )
    }

    if (any(active)) {
      mailboxes <- directory_mailboxes(
        directory, field("username")[active], domain = domain
      )
      for (k in seq_len(sum(active))) {
        i <- which(active)[[k]]
        row <- as.list(register[i, , drop = FALSE])
        row[["mailbox"]] <- mailboxes[["mailbox"]][[k]]
        row[["external"]] <- mailboxes[["external"]][[k]]
        welcome <- if (identical(field("identity")[[i]], "created")) {
          field("contact_email")[[i]]
        }
        add(
          c(mail_access_recipients(row, domain = domain), welcome),
          "recapito", ids[[i]]
        )
      }
    }
  }

  destinatari <- do.call(rbind, c(
    list(data.frame(
      indirizzo = character(), classe = character(), record_id = character(),
      stringsAsFactors = FALSE
    )),
    rows
  ))
  destinatari <- destinatari[!duplicated(data.frame(
    tolower(destinatari[["indirizzo"]]), destinatari[["classe"]],
    destinatari[["record_id"]]
  )), , drop = FALSE]
  rownames(destinatari) <- NULL

  list(destinatari = destinatari, classi = classes)
}


#' Cross the suppression lists with the channel's recipients
#'
#' Addresses compare without case and without blanks at the edges. The four
#' lists that suppress are a state, any entry whatever its age; *Blocks* is
#' an event. So is `soppressi_recapiti_nuovi`, the recipients with an entry
#' that is new: created in the 24 hours before the last cut, `cut` UTC, the
#' time the job's timer starts, at or before `now`. The window is aligned to
#' the timer and not to the moment of the run, which comes up to five minutes
#' later (`RandomizedDelaySec=300`): an entry made between the cut and the run
#' counts the next day, and every entry counts on one day only, with no
#' overlap and no gap between two runs of the timer. A run by hand on the same
#' day counts the same window. A day with no run at all (the machine off
#' from before one cut to after the next) loses its entries as news; one of
#' the four lists stays in the state counts and in the mail to IT.
#'
#' Counts and nothing else for the record, which a workspace keeps and others
#' read: never an address, and no hash of one, which on a known domain is
#' reversed by dictionary. The addresses are in `dettaglio`, which the
#' runner writes to the standard error, the unit's journal.
#'
#' `NA` is "not computed", not zero. With the lists not read every count is
#' `NA`. With the lists read, the address of IT is judged whenever there is
#' one, and the rest only with the register and the directory read;
#' `bloccati_nuovi` counts the three classes, so it needs all of them read
#' that can be. `soppressioni_lette` is the lists read whole and the register
#' and the directory read.
#'
#' @param reading What `suppression_read()` answered, or `NULL` when nothing
#'   was read.
#' @param recipients What `suppression_recipients()` answered.
#' @param now The moment the run reads.
#' @param cut The time of day, `"%H:%M"` in UTC, at which the job's timer
#'   starts (`OnCalendar=*-*-* 06:30:00 UTC`). If the timer moves, this moves
#'   with it.
#'
#' @return A list with `soppressioni_lette`, `soppressa_casella_it`,
#'   `soppressi_referenti`, `soppressi_recapiti`, `soppressi_recapiti_nuovi`,
#'   `bloccati_nuovi`, and `dettaglio`, a data frame of `lista`, `classe`,
#'   `record_id` (the rows of the address, separated by commas), `creata`
#'   (UTC, to the minute), `motivo` (the service's reason, on one line and
#'   cut) and `indirizzo`: one row per address, class and entry that counts.
#'
#' @keywords internal
suppression_match <- function(reading, recipients, now, cut = "06:30") {
  stopifnot(
    is.null(reading) || is.list(reading),
    is.list(recipients), is.data.frame(recipients[["destinatari"]]),
    inherits(now, "POSIXct"),
    is.character(cut), length(cut) == 1L,
    grepl("^[0-2][0-9]:[0-5][0-9]$", cut)
  )

  # The last cut at or before `now`, and the day before it.
  until <- as.POSIXct(
    paste(format(now, "%Y-%m-%d", tz = "UTC"), cut), tz = "UTC"
  )
  if (until > now) {
    until <- until - 86400
  }
  since <- until - 86400
  is_new <- function(at) !is.na(at) & at >= since & at < until

  detail <- data.frame(
    lista = character(), classe = character(), record_id = character(),
    creata = character(), motivo = character(), indirizzo = character(),
    stringsAsFactors = FALSE
  )
  classes <- recipients[["classi"]] %||% character()
  read <- !is.null(reading) && isTRUE(reading[["ok"]])
  whole <- read && all(c("referente", "recapito") %in% classes)

  answer <- list(
    soppressioni_lette = whole,
    soppressa_casella_it = NA,
    soppressi_referenti = NA_integer_,
    soppressi_recapiti = NA_integer_,
    soppressi_recapiti_nuovi = NA_integer_,
    bloccati_nuovi = NA_integer_,
    dettaglio = detail
  )
  if (!read) {
    return(answer)
  }

  lists <- suppression_lists()
  entries <- reading[["voci"]]
  key <- function(x) tolower(trimws(as.character(x)))
  entries[["chiave"]] <- key(entries[["email"]])
  entries <- entries[nzchar(entries[["chiave"]]), , drop = FALSE]
  silencing <- entries[["lista"]] %in% lists[["lista"]][lists[["sopprime"]]]
  fresh <- is_new(entries[["creata"]])
  blocked <- entries[["lista"]] %in% lists[["lista"]][!lists[["sopprime"]]]
  counted <- entries[silencing | (blocked & fresh), , drop = FALSE]

  people <- recipients[["destinatari"]]
  people[["chiave"]] <- key(people[["indirizzo"]])
  people <- people[people[["classe"]] %in% classes, , drop = FALSE]

  hits <- merge(
    people, counted, by = "chiave", sort = FALSE,
    suffixes = c("", ".voce")
  )
  hit_silencing <- hits[["lista"]] %in% lists[["lista"]][lists[["sopprime"]]]
  hit_fresh <- is_new(hits[["creata"]])

  distinct <- function(class, also = TRUE) {
    as.integer(length(unique(
      hits[["chiave"]][hits[["classe"]] == class & hit_silencing & also]
    )))
  }

  if ("casella_it" %in% classes) {
    answer[["soppressa_casella_it"]] <- distinct("casella_it") > 0L
  }
  if (whole) {
    answer[["soppressi_referenti"]] <- distinct("referente")
    answer[["soppressi_recapiti"]] <- distinct("recapito")
    answer[["soppressi_recapiti_nuovi"]] <- distinct("recapito", hit_fresh)
    answer[["bloccati_nuovi"]] <- as.integer(length(unique(
      hits[["chiave"]][!hit_silencing]
    )))
  }

  if (nrow(hits) > 0L) {
    reason <- substr(gsub("[[:space:]]+", " ", trimws(hits[["motivo"]])), 1L,
                     160L)
    when <- format(hits[["creata"]], "%Y-%m-%d %H:%M", tz = "UTC")
    when[is.na(when)] <- ""
    group <- paste(
      hits[["lista"]], hits[["classe"]], hits[["chiave"]], when, sep = "\r"
    )
    first <- !duplicated(group)
    rows <- vapply(group[first], function(g) {
      ids <- unique(hits[["record_id"]][group == g])
      paste(ids[nzchar(ids)], collapse = ",")
    }, "", USE.NAMES = FALSE)
    detail <- data.frame(
      lista = hits[["lista"]][first], classe = hits[["classe"]][first],
      record_id = rows, creata = when[first], motivo = reason[first],
      indirizzo = hits[["indirizzo"]][first], stringsAsFactors = FALSE
    )
    detail <- detail[order(
      match(detail[["classe"]], c("casella_it", "referente", "recapito")),
      detail[["indirizzo"]], detail[["lista"]]
    ), , drop = FALSE]
    rownames(detail) <- NULL
  }
  answer[["dettaglio"]] <- detail
  answer
}
