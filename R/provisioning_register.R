#' Read the request register's data dictionary
#'
#' The dictionary is the schema, and it lives as a file rather than as R code
#' because REDCap imports it as it is: one artifact, two consumers.
#'
#' Sixteen of its seventeen fields are exactly that. The seventeenth is not:
#' the choices of `server` are the fleet, a piece of operating data that
#' changes when the machines change rather than when the contract does. Kept in
#' the file, it coupled a release of this package to every movement of the
#' fleet, and published the list in a public repository. So the packaged file
#' is a **template** with that one cell empty, and the caller supplies the list.
#'
#' The template is deliberately not importable: REDCap refuses a `radio` with
#' no choices, so the template cannot be imported by mistake in place of the
#' real dictionary. A recognizable placeholder would have been importable, and
#' would have produced a project carrying one invented choice — a file that
#' looks like it worked costs more than one that refuses to.
#'
#' @param instances Character vector of instance names, or `NULL` for the
#'   template. A zero-length vector is refused rather than treated as `NULL`:
#'   `NULL` means "I am not passing it", while `character(0)` asserts that the
#'   fleet is empty, and the two must not reach the same result by opposite
#'   routes. Empty or missing names are refused for the same reason — they
#'   would become the choice `", "` inside a dictionary that looks sound.
#'
#' @return A data frame with the eighteen columns of a REDCap data dictionary.
#'
#' @keywords internal
register_dictionary <- function(instances = NULL) {
  path <- system.file(
    "extdata", "request-register-dictionary.csv",
    package = "ubep.azure"
  )
  dictionary <- readr::read_csv(path, show_col_types = FALSE)

  if (is.null(instances)) {
    return(dictionary)
  }

  if (!is.character(instances) || length(instances) == 0L ||
        anyNA(instances) || !all(nzchar(instances))) {
    stop(
      "register_dictionary(): `instances` must be a non-empty character ",
      "vector with no missing or empty names.",
      call. = FALSE
    )
  }

  row <- dictionary[["Variable / Field Name"]] == "server"
  dictionary[["Choices, Calculations, OR Slider Labels"]][row] <-
    paste0(instances, ", ", instances, collapse = " | ")

  dictionary
}


#' Split a REDCap choice string into codes and labels
#'
#' Choices travel as `"code, label | code, label"`, and only the **first** comma
#' separates the two: a label may carry commas of its own.
#'
#' @param text One cell of the dictionary's choices column.
#'
#' @return A data frame with `code` and `label`.
#'
#' @keywords internal
dictionary_choices <- function(text) {
  items <- trimws(strsplit(as.character(text), "|", fixed = TRUE)[[1]])
  items <- items[nzchar(items)]

  data.frame(
    code = trimws(sub("^([^,]*),.*$", "\\1", items)),
    label = trimws(sub("^[^,]*,\\s*", "", items)),
    stringsAsFactors = FALSE
  )
}


#' The register fields only the job writes
#'
#' Marked `@READONLY` in the dictionary, which governs the form and not the
#' API: the job keeps writing them while a requester cannot. Without the tag a
#' requester could type `applied` into the outcome, and the register would carry
#' a success nobody produced.
#'
#' `owned_by` is written by the channel alone, and its value is not believed
#' as written: who owns a row is read from the event log (`log_owner()`).
#'
#' @return A character vector of field names.
#'
#' @keywords internal
register_readonly_fields <- function() {
  c(
    "identity", "requested_by", "owned_by", "outcome", "outcome_detail",
    "outcome_at", "applied_as", "applied_seal", "seal_state"
  )
}


#' The fields the seal does not cover
#'
#' Every read-only field, plus the one a person writes that must still stay out
#' of the seal.
#'
#' The two lists were the same until row protection needed them apart, and the
#' reason they were the same is worth keeping: a field the channel writes is a
#' field a requester must not, and a field the channel writes must not move the
#' seal, or the round would accuse itself one pass after every write.
#'
#' `approved_seal` breaks that coincidence. It carries the seal it approves, so
#' if writing it moved the seal it would never match the row it was written
#' for — the comparison would chase itself and no change could ever be
#' approved. But a person writes it, so it cannot be `@READONLY`, and
#' `register_readonly_fields()` is also what the dictionary test checks the
#' tags against. Two questions, two lists.
#'
#' @return A character vector of field names.
#'
#' @keywords internal
register_unsealed_fields <- function() {
  c(register_readonly_fields(), "approved_seal")
}


#' The fields only the channel writes
#'
#' Every read-only field but `requested_by`, which `@USERNAME` fills in with
#' the account that creates the row: it is the one read-only field a person
#' writes. The rest are `@READONLY` on the form, and only the round is meant
#' to write them.
#'
#' Meant, and not guaranteed. `@READONLY` governs the form REDCap draws, and
#' an import draws none: the import right is open to the referents, and an
#' import writes these fields as it writes any other. So a write of one of
#' them does not say by itself that the round made it. The account that holds
#' the round's token is configured, `channel_account`, and
#' `log_channel_accounts()` reads these fields to find any other account that
#' wrote them, which makes the row's log ambiguous.
#'
#' @return A character vector of field names.
#'
#' @keywords internal
register_channel_fields <- function() {
  setdiff(register_readonly_fields(), "requested_by")
}


#' The fields a row carries because somebody asked for them
#'
#' Derived and not listed: everything in the dictionary the seal has to cover.
#' A field added to the dictionary joins this set on its own, which is the
#' property that keeps the seal honest — a hand-picked list would silently
#' stop covering the column somebody added last week.
#'
#' @return A character vector of field names, in dictionary order.
#'
#' @keywords internal
register_intent_fields <- function() {
  setdiff(
    register_dictionary()[["Variable / Field Name"]],
    register_unsealed_fields()
  )
}


#' What the round applied, in twelve characters
#'
#' The seal the round writes beside a row once it has acted on it, and what the
#' next round compares the row against: a different seal means the row was
#' modified after it was applied.
#'
#' It covers the intent fields and nothing else, and that is the whole point.
#' A seal that moved when the round wrote the outcome would make every applied
#' row look modified one round later — the mechanism would accuse itself, on
#' every row, for ever.
#'
#' A field the register does not carry is sealed as empty rather than skipped,
#' so a row exported with a column missing and the same row with that column
#' blank seal alike. The absence itself is not lost: `compare_dictionary()`
#' reports it as `DIZIONARIO_CAMPO_ASSENTE`, which is where it belongs.
#'
#' Twelve hex characters, like the surface fingerprint, and for the same
#' reason: it goes in a text field a person may read aloud.
#'
#' @param register The register as read, one row per request.
#'
#' @return A character vector, one seal per row.
#'
#' @keywords internal
request_seal <- function(register) {
  stopifnot(is.data.frame(register))

  fields <- register_intent_fields()
  values <- lapply(fields, function(field) {
    if (is.null(register[[field]])) {
      rep("", nrow(register))
    } else {
      value <- trimws(as.character(register[[field]]))
      value[is.na(value)] <- ""
      value
    }
  })

  # `\r` and not a comma: the separator has to be a character no register value
  # can contain, or two different rows could join into the same string --
  # role_name "a" with dag "b,c" against role_name "a,b" with dag "c".
  joined <- do.call(paste, c(values, list(sep = "\r")))

  substr(as.character(openssl::sha256(joined)), 1L, 12L)
}


#' The closed vocabulary of what the round thinks of a row
#'
#' Named here for the reason `outcome_vocabulary()` is: the CSV holds a copy,
#' and a word added to one and not the other is a value the live project
#' refuses to store or one the package never emits. The dictionary test walks
#' both.
#'
#' @return A character vector of the three states.
#'
#' @keywords internal
seal_state_vocabulary <- function() {
  c("intact", "modified", "approved")
}


#' Build the body that writes a seal back into the register
#'
#' A third door beside the outcome and the identity, and it exists for the
#' reason those two are separate rather than for a new one: the columns are
#' fixed here so a bug cannot rewrite anything else.
#'
#' It could not be a column of `outcome_payload()`, and the reason is worth
#' keeping. That body is written on every outcome, so a seal column would carry
#' a value on every outcome too — and the honest default is empty. A
#' `data_error` on an already applied row would then blank the seal, quietly
#' taking the protection off the one kind of row that has any.
#'
#' @param record_id The register record to write to.
#' @param seal The seal of what was applied, `""` when nothing was.
#' @param state One of `seal_state_vocabulary()`.
#'
#' @return A one-row data frame with exactly the seal columns.
#'
#' @keywords internal
seal_payload <- function(record_id, seal, state) {
  stopifnot(
    is.character(record_id), length(record_id) == 1L,
    is.character(seal), length(seal) == 1L,
    is.character(state), length(state) == 1L,
    state %in% seal_state_vocabulary()
  )

  data.frame(
    record_id = record_id,
    applied_seal = seal,
    seal_state = state,
    stringsAsFactors = FALSE
  )
}


#' Build the body that writes the row owner into the register
#'
#' A fourth door beside the outcome, the identity and the seal, with the same
#' reason: the columns are fixed here so a bug cannot rewrite anything else.
#' The owner is the referent a row belongs to after its last approved change,
#' and it is written apart from the seal and from the outcome because it is
#' neither: a body that also carried them could move a seal or restate what
#' the round did while only meaning to say whose the row is.
#'
#' An empty or missing owner is refused rather than written. The register
#' reads an empty `owned_by` as "whoever created the row", so writing one would
#' erase a decision with something that looks like an absence.
#'
#' @param record_id The register record to write to.
#' @param owner The owner's address, never empty.
#'
#' @return A one-row data frame with exactly `record_id` and `owned_by`.
#'
#' @keywords internal
owner_payload <- function(record_id, owner) {
  stopifnot(
    is.character(record_id), length(record_id) == 1L,
    is.character(owner), length(owner) == 1L,
    !is.na(owner), nzchar(trimws(owner))
  )

  data.frame(
    record_id = record_id,
    owned_by = owner,
    stringsAsFactors = FALSE
  )
}


#' Who last wrote one of these fields on this row
#'
#' Reads `details`, which REDCap fills with the fields an edit touched and the
#' values it gave them — `role_name = 'read only'` — so the question "who
#' changed what was asked" is answerable without holding a copy of the row.
#'
#' The most recent matching event wins, and which one that is comes from the
#' **order of the answer** rather than from the timestamp: REDCap stamps the
#' log to the minute, and an edit and the approval that follows it can easily
#' share one. The order is REDCap's own, newest first.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param record The record id to look at.
#' @param fields Field names to look for in `details`.
#'
#' @return The username, or `""` when no event touched any of those fields.
#'
#' @keywords internal
log_last_author <- function(events, record, fields) {
  stopifnot(is.data.frame(events), is.character(fields))

  mine <- log_of_record(events, record)
  if (nrow(mine) == 0L || length(fields) == 0L) {
    return("")
  }

  hit <- log_wrote(mine, fields)
  if (!any(hit)) {
    return("")
  }

  trimws(as.character(mine[["username"]][which(hit)[[1L]]]))
}


#' The events of the row that stands now under a record id
#'
#' The rows of the log that belong to `record`, in the order REDCap gave
#' them, and of those only the current life of the row, `log_current_life()`.
#' Every reader of a row's log comes through here (who changed the row, who
#' approved it, which account is the channel), so none of them reads the
#' history of an earlier row that had the same id. REDCap reuses the ids of
#' deleted records: the register was emptied on 2026-09-01, and the first
#' request filed after it took id 1, which had been a field test's.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param record The record id.
#'
#' @return The rows of `events` that belong to `record`, from its newest
#'   creation on.
#'
#' @keywords internal
log_of_record <- function(events, record) {
  mine <- events[
    trimws(as.character(events[["record"]])) == as.character(record), ,
    drop = FALSE
  ]
  log_current_life(mine)
}


#' The events of the row that stands now, without those of an earlier one
#'
#' A record id can be used twice: deleted, and made again by somebody else for
#' another request. The log keeps both lives under the same `record`, and
#' everything below the newest creation belongs to a row that no longer
#' exists. The creation itself is the first event of the row that stands now,
#' and stays: a row with one life is answered whole, as before the cut.
#'
#' Which event is newest comes from the order of the answer, REDCap's own,
#' newest first, as for `log_creators()`, which names as the creator the
#' author of this same event; the stamps are to the minute, and two lives can
#' share one. The creation is read as `log_creators()` reads it, from the
#' start of `action`, whose wording was measured on 2026-09-02. Read as a
#' guard, a wording that does not match cuts nothing, and the log is read
#' whole as before; `log_creators()` then names nobody, and the round holds
#' the row.
#'
#' Only the creation cuts, and not the deletion, whose wording was never
#' measured. Nothing is lost by it, since the deletion of an earlier life
#' stands below the creation of the current one. And an event that only
#' reads like a deletion, inside the current life, would cut that life's own
#' changes in the direction that grants: below it may stand a change by
#' somebody else, which the round would then carry out with nobody asked.
#'
#' Read by `log_of_record()`, so by every reader of a row's log.
#'
#' @param events The events of one record, newest first.
#'
#' @return The events from the newest creation on, or all of them when there
#'   is none.
#'
#' @keywords internal
log_current_life <- function(events) {
  stopifnot(is.data.frame(events))

  said <- trimws(as.character(events[["action"]]))
  born <- which(startsWith(said, "Create record"))
  if (length(born) == 0L) {
    return(events)
  }
  events[seq_len(born[[1L]]), , drop = FALSE]
}


#' Which events wrote one of these fields
#'
#' Reads `details`, which REDCap fills with the fields an event wrote and the
#' values it gave them, `role_name = 'read only'`.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param fields Field names to look for.
#'
#' @return A logical vector, one answer per event.
#'
#' @keywords internal
log_wrote <- function(events, fields) {
  if (length(fields) == 0L || nrow(events) == 0L) {
    return(logical(nrow(events)))
  }
  # `\b` and `=` together: without the word boundary `seal_state` would match
  # inside nothing, but `name` would match inside `role_name`, and the answer
  # would be an author who touched a different field.
  pattern <- paste0("\\b(", paste(fields, collapse = "|"), ")\\s*=")
  grepl(pattern, as.character(events[["details"]]))
}


#' Which accounts in a row's log are the channel
#'
#' The account that holds the round's token, as the machine that runs the
#' round configures it, followed by every other account that wrote a field
#' only the channel is meant to write, `register_channel_fields()`, in the
#' row's current life. Callers read the answer one way: longer than one, and
#' the log cannot say which writes are the round's, so the row is held.
#'
#' It has to be recognized by the account and not by the event. REDCap logs
#' only the fields an import changed, so when the round writes back a username
#' it resolved and the verdict has not moved, the event carries `username`
#' alone -- an intent field, written by the channel, with nothing in the event
#' itself to say so.
#'
#' The account is configured, decided on 2026-10-17. Recognized by what it
#' writes alone, the channel is whoever wrote a channel field, and the import
#' right is open to the referents: one who imports `owned_by` on a colleague's
#' new row, before the round has written on it, would be the only "channel"
#' of that row. Named by the configuration, the round's account answers first
#' even on a row where it has not written yet, and that referent comes second,
#' which makes the row ambiguous. A write of a channel field whose author is
#' blank or missing names nobody, and with the account configured it counts
#' among the others too, as a blank author of an intent field does for
#' `log_change_authors()`.
#'
#' One consequence is worth knowing: if the account that holds the token
#' changes, every row whose current life carries writes of the old account
#' becomes ambiguous, and the round holds it.
#'
#' The configured name is typed by hand on the machine, so it is compared
#' without regard to case, and answered with the spelling the log carries
#' when the log carries it. Without it, `NULL`, the answer is the authors of
#' the channel fields, as before the account was configured: what the round
#' judges does not change for a caller that does not pass it, and
#' `log_owner()` believes no write of `owned_by`.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param record The record id to look at.
#' @param channel_account The REDCap username that holds the round's token,
#'   or `NULL` when it is not configured.
#'
#' @return A character vector of usernames. With `channel_account`, it starts
#'   with that account and is one long when nobody else wrote a channel field.
#'   Without, it is empty when no event wrote one of those fields.
#'
#' @keywords internal
log_channel_accounts <- function(events, record, channel_account = NULL) {
  stopifnot(
    is.data.frame(events),
    is.null(channel_account) ||
      (is.character(channel_account) && length(channel_account) == 1L &&
         !is.na(channel_account) && nzchar(trimws(channel_account)))
  )

  mine <- log_of_record(events, record)
  authors <- trimws(as.character(mine[["username"]]))
  wrote <- log_wrote(mine, register_channel_fields())
  if (is.null(channel_account)) {
    return(unique(authors[wrote & nzchar(authors)]))
  }

  configured <- trimws(channel_account)
  logged <- authors[which(tolower(authors) == tolower(configured))]
  own <- if (length(logged) > 0L) logged[[1L]] else configured
  # A blank or missing author is not the configured account either: it stays
  # among the others, and the row is ambiguous.
  c(own, unique(authors[wrote & !tolower(authors) %in% tolower(configured)]))
}


#' Who was authenticated when each of these rows was created
#'
#' The answer the register's own fields cannot give. `requested_by` is filled
#' in by `@USERNAME`, and an action tag governs the form REDCap draws: an
#' import draws no form, so it writes into that field whatever it is handed.
#' Measured on 2026-09-02 on a live instance, an import creation logs
#' `username` as the account that was authenticated and carries the forged
#' name only inside `details`, where it is a string somebody chose rather than
#' a fact REDCap established.
#'
#' It answers from `record` and `username`, which is what keeps it apart from
#' `log_last_author()`. That one searches `details` for a field pattern
#' because it asks "who wrote this field"; this one asks "who made this row",
#' and the caller has already had REDCap answer only with creations.
#'
#' `action` is then read as a **guard and not as the mechanism**, and the
#' distinction is the whole of it. REDCap ignores a parameter it does not
#' know rather than refusing it, so a `logtype` it silently dropped would
#' come back as a complete log that looks exactly like a valid answer -- and
#' the newest event for a row would be whoever last edited it, not whoever
#' opened it. Reading the prose is a bad primary mechanism, because the same
#' act reads `Create record 7` from the form and `Create record (import) 20`
#' from an import. It is a sound guard because it fails **closed**: reword the
#' string and nothing matches, the answer is empty, and the caller holds the
#' row instead of judging it against the wrong person.
#'
#' The most recent event wins, and which one that is comes from the order of
#' the answer rather than from the timestamp -- REDCap's own, newest first,
#' the same rule `log_last_author()` follows. A record id normally carries one
#' creation; it can carry two when an id was deleted and made again, and then
#' the row that exists now is the one made last.
#'
#' @param events The creation events, as `register_log()` returns them when
#'   asked with `logtype = "record_add"`. Handing it a wider log would answer
#'   with whoever last touched the row instead of whoever made it.
#' @param records The record ids to answer about.
#'
#' @return A character vector as long as `records`, holding the username or
#'   `""` where no creation event names that row. `""` is not "nobody made
#'   it": it is "the log did not say", and the caller decides what that means.
#'
#' @keywords internal
log_creators <- function(events, records) {
  stopifnot(is.data.frame(events))

  made <- trimws(as.character(events[["record"]]))
  authors <- trimws(as.character(events[["username"]]))
  said <- trimws(as.character(events[["action"]]))
  opened <- startsWith(said, "Create record")

  vapply(as.character(records), function(record) {
    hit <- which(made == record & opened)
    if (length(hit) == 0L) "" else authors[[hit[[1L]]]]
  }, character(1), USE.NAMES = FALSE)
}


#' Whether each of these stamps reads as one of the log's
#'
#' REDCap writes its stamps `"%Y-%m-%d %H:%M"`, to the minute, in the
#' instance's civil time. A stamp that does not start that way cannot be
#' placed before or after anything, and every reader that dates by the log
#' answers "unknown" on it rather than comparing a string it cannot read.
#'
#' @param stamps The stamps, as the log's `timestamp` column carries them.
#'
#' @return A logical vector, one answer per stamp.
#'
#' @keywords internal
log_stamp_reads <- function(stamps) {
  grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}", stamps)
}


#' Who a row belongs to, from the log
#'
#' The value of the newest write of `owned_by` signed by the account that
#' holds the round's token, in the row's current life; the creator, as
#' `log_creators()` names it, when that account never wrote one.
#'
#' The field itself is not believed. `owned_by` is `@READONLY` on the form,
#' but an import draws no form: the import right is open to the referents,
#' and an import writes the field as it writes any other. The log names who
#' was authenticated for each write, so it says which value the round wrote,
#' the same principle that names the creator from the log and not from
#' `requested_by`.
#'
#' The round's account is configured, decided on 2026-10-17, and without it,
#' `NULL`, no write of `owned_by` is believed and the row belongs to its
#' creator. Recognizing the round by what it writes would hand the row to a
#' referent who imports `owned_by` alone on a colleague's new row before the
#' round has written on it; with the account configured, that referent makes
#' the row ambiguous, `log_channel_accounts()`, and the answer is unknown.
#' The ambiguity is read first, so a row whose log is ambiguous is unknown
#' with or without the configured account.
#'
#' `before` asks who the row belonged to at a moment, and only what stands
#' strictly before it counts. It is in the instance's civil time, which is
#' Rome, the time the log's stamps are in, as for `report_executions()`: no
#' conversion can move a write across it. A stamp of the row's log that does
#' not read as one, `log_stamp_reads()`, makes the answer unknown, since the
#' write it dates could stand on either side.
#'
#' The newest write is read from the order of the answer, REDCap's own,
#' newest first, as everywhere else in the log. A write by the channel that
#' leaves the field blank names nobody, and the one below it is read.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param record The record id to look at.
#' @param creator Who created the row, as `log_creators()` answers.
#' @param channel_account The REDCap username that holds the round's token,
#'   or `NULL` when it is not configured.
#' @param before A moment, `"%Y-%m-%d %H:%M"` in Rome and exactly that long,
#'   or `NULL` to read the whole log. A longer stamp, with seconds, would make
#'   a write of that same minute count as before it.
#'
#' @return One username; `""` when no write of `owned_by` is believed and the
#'   creator is not known; `NA_character_` when the log cannot say.
#'
#' @keywords internal
log_owner <- function(events, record, creator, channel_account = NULL,
                      before = NULL) {
  stopifnot(
    is.data.frame(events), is.character(creator), length(creator) == 1L,
    is.null(before) ||
      (is.character(before) && length(before) == 1L &&
         nchar(before) == 16L && isTRUE(log_stamp_reads(before)))
  )

  fallback <- if (is.na(creator)) "" else trimws(creator)
  mine <- log_of_record(events, record)
  channel <- log_channel_accounts(events, record, channel_account)
  if (length(channel) > 1L) {
    return(NA_character_)
  }
  if (is.null(channel_account)) {
    return(fallback)
  }

  if (!is.null(before)) {
    stamps <- trimws(as.character(mine[["timestamp"]]))
    if (!all(log_stamp_reads(stamps))) {
      return(NA_character_)
    }
    mine <- mine[substr(stamps, 1L, 16L) < before, , drop = FALSE]
  }

  authors <- trimws(as.character(mine[["username"]]))
  owners <- log_value(mine, "owned_by")
  passed <- which(
    log_wrote(mine, "owned_by") & authors == channel[[1L]] & nzchar(owners)
  )
  if (length(passed) == 0L) {
    return(fallback)
  }
  owners[[passed[[1L]]]]
}


#' Who changed a row since the round last applied it
#'
#' The people whose writes to an intent field stand between the round's last
#' execution of the row and now, newest first. The last execution is the
#' newest event that wrote `applied_seal`, which only the round writes and
#' only when it has applied the row: what came before it was carried out
#' already, under somebody's responsibility, and is not the change the round
#' is now asked to carry out. Where the row's log no longer holds that event
#' the whole history counts, which can only ask for an approval more often.
#'
#' Only the writes still in the row count, decided on 2026-10-17 (option (a)
#' of three). For each intent field whose current value differs from the one
#' carried out, the author is whoever wrote that field last; a write somebody
#' other than the channel then overwrote is not part of the change, and a
#' field brought back to the value carried out is no change at all. The value
#' carried out is the newest write of the field below the seal, by anybody,
#' the channel included; where the log holds none it is unknown, and the
#' field counts if it was written above the seal. The current value comes
#' from the register and not from the log, which cuts a value at its first
#' apostrophe and would call `D'Angelo` and `D'Amico` equal.
#'
#' On a row never carried out there is no value to compare with, and every
#' intent field written in its life counts, with its last author, empty or
#' not: an empty field decides what is granted too, an empty `dag_name` a user
#' in no group, an empty `expiration` an access with no end. The same holds
#' without the row in hand, `current = NULL`: every field written since the
#' last execution counts, with its last author.
#'
#' This is also the way out of a write by somebody who could not have made
#' it by hand: the owner writes that field again, and the other is no longer
#' its author. Without it a row touched by mistake would stay held for ever,
#' since nothing is ever deleted. REDCap logs no write that leaves the value
#' as it was, so writing again means changing the value and then putting it
#' back.
#'
#' "Carried out already" holds for what the round read, and the seal is
#' written at the end of the round: a change made while the round ran sits
#' below it and was not. `log_uncovered_authors()` looks for those, and
#' `log_pending_authors()` is the two together, which is what the round
#' judges.
#'
#' The round's own writes are not a change. It writes `username` back when it
#' resolves it, and `username` is an intent field: counted, the channel would
#' be an author of every row whose username it settles. Its account is the one
#' `log_channel_accounts()` names, and its events are dropped by account: a
#' field only the channel wrote since the last execution carries no author.
#'
#' Two cases make the answer unknown rather than short, and the caller holds
#' the row on both. A second account writing what only the channel is meant
#' to write is a referent's import, since the import right is open to them
#' and an import writes `@READONLY` fields too, or a value that happens to
#' read as a field assignment; taking it for the channel would drop its
#' author from the change. And a write that counts whose author is blank
#' names nobody, which is not the same as naming the creator.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param record The record id to look at.
#' @param fields The intent fields. Passed in by a caller that asks about
#'   many rows, since deriving them reads the packaged dictionary.
#' @param channel_account The REDCap username that holds the round's token,
#'   or `NULL` when it is not configured, for `log_channel_accounts()`.
#' @param current The row as the round will leave it, a data frame of one
#'   row holding every field in `fields`, or `NULL` when there is no row in
#'   hand. Read only on a row the round has carried out.
#'
#' @return A character vector of usernames, newest first (by the write that
#'   counts) and each once; `character()` when no intent field changed, or
#'   nobody but the channel changed one; `NA_character_` when the log cannot
#'   say who did.
#'
#' @keywords internal
log_change_authors <- function(events, record,
                               fields = register_intent_fields(),
                               channel_account = NULL, current = NULL) {
  stopifnot(
    is.data.frame(events), is.character(fields),
    is.null(current) ||
      (is.data.frame(current) && nrow(current) == 1L &&
         all(fields %in% names(current)))
  )

  mine <- log_of_record(events, record)
  channel <- log_channel_accounts(events, record, channel_account)
  if (length(channel) > 1L) {
    return(NA_character_)
  }

  # Newest first, which is REDCap's order: what stands above the newest write
  # of the seal happened after the round last applied the row, what stands
  # below it is what the round carried out.
  rows <- seq_len(nrow(mine))
  executed <- which(log_wrote(mine, "applied_seal"))
  sealed <- length(executed) > 0L
  window <- if (sealed) rows < executed[[1L]] else rep(TRUE, nrow(mine))
  below <- if (sealed) rows > executed[[1L]] else rep(FALSE, nrow(mine))

  authors <- trimws(as.character(mine[["username"]]))
  theirs <- window & !authors %in% channel

  now <- function(field) {
    value <- trimws(as.character(current[[field]][[1L]]))
    if (is.na(value)) "" else value
  }
  counts <- function(field, wrote) {
    # A row never carried out has no value to compare with: what was written
    # counts, an emptied field included, since it decides what is granted.
    if (is.null(current) || !sealed) {
      return(any(wrote & window))
    }
    done <- which(wrote & below)
    if (length(done) == 0L) {
      # The value carried out is not in the log: the field counts as it did
      # before the row was compared, if somebody wrote it since.
      return(any(wrote & window))
    }
    now(field) != log_value(mine[done[[1L]], , drop = FALSE], field)
  }

  last <- vapply(fields, function(field) {
    wrote <- log_wrote(mine, field)
    hit <- which(wrote & theirs)
    if (length(hit) == 0L || !counts(field, wrote)) NA_integer_ else hit[[1L]]
  }, integer(1), USE.NAMES = FALSE)
  last <- sort(unique(last[!is.na(last)]))

  if (any(is.na(authors[last]) | !nzchar(authors[last]))) {
    return(NA_character_)
  }

  unique(authors[last])
}


#' The value each event wrote into one field
#'
#' Reads `details`, `applied_seal = '0a1b2c3d4e5f'`. Meant for the seals, which
#' are twelve hex characters and so never hold the quote that would end the
#' value early.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param field One field name.
#'
#' @return A character vector, one value per event, `""` where the event did
#'   not write the field.
#'
#' @keywords internal
log_value <- function(events, field) {
  stopifnot(is.character(field), length(field) == 1L)

  details <- as.character(events[["details"]])
  pattern <- paste0("\\b", field, "\\s*=\\s*'([^']*)'")
  found <- regmatches(details, regexec(pattern, details))
  vapply(found, function(hit) {
    if (length(hit) < 2L) "" else trimws(hit[[2L]])
  }, character(1))
}


#' Whether each of these authors may approve a row
#'
#' Whoever owns the row, `log_owner()`, or one of the IT accounts. The owner
#' is compared as REDCap logs it, which is the same source on both sides. The
#' IT list is typed by hand on the machine, so it is compared without regard
#' to case: a capital letter must not void an approval by IT in silence. A
#' blank name approves nothing, whatever the list holds.
#'
#' @param authors Usernames, as the log carries them.
#' @param owner Who owns the row, as `log_owner()` answers.
#' @param approvers The IT accounts whose approval counts on any row.
#'
#' @return A logical vector, one answer per author.
#'
#' @keywords internal
log_approver <- function(authors, owner, approvers = character()) {
  authors <- trimws(as.character(authors))
  it <- tolower(setdiff(trimws(approvers), ""))
  nzchar(authors) &
    (authors == trimws(owner) | tolower(authors) %in% it)
}


#' Who changed a row before its last execution without the owner's leave
#'
#' `log_change_authors()` drops what stands below the round's newest seal as
#' already carried out. That holds for what the round **read**, and the seal is
#' written last: an edit somebody makes while the round sweeps the tenant and
#' talks to the instances lands below the seal in the log and was never
#' applied. Dropped with the rest, it would pass for the owner's as soon as
#' the owner edits the row again.
#'
#' So the stretch between the newest seal and the one before it (or the start
#' of the row's log, its creation when the log holds it) is read again, for
#' changes by anybody other than whoever owned the row in that stretch.
#' The round applies such a change only once the owner has approved it, so
#' one that the round did carry out has the owner's approval above it in
#' that stretch, carrying the very seal the execution wrote. A change with no
#' such approval above it is one the execution did not cover, and it is still
#' part of the change the round is being asked to carry out.
#'
#' **The stretch is read with the owner of then**, decided on 2026-10-17: the
#' newest write of `owned_by` by the channel below the seal that opens the
#' stretch, `log_owner()`, or the creator when there is none or only one seal.
#' The round that writes a seal writes `owned_by` below it, so the passage it
#' decided belongs to the stretch after it. Read with today's owner instead,
#' the approval of the one before would be a stranger's after a passage, and
#' the row would be held again with no new change in it.
#'
#' One write is judged with today's owner as well: one that stands above the
#' newest approval that covers, written while the round that passes the row
#' ran, after the approval and before the seal. The outgoing owner who writes
#' there is not the new owner, and nobody else would name the change, since
#' below the seal `log_change_authors()` reads it as the value carried out.
#' So a write above that approval counts when its author is not the owner of
#' then or not the owner of today, `log_owner()` on the whole log.
#'
#' One stretch is enough. An uncovered change makes the next round hold the
#' row, and a held row writes no seal: the stretch does not move until the
#' owner approves, and that approval covers the version holding the change.
#'
#' Two kinds of leave besides the owner's, both from 2026-10-15. An approval
#' by one of the IT accounts covers as the owner's does, since it is what
#' carried the change out. And a revocation alone, `request_status =
#' 'revoked'` and no other intent field, is never uncovered: it grants
#' nothing, so whether or not the execution above it carried it out, nothing
#' in it can reach anybody through the owner's next edit. Counted, it would
#' make the owner approve the reactivation of their own request after a
#' manager's free revocation.
#'
#' Unknown, `NA_character_`, when the owner of the stretch is not known, when
#' two accounts write the channel's fields, or when an uncovered change has a
#' blank author: the caller holds the row on all three.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param record The record id to look at.
#' @param creator Who created the row, as `log_creators()` answers; the owners
#'   are read from the log with it.
#' @param fields The intent fields.
#' @param approvers The IT accounts whose approval counts on any row.
#' @param channel_account The REDCap username that holds the round's token,
#'   or `NULL` when it is not configured, for `log_channel_accounts()` and
#'   `log_owner()`.
#'
#' @return A character vector of usernames, newest first and each once;
#'   `character()` when the stretch holds no uncovered change or the log holds
#'   no seal at all; `NA_character_` when the log cannot say.
#'
#' @keywords internal
log_uncovered_authors <- function(events, record, creator,
                                  fields = register_intent_fields(),
                                  approvers = character(),
                                  channel_account = NULL) {
  stopifnot(
    is.data.frame(events), is.character(creator), length(creator) == 1L,
    is.character(fields), is.character(approvers)
  )

  mine <- log_of_record(events, record)
  channel <- log_channel_accounts(events, record, channel_account)
  if (length(channel) > 1L) {
    return(NA_character_)
  }
  executed <- which(log_wrote(mine, "applied_seal"))
  if (length(executed) == 0L) {
    return(character())
  }

  # Newest first: the stretch is what stands below the newest seal and above
  # the one before it.
  rows <- seq_len(nrow(mine))
  last <- if (length(executed) > 1L) executed[[2L]] else nrow(mine) + 1L
  stretch <- mine[rows > executed[[1L]] & rows < last, , drop = FALSE]
  sealed <- log_value(mine[executed[[1L]], , drop = FALSE], "applied_seal")

  # The owner of the stretch is read below the seal that opens it, where the
  # round that wrote that seal wrote owned_by too; with one seal, nothing
  # stands below the stretch and the row is its creator's.
  older <- mine[rows > last, , drop = FALSE]
  owner <- log_owner(older, record, creator, channel_account)
  if (is.na(owner) || !nzchar(owner)) {
    return(NA_character_)
  }

  # Who owns the row now, past the passage the newest seal's round wrote.
  now <- log_owner(mine, record, creator, channel_account)
  if (is.na(now)) {
    now <- ""
  }

  authors <- trimws(as.character(stretch[["username"]]))
  withdrawal <- log_value(stretch, "request_status") == "revoked" &
    !log_wrote(stretch, setdiff(fields, "request_status"))
  leave <- which(
    log_wrote(stretch, "approved_seal") &
      log_approver(authors, owner, approvers) &
      log_value(stretch, "approved_seal") == sealed & nzchar(sealed)
  )
  # Above the newest approval stands what the round wrote the seal over: a
  # write there by the owner of then is not the new owner's, and nobody
  # else names it, since below the seal it reads as the value carried out.
  above <- if (length(leave) > 0L) {
    seq_len(nrow(stretch)) < min(leave)
  } else {
    rep(FALSE, nrow(stretch))
  }
  foreign <- which(
    log_wrote(stretch, fields) & !authors %in% channel & !withdrawal &
      (authors != owner | (above & authors != now))
  )
  # Covered is below an approval; what stands above the newest one is not.
  if (length(leave) > 0L) {
    foreign <- foreign[foreign < min(leave)]
  }
  if (any(!nzchar(authors[foreign]))) {
    return(NA_character_)
  }

  unique(authors[foreign])
}


#' Who has a hand in the version the round is asked to carry out
#'
#' The changes since the round's last execution, `log_change_authors()`, and
#' the changes below it that the execution did not cover,
#' `log_uncovered_authors()`. What `change_needs_approval()` judges, and what
#' the held message names.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param record The record id to look at.
#' @param creator Who created the row, as `log_creators()` answers.
#' @param fields The intent fields.
#' @param approvers The IT accounts whose approval counts on any row.
#' @param channel_account The REDCap username that holds the round's token,
#'   or `NULL` when it is not configured, for `log_channel_accounts()`.
#' @param current The row as the round will leave it, a data frame of one
#'   row, or `NULL` when there is no row in hand, for `log_change_authors()`.
#'
#' @return A character vector of usernames, each once; `NA_character_` when
#'   either half cannot say.
#'
#' @keywords internal
log_pending_authors <- function(events, record, creator,
                                fields = register_intent_fields(),
                                approvers = character(),
                                channel_account = NULL, current = NULL) {
  authors <- c(
    log_change_authors(
      events, record, fields,
      channel_account = channel_account, current = current
    ),
    log_uncovered_authors(
      events, record, creator, fields, approvers, channel_account
    )
  )
  if (anyNA(authors)) {
    return(NA_character_)
  }

  unique(authors)
}


#' Whether a change to a request waits for an approval
#'
#' **The one place the rule lives**, decided on 2026-10-14. A request belongs
#' to whoever owns it, and the row answers to its owner: a change somebody
#' else had a hand in is carried out only once the owner, or IT, has approved
#' it. The owner is whoever created the row until the round passes it on:
#' since 2026-10-16 the row belongs to the last referent whose change was
#' approved and carried out, `log_owner()`. So:
#'
#' - a change made only by the owner is carried out on the next round, with
#'   nobody to ask;
#' - a change in which anybody else had a hand waits for the owner, even
#'   when the owner edited the row afterwards: a later edit does not say the
#'   owner saw the other one, and an approval is the act that does;
#' - a change whose authors or whose owner the log cannot establish waits
#'   too. "I could not establish who did this" is not "the owner did it".
#'
#' It holds whether or not the round has applied the row yet. The one
#' difference is what a log naming nobody means. On a row that carries a seal
#' the seal has already moved, so the row did change and nobody is on record
#' for it: it waits. On a row never applied there is no such evidence, and a
#' log that names nobody says nobody changed it.
#'
#' **A revocation is the one exception**, decided on 2026-10-15: somebody
#' else's withdrawal of the request does not wait when everybody other than
#' the owner who has a hand in it holds User Rights with Full Access on the
#' project. Taking an access away grants nothing, and whoever manages the
#' users of a project could have removed that person by hand -- the rule the
#' scope gate enforces, "nobody does through the channel what they could not
#' do by hand", holds as it is. What counts as a revocation is narrow on
#' purpose, `log_revocation_only()`: the row now asks for `revoked`, and what
#' the others wrote is that and nothing else. A withdrawal that also moves the
#' role, the person or the project is a change like any other.
#'
#' The rights come from the instance, and the round has them only once it has
#' asked it. So the round asks this question twice for a revocation: before
#' talking to the instance, with no managers, which holds it provisionally;
#' and at the gate, with the managers the instance reported, which decides.
#'
#' @param authors Who has a hand in the version the round would carry out,
#'   as `log_pending_authors()` answers.
#' @param owner Who owns the row, as `log_owner()` answers, with `""` where it
#'   answers `NA`.
#' @param sealed Whether the row carries the seal of an execution, whose
#'   mismatch is what says it changed.
#' @param revocation Whether the change is a revocation and nothing else: the
#'   row asks for `revoked` and `log_revocation_only()` holds.
#' @param managers Who holds User Rights with Full Access on the project the
#'   row names, as the instance reported it this round.
#'
#' @return `TRUE` when the change has to wait for the owner's approval.
#'
#' @keywords internal
change_needs_approval <- function(authors, owner, sealed = TRUE,
                                  revocation = FALSE,
                                  managers = character()) {
  stopifnot(
    is.character(authors), is.character(owner), length(owner) == 1L,
    is.logical(sealed), length(sealed) == 1L, !is.na(sealed),
    is.logical(revocation), length(revocation) == 1L, !is.na(revocation),
    is.character(managers)
  )

  owner <- trimws(owner)
  if (is.na(owner) || !nzchar(owner)) {
    return(TRUE)
  }
  if (anyNA(authors)) {
    return(TRUE)
  }
  if (length(authors) == 0L) {
    return(sealed)
  }
  others <- setdiff(trimws(authors), owner)
  if (length(others) == 0L) {
    return(FALSE)
  }
  !(revocation && all(others %in% trimws(managers)))
}


#' Whether what somebody other than the owner wrote is a revocation alone
#'
#' The half of the revocation exception that the log answers, for
#' `change_needs_approval()`. Since the round's last execution, every write to
#' an intent field by an account that is neither the owner nor the channel
#' wrote `request_status = 'revoked'` and no other intent field; and there is
#' at least one such write, or there is no withdrawal by somebody else to
#' free. The owner is the one the row has now, `log_owner()`: after a passage
#' the creator's withdrawal is somebody else's.
#'
#' A change below the newest execution that the execution did not cover,
#' `log_uncovered_authors()`, makes the answer `FALSE`. That stretch is the
#' rare case of an edit made while a round ran, and reading it for its fields
#' as well would buy nothing but code: the row waits for the owner, as it
#' would have before the exception existed.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param record The record id to look at.
#' @param creator Who created the row, as `log_creators()` answers; the owner
#'   is read from the log with it.
#' @param fields The intent fields.
#' @param approvers The IT accounts whose approval counts on any row.
#' @param channel_account The REDCap username that holds the round's token,
#'   or `NULL` when it is not configured, for `log_channel_accounts()` and
#'   `log_owner()`.
#'
#' @return `TRUE` when the others wrote a revocation and nothing else; `FALSE`
#'   too when the owner is not known.
#'
#' @keywords internal
log_revocation_only <- function(events, record, creator,
                                fields = register_intent_fields(),
                                approvers = character(),
                                channel_account = NULL) {
  stopifnot(
    is.data.frame(events), is.character(creator), length(creator) == 1L,
    is.character(fields), is.character(approvers)
  )

  owner <- log_owner(events, record, creator, channel_account)
  if (is.na(owner) || !nzchar(owner)) {
    return(FALSE)
  }
  uncovered <- log_uncovered_authors(
    events, record, creator, fields, approvers, channel_account
  )
  if (anyNA(uncovered) || length(uncovered) > 0L) {
    return(FALSE)
  }

  mine <- log_of_record(events, record)
  channel <- log_channel_accounts(events, record, channel_account)
  if (length(channel) > 1L) {
    return(FALSE)
  }
  executed <- which(log_wrote(mine, "applied_seal"))
  if (length(executed) > 0L) {
    mine <- mine[seq_len(executed[[1L]] - 1L), , drop = FALSE]
  }

  authors <- trimws(as.character(mine[["username"]]))
  others <- log_wrote(mine, fields) & !authors %in% channel &
    authors != owner
  if (!any(others)) {
    return(FALSE)
  }

  theirs <- mine[others, , drop = FALSE]
  all(log_value(theirs, "request_status") == "revoked") &&
    !any(log_wrote(theirs, setdiff(fields, "request_status")))
}


#' Who owns a row once the round has carried it out
#'
#' The owner after the execution of the version the log describes: the row
#' passes to the newest of the authors who count, `log_pending_authors()`,
#' which is the referent whose change the round is carrying out. IT included:
#' a change IT wrote and the round carried out makes IT the owner.
#'
#' The passage is decided once, by the round that carries the change out,
#' after the gate has let it through: what this function reads is a version
#' already approved, and it does not judge the approval again.
#'
#' The act is judged, not the path that led to it (decided on 2026-10-17). A
#' revocation does not move the row, whether it went through freely or was
#' approved: whoever wrote only `request_status = 'revoked'` and no other
#' intent field never becomes the owner, even when the version also holds
#' somebody else's change. The row passes to the newest of the other authors
#' who count, and stays with the owner of today when only withdrawals are
#' left.
#'
#' An author counts in two stretches, and is a withdrawal alone only when
#' every write of theirs that counts, in both, is one. Above the last
#' execution, every write of theirs is read, not only the ones still in the
#' row, as `log_revocation_only()` reads the others. Below it, an uncovered
#' change, `log_uncovered_authors()`, is never a withdrawal, which that
#' function leaves out: an author it names changed something the version
#' carried out holds, and can take the row, whatever they wrote above. So a
#' revocation above the execution over an uncovered change by somebody else
#' passes the row to that somebody, and over an uncovered change of their
#' own to its author.
#'
#' Without the channel's account, `channel_account = NULL`, no write of
#' `owned_by` is believed and no row passes: the answer is the one of
#' `log_owner()`, the creator, or unknown on a row whose channel the log
#' cannot tell.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param record The record id to look at.
#' @param creator Who created the row, as `log_creators()` answers.
#' @param fields The intent fields.
#' @param approvers The IT accounts whose approval counts on any row.
#' @param channel_account The REDCap username that holds the round's token,
#'   or `NULL` when it is not configured.
#' @param current The row as the round will leave it, a data frame of one
#'   row, or `NULL` when there is no row in hand, for `log_pending_authors()`.
#'
#' @return One username; `""` or `NA_character_` as `log_owner()` answers
#'   them, and `NA_character_` too when the log cannot say who the authors
#'   are.
#'
#' @keywords internal
log_next_owner <- function(events, record, creator,
                           fields = register_intent_fields(),
                           approvers = character(),
                           channel_account = NULL, current = NULL) {
  owner <- log_owner(events, record, creator, channel_account)
  if (is.na(owner) || !nzchar(owner) || is.null(channel_account)) {
    return(owner)
  }

  pending <- log_pending_authors(
    events, record, creator, fields, approvers,
    channel_account = channel_account, current = current
  )
  if (anyNA(pending)) {
    return(NA_character_)
  }
  if (length(pending) == 0L) {
    return(owner)
  }

  # An uncovered change below the last execution is never a withdrawal.
  uncovered <- log_uncovered_authors(
    events, record, creator, fields, approvers, channel_account
  )

  # Above the last execution, newest first; when there is none, the whole
  # life.
  mine <- log_of_record(events, record)
  executed <- which(log_wrote(mine, "applied_seal"))
  if (length(executed) > 0L) {
    mine <- mine[seq_len(executed[[1L]] - 1L), , drop = FALSE]
  }
  authors <- trimws(as.character(mine[["username"]]))
  wrote <- log_wrote(mine, fields)
  withdrew <- vapply(pending, function(who) {
    theirs <- mine[which(wrote & authors == who), , drop = FALSE]
    !who %in% uncovered && nrow(theirs) > 0L &&
      all(log_value(theirs, "request_status") == "revoked") &&
      !any(log_wrote(theirs, setdiff(fields, "request_status")))
  }, logical(1), USE.NAMES = FALSE)
  changed <- pending[!withdrew]
  if (length(changed) == 0L) {
    return(owner)
  }

  changed[[1L]]
}


#' Whether each changed row waits for an approval
#'
#' `change_needs_approval()` asked once per row, of the authors the row's log
#' names, `log_pending_authors()`, and of whoever owns the row, `log_owner()`,
#' read from the log with the creator the creation log names. Whether the row
#' carries a seal is read from its `applied_seal`, and the authors are read
#' against the row as it stands, so a field brought back to the value carried
#' out names nobody.
#'
#' @param register The register as read, one row per request, carrying every
#'   intent field.
#' @param events The event log of the rows that changed, as `register_log()`
#'   returns it.
#' @param creators Who created each row, as `log_creators()` answers, in the
#'   order of `register`.
#' @param approvers The IT accounts whose approval counts on any row: it
#'   decides what an earlier execution covered.
#' @param channel_account The REDCap username that holds the round's token,
#'   or `NULL` when it is not configured, for `log_channel_accounts()` and
#'   `log_owner()`.
#'
#' @return A logical vector, one answer per row. It answers about every row
#'   it is handed, so the caller restricts it to the rows that changed.
#'
#' @keywords internal
seal_needs_approval <- function(register, events, creators,
                                approvers = character(),
                                channel_account = NULL) {
  stopifnot(
    is.data.frame(register), is.data.frame(events),
    is.character(creators), length(creators) == nrow(register),
    is.character(approvers)
  )

  ids <- as.character(register[["record_id"]])
  sealed <- trimws(as.character(register[["applied_seal"]] %||% ""))
  sealed[is.na(sealed)] <- ""
  intent <- register_intent_fields()
  vapply(seq_along(ids), function(i) {
    owner <- log_owner(events, ids[[i]], creators[[i]], channel_account)
    change_needs_approval(
      log_pending_authors(
        events, ids[[i]], creators[[i]], intent, approvers, channel_account,
        current = register[i, , drop = FALSE]
      ),
      if (is.na(owner)) "" else owner,
      sealed = nzchar(sealed[[i]])
    )
  }, logical(1))
}


#' Whether a change to an applied row has been approved
#'
#' Three conditions, and none is enough on its own.
#'
#' The approval has to carry **this** row's seal. A value that is some other
#' seal approves some other version of the row, and accepting it would make one
#' approval stand for every change that came after it.
#'
#' It has to come from **whoever owns the row**, `log_owner()`: its creator
#' until the round passes it on, then the last referent whose change was
#' approved and carried out. Not merely from somebody other than the author of
#' the change: the request is the owner's, so an approval from a third
#' referent would grant on the word of somebody the row does not answer to.
#' The seal detects that the row moved; only the log can say who approved it
#' and who owns the row, because it names whoever was authenticated rather
#' than a value somebody typed -- which is the same reason neither
#' `requested_by` nor `owned_by` can be trusted alone. An owner the log cannot
#' establish approves nothing.
#'
#' And it has to be **newer than what it approves**: above the round's last
#' execution and above every change somebody other than the owner made, as
#' `log_approval_stands()` reads the log. The value alone cannot say so.
#' `approved_seal` is never blanked, so an approval the round has already
#' carried out would approve again any later change that brings the row back
#' to it; and the seal is a public hash of the intent fields, so it can be
#' pasted before the change it names exists.
#'
#' **IT approves as the owner does**, decided on 2026-10-15: the accounts
#' named in `approvers` stand where the owner stands, under the same three
#' conditions. It is what keeps a request whose owner has left UBEP from
#' waiting for ever, without deleting the row and losing who filed it. The
#' list lives on the machine that runs the round and never in this
#' repository. One limit is worth knowing: the scope gate still asks the
#' creator's rights on the project, so no approval, from IT or anybody else,
#' carries a row whose creator no longer manages the project.
#'
#' An unreadable log is not this function's to decide. It answers about the
#' events and the creators it was handed, and a caller holding neither gets
#' `FALSE` on every changed row: the row waits, which is the direction that
#' does not grant.
#'
#' @param register The register as read, one row per request.
#' @param events The event log, as `register_log()` returns it.
#' @param creators Who created each row, as `log_creators()` answers, in the
#'   order of `register`; the owner is read from the log with them.
#' @param approvers The IT accounts whose approval counts on any row, as REDCap
#'   usernames.
#' @param channel_account The REDCap username that holds the round's token,
#'   or `NULL` when it is not configured, for `log_channel_accounts()` and
#'   `log_owner()`.
#'
#' @return A logical vector, one answer per row.
#'
#' @keywords internal
seal_approved <- function(register, events, creators,
                          approvers = character(),
                          channel_account = NULL) {
  stopifnot(
    is.data.frame(register), is.data.frame(events),
    is.character(creators), length(creators) == nrow(register),
    is.character(approvers)
  )

  current <- request_seal(register)
  approved <- trimws(as.character(register[["approved_seal"]] %||% ""))
  approved[is.na(approved)] <- ""
  ids <- as.character(register[["record_id"]])
  creators <- trimws(creators)
  intent <- register_intent_fields()

  vapply(seq_len(nrow(register)), function(i) {
    if (!nzchar(approved[[i]]) || !identical(approved[[i]], current[[i]])) {
      return(FALSE)
    }

    log_approval_stands(
      events, ids[[i]], creators[[i]], intent, approvers, channel_account
    )
  }, logical(1))
}


#' Whether the newest approval in a row's log still stands
#'
#' The log half of `seal_approved()`: the newest write of `approved_seal` is
#' the owner's, `log_owner()`, or one of the IT accounts', and nothing it could
#' not have seen stands above it. An owner the log cannot establish, or a
#' blank one, approves nothing.
#'
#' - **No execution above it.** The newest write of `applied_seal` is the
#'   round's last execution, and an approval below it was the one that
#'   execution carried out, or one older still. Either way it is spent.
#' - **No change by anybody else above it.** An intent field written by an
#'   account that is neither the owner nor the channel, or by a blank
#'   account, after the approval, is a change the approval cannot have seen:
#'   written before the change, the approval is a seal computed in advance.
#'
#' The owner's own edits above it do not withdraw it here. They move the
#' seal, and the value check in `seal_approved()` is what refuses an approval
#' of a version the owner changed afterwards.
#'
#' The order is REDCap's, newest first, as everywhere else in the log.
#'
#' @param events The event log, as `register_log()` returns it.
#' @param record The record id to look at.
#' @param creator Who created the row, as `log_creators()` answers; the owner
#'   is read from the log with it.
#' @param fields The intent fields.
#' @param approvers The IT accounts whose approval counts on any row.
#' @param channel_account The REDCap username that holds the round's token,
#'   or `NULL` when it is not configured, for `log_channel_accounts()` and
#'   `log_owner()`.
#'
#' @return `TRUE` when the approval stands.
#'
#' @keywords internal
log_approval_stands <- function(events, record, creator,
                                fields = register_intent_fields(),
                                approvers = character(),
                                channel_account = NULL) {
  stopifnot(
    is.data.frame(events), is.character(creator), length(creator) == 1L,
    is.character(fields), is.character(approvers)
  )

  owner <- log_owner(events, record, creator, channel_account)
  if (is.na(owner) || !nzchar(owner)) {
    return(FALSE)
  }
  mine <- log_of_record(events, record)
  channel <- log_channel_accounts(events, record, channel_account)
  if (length(channel) > 1L) {
    return(FALSE)
  }

  authors <- trimws(as.character(mine[["username"]]))
  approvals <- which(log_wrote(mine, "approved_seal"))
  if (length(approvals) == 0L ||
        !log_approver(authors[[approvals[[1L]]]], owner, approvers)) {
    return(FALSE)
  }
  newest <- approvals[[1L]]

  executed <- which(log_wrote(mine, "applied_seal"))
  foreign <- which(
    log_wrote(mine, fields) & !authors %in% channel & authors != owner
  )
  !any(executed <= newest) && !any(foreign < newest)
}


#' Compare a project's dictionary against the packaged one
#'
#' The packaged CSV is the schema and REDCap imports it as it is, so the two
#' start identical. What this reads is whether they still are: an import that
#' dropped a field, a hand edit on the form, a field type loosened to get past
#' a validation complaint.
#'
#' None of those raise anywhere else. `request_from_row()` reads a missing
#' column as "not set" rather than as an error, and the channel ignores fields
#' it does not know — which is correct behavior and also the reason drift here
#' is silent. The comparison is the only thing that looks.
#'
#' The codes it can report, and why each is not cosmetic:
#'
#' - `DIZIONARIO_CAMPO_ASSENTE` — the request loses that field without saying
#'   so;
#' - `DIZIONARIO_CAMPO_IN_PIU` — breaks nothing, and is direct evidence that
#'   somebody edited the form by hand;
#' - `DIZIONARIO_TIPO_DIVERSO` — a `request_status` gone free-text turns a
#'   typo into a request to grant what somebody asked to revoke;
#' - `DIZIONARIO_SCELTE_DIVERSE` — same type, and the value that revokes is
#'   gone;
#' - `DIZIONARIO_READONLY_CADUTO` — a requester can type `applied` into the
#'   outcome, and the register carries a success nobody produced;
#' - `DIZIONARIO_COLONNA_ASSENTE` — the dictionary is malformed, and without
#'   this code it would read as conforming rather than as unreadable;
#' - `DIZIONARIO_SCELTE_NON_CONFRONTATE` — reported for `server` when no
#'   instance list was given: its choices are the fleet, so without the list
#'   only their shape can be judged. It makes `conforms` false on an otherwise
#'   sound dictionary, deliberately — a comparison that could not look at a
#'   field must not be able to return a green, which is the same reason
#'   `DIZIONARIO_COLONNA_ASSENTE` exists.
#'
#' @param actual The dictionary read back from the live project, in the same
#'   eighteen-column shape `register_dictionary()` returns.
#' @param instances Character vector of instance names, passed through to
#'   `register_dictionary()`. With it, the choices of `server` are compared by
#'   content as every other field is. Without it, they are compared by shape
#'   and the substitution is declared.
#'
#' @return A list with `conforms` and `differences`, the latter a character
#'   vector of `CODE:field` strings. Shaped like `compare_readback()` because
#'   it answers the same kind of question.
#'
#' @keywords internal
compare_dictionary <- function(actual, instances = NULL) {
  expected <- register_dictionary(instances)
  field <- "Variable / Field Name"

  # paste0() treats a zero-length vector as "" instead of propagating the
  # empty, so the naive form reports one nameless difference on a dictionary
  # that matches perfectly.
  tag <- function(code, fields) {
    if (length(fields) == 0L) character(0) else paste0(code, ":", fields)
  }

  readonly_in <- function(dictionary) {
    annotation <- dictionary[["Field Annotation"]]
    annotation[is.na(annotation)] <- ""
    dictionary[[field]][grepl("@READONLY", annotation)]
  }

  # Checked up front because an absent column does not raise downstream: the
  # comparison of a seventeen-long vector against a zero-long one yields
  # logical(0), nothing gets reported, and a malformed dictionary reads as
  # conforming. That is the silent pass this function exists to prevent,
  # happening inside the function.
  columns <- c(
    field, "Field Type", "Choices, Calculations, OR Slider Labels",
    "Field Annotation"
  )

  # Only fields both sides carry can drift: the ones only one side has are
  # already reported as absent, and comparing them here would say the same
  # thing twice in a different vocabulary.
  common <- intersect(expected[[field]], actual[[field]])

  cell <- function(dictionary, column) {
    at <- match(common, dictionary[[field]])
    value <- as.character(dictionary[[column]][at])
    value[is.na(value)] <- ""
    value
  }

  drifted <- function(column) {
    common[cell(expected, column) != cell(actual, column)]
  }

  # Compared as parsed pairs, not as the raw cell: REDCap may hand the same
  # choices back with different spacing around the separators, and a check
  # that cries drift on a round trip is one nobody reads by the third run.
  # Order stays significant — a reordering is an edit somebody made.
  choices_of <- function(dictionary) {
    vapply(
      cell(dictionary, "Choices, Calculations, OR Slider Labels"),
      function(text) {
        parsed <- dictionary_choices(text)
        if (nrow(parsed) == 0L) {
          return("")
        }
        paste0(parsed[["code"]], "\r", parsed[["label"]], collapse = "\n")
      },
      character(1),
      USE.NAMES = FALSE
    )
  }

  # The one field whose choices are operating data rather than the contract's
  # vocabulary. Without the list there is nothing to compare them against, so
  # what can still be asserted is their shape: every choice carries its code
  # equal to its label, none is empty, and there is at least one.
  fleet_field <- "server"

  well_formed_fleet <- function() {
    at <- match(fleet_field, common)
    if (is.na(at)) {
      return(TRUE)
    }
    text <- cell(actual, "Choices, Calculations, OR Slider Labels")
    if (length(text) < at) {
      return(FALSE)
    }
    parsed <- dictionary_choices(text[[at]])
    nrow(parsed) > 0L &&
      all(nzchar(parsed[["code"]])) &&
      identical(parsed[["code"]], parsed[["label"]])
  }

  drifted_choices <- common[choices_of(expected) != choices_of(actual)]
  not_compared <- character(0)

  if (is.null(instances)) {
    # Judged by shape instead of by content, and the substitution is declared:
    # a check that could not look must not be able to return a green.
    drifted_choices <- setdiff(drifted_choices, fleet_field)
    if (!well_formed_fleet()) {
      drifted_choices <- c(drifted_choices, fleet_field)
    }
    if (fleet_field %in% common) {
      not_compared <- fleet_field
    }
  }

  differences <- c(
    tag("DIZIONARIO_COLONNA_ASSENTE", setdiff(columns, names(actual))),
    tag(
      "DIZIONARIO_CAMPO_ASSENTE",
      setdiff(expected[[field]], actual[[field]])
    ),
    tag(
      "DIZIONARIO_CAMPO_IN_PIU",
      setdiff(actual[[field]], expected[[field]])
    ),
    tag("DIZIONARIO_TIPO_DIVERSO", drifted("Field Type")),
    tag("DIZIONARIO_SCELTE_DIVERSE", drifted_choices),
    tag("DIZIONARIO_SCELTE_NON_CONFRONTATE", not_compared),
    tag(
      "DIZIONARIO_READONLY_CADUTO",
      setdiff(readonly_in(expected), readonly_in(actual))
    )
  )

  list(conforms = length(differences) == 0L, differences = differences)
}


#' Turn one register row into a request
#'
#' The register's field names are the request's field names, so there is no map
#' between the two and no key can fall into a default without raising. That is
#' the whole reason the names were chosen.
#'
#' A blank cell is dropped rather than carried as `""`. The difference matters
#' downstream: `provisioning_diff()` reads an absent field as "not set", while
#' an empty string would be a value nobody asked for — and a DAG nobody asked
#' for is an update, never a `noop`.
#'
#' @param row A one-row data frame from the register.
#'
#' @return A named list holding only the fields that carry a value.
#'
#' @keywords internal
request_from_row <- function(row) {
  stopifnot(is.data.frame(row), nrow(row) == 1L)

  fields <- c(
    "server", "username", "project_id", "role_name", "dag_name",
    "expiration", "contact_email"
  )

  value_of <- function(field) {
    if (!field %in% names(row)) {
      return(NULL)
    }
    raw <- row[[field]]
    if (length(raw) != 1L || is.na(raw)) {
      return(NULL)
    }
    text <- trimws(as.character(raw))
    if (nzchar(text)) text else NULL
  }

  request <- lapply(fields, value_of)
  names(request) <- fields
  request[!vapply(request, is.null, logical(1))]
}


#' Turn the register into the desired state
#'
#' The register declares requests; it does not describe reality. A pair that
#' exists in REDCap and appears nowhere here means nothing, so this function
#' never produces a revocation that a person did not ask for: only
#' `request_status = "revoked"` does that.
#'
#' Three things keep a row out of the desired state, and they are not the same
#' thing. A row with no resolved username is not a pair yet and is not an
#' error. A pair that appears twice is an error on **every row but the oldest**.
#' A row that fails validation carries the data-error codes back to whoever
#' wrote it.
#'
#' **Why the oldest row survives a duplicate, when it used to fail with the
#' rest.** The two rows were never equals: the older one may already have
#' granted an access, and the newer is the one that did what the work
#' instruction says not to do, which is to file a second request instead of
#' changing the first. Failing closed on both looked like refusing to guess,
#' and was: a marked row never reaches the plan, so **a revocation written on
#' the older row was never carried out either**. The access stayed, the mandate
#' read `data_error`, and nothing in the register could take the access away —
#' a right standing with its mandate marked invalid, which is the failure this
#' register exists to prevent, arriving from the side nobody was watching.
#'
#' Age is the `record_id` and nothing else. "The row already served wins" would
#' name the right row more precisely and is refused on the same ground as the
#' identity gate's: it would ask the `outcome` the register carries, a verdict
#' up to four hours old, instead of a fact about the row.
#'
#' @param register The register as a data frame, one row per pair, carrying at
#'   least `record_id` and `request_status`.
#'
#' @return A list with `desired`, `revoked` and `errors`. The first two hold
#'   requests that already went through `intake_request()`, each carrying its
#'   `record_id` so the outcome knows where to go back. `errors` is named by
#'   `record_id`.
#'
#' @keywords internal
register_to_desired <- function(register) {
  stopifnot(
    is.data.frame(register),
    all(c("record_id", "request_status") %in% names(register))
  )

  ids <- as.character(register[["record_id"]])
  statuses <- as.character(register[["request_status"]])
  requests <- lapply(
    seq_len(nrow(register)),
    function(i) request_from_row(register[i, , drop = FALSE])
  )

  is_pair <- vapply(
    requests,
    function(request) {
      all(
        vapply(
          c("server", "project_id", "username"),
          function(field) !is.null(request[[field]]),
          logical(1)
        )
      )
    },
    logical(1)
  )

  keys <- vapply(seq_along(requests), function(i) {
    if (!is_pair[[i]]) {
      return(NA_character_)
    }
    paste(
      requests[[i]][["server"]],
      requests[[i]][["project_id"]],
      requests[[i]][["username"]],
      sep = "\r"
    )
  }, character(1))

  # The oldest row of a repeated pair keeps its mandate, and only the rows
  # filed after it are told they are duplicates. Marking all of them failed
  # closed on the row that may already hold a granted access -- and a marked
  # row never reaches the plan, so that access could no longer be revoked
  # either. A right standing with its mandate marked invalid is the shape this
  # register exists to make impossible, arriving from the other side.
  #
  # Age is the `record_id`, which REDCap auto-numbers, so it is a fact about
  # the row. "The row already served wins" would be more precise and is
  # refused on the same ground as everywhere else: it would ask the outcome
  # the register carries, which is a verdict up to four hours old.
  #
  # `request_status` in the key was the other candidate and is unsafe. It
  # would stop an `active` and a `revoked` row for one pair from being
  # duplicates, and both would enter the plan: `provisioning_reconcile()`
  # builds its apply batches before its revoke batches and reads the real
  # state before either, so the round would grant the pair and remove it in
  # the same pass, every four hours, without an outcome changing and
  # therefore without a word to anybody.
  #
  # The NA guard is not decoration: `NA %in% NA` is TRUE, so without it every
  # row still waiting for an identity would report itself as a duplicate.
  age <- suppressWarnings(as.numeric(ids))
  eldest <- list()
  for (i in order(age, ids, na.last = TRUE)) {
    key <- keys[[i]]
    # `[[` with an unmatched character subscript is NULL on a list, which is
    # what makes "the first one wins" a single line instead of a lookup.
    if (!is.na(key) && is.null(eldest[[key]])) {
      eldest[[key]] <- i
    }
  }
  repeated <- vapply(
    seq_along(keys),
    function(i) !is.na(keys[[i]]) && !identical(eldest[[keys[[i]]]], i),
    logical(1)
  )

  desired <- list()
  revoked <- list()
  errors <- list()

  for (i in seq_along(requests)) {
    if (!is_pair[[i]]) {
      next
    }

    if (repeated[[i]]) {
      errors[[ids[[i]]]] <- "DATO_COPPIA_DUPLICATA"
      next
    }

    taken <- intake_request(requests[[i]])
    if (length(taken[["errors"]]) > 0L) {
      errors[[ids[[i]]]] <- taken[["errors"]]
      next
    }

    entry <- taken[["request"]]
    entry[["record_id"]] <- ids[[i]]
    if (identical(statuses[[i]], "revoked")) {
      revoked[[length(revoked) + 1L]] <- entry
    } else {
      desired[[length(desired) + 1L]] <- entry
    }
  }

  list(desired = desired, revoked = revoked, errors = errors)
}


#' The closed vocabulary of identity verdicts
#'
#' What the round observed about the person a request names, never what somebody
#' should do about it. The distinction is the same one `outcome` makes: a
#' verdict, not an instruction.
#'
#' Five words, and they are exhaustive over the two questions the resolution
#' asks — how many accounts match the contact address, and whether the composed
#' UPN is taken:
#'
#' - one match — `existing`, or `created` when the account was not there when
#'   the row was last looked at;
#' - no match, composed UPN free — `absent`;
#' - no match, composed UPN taken — `collision`;
#' - more than one match — `ambiguous`.
#'
#' `absent` is the one the four approved on 2026-08-07 were missing, and its
#' absence was not an oversight: they assume resolving and creating are a single
#' act, so the case became `created` at once. It does not, and a state that can
#' last needs a name — for a creation that failed, and for the row a person is
#' still looking at.
#'
#' Only the first two admit an action: the gate refuses a row whose verdict is
#' any of the other three, which is why the vocabulary being closed matters more
#' here than a vocabulary usually does.
#'
#' @return A character vector of the five verdicts.
#'
#' @keywords internal
identity_vocabulary <- function() {
  c("existing", "created", "absent", "collision", "ambiguous")
}


#' Build the body that writes a resolved identity back into the register
#'
#' The twin of `outcome_payload()`, for the second family of fields the round
#' owns, and separate from it for the reason `register_import()` states in its
#' own refusal: the register's intent and what the round decided must not
#' travel together. The columns are fixed here rather than assembled by the
#' caller, so that a bug cannot rewrite what a person asked for.
#'
#' **Neither field is ever written without the other.** A username written
#' without the verdict that authorizes it is exactly the state this sub-project
#' exists to close: the channel today decides by looking at whether `username`
#' is non-empty, and nothing has ever put a verdict beside it.
#'
#' The invariant this establishes is **conditional**, and it is the same
#' condition the gate checks: *a username is authoritative if and only if
#' `identity` is `existing` or `created`*.
#'
#' It is conditional rather than absolute because a collision carries the
#' proposal of decision 11 — there is a determined value to show, and it is the
#' one a person has to act on, so keeping it out of the register would leave it
#' living only inside an e-mail. On `absent` and `ambiguous` there is nothing
#' to propose and the username is empty. What the referent had typed does not
#' survive the resolution either way; REDCap's Logging keeps it.
#'
#' @param record_id The register record to write to.
#' @param username The confirmed UPN, the proposal of a collision, or `""`.
#' @param identity One of the five verdicts, or `""` for a row the resolution
#'   stopped. The empty string is not a missing value here: it is the verdict
#'   "not resolved", and it has to be writable, or a row that stops would keep
#'   the username it earned when it still resolved — which is precisely the
#'   value that has become false.
#'
#' @return A one-row data frame with exactly the identity columns.
#'
#' @keywords internal
identity_payload <- function(record_id, username, identity) {
  stopifnot(
    is.character(record_id), length(record_id) == 1L,
    is.character(username), length(username) == 1L,
    is.character(identity), length(identity) == 1L
  )

  if (!(identity %in% c(identity_vocabulary(), ""))) {
    stop(
      "identity_payload(): \"", identity,
      "\" is not one of the five verdicts, nor the empty one a stopped row ",
      "carries. The five are ",
      paste(identity_vocabulary(), collapse = ", "), ".",
      call. = FALSE
    )
  }

  data.frame(
    record_id = record_id,
    username = username,
    identity = identity,
    stringsAsFactors = FALSE
  )
}


#' The closed vocabulary of outcomes
#'
#' Six words, and the register's `outcome` field offers exactly these. Kept in
#' one place because two readers already need it — the payload builder, which
#' refuses anything else, and the run record, which carries one counter per
#' word. A second copy would let the two drift, and the drift would show as a
#' counter that silently stops counting a word somebody added.
#'
#' `held` is the one that is neither a state nor a fault. The other five split
#' in two: three say where the row is (`pending`, `applied`, `simulated`) and
#' two say what went wrong and therefore who hears about it — `data_error` to
#' whoever filed the row, `transport_error` to us. A row modified after it was
#' applied is a third thing: nothing went wrong, and the round stopped on
#' purpose until somebody approves the change. Filing it under either `_error`
#' would send an alarm to a person with nothing to fix, and `pending` would say
#' nobody has looked at it yet.
#'
#' @return A character vector of the six outcomes.
#'
#' @keywords internal
outcome_vocabulary <- function() {
  c(
    "pending", "applied", "data_error", "transport_error", "simulated",
    "held"
  )
}


#' Build the body that writes an outcome back into the register
#'
#' The register holds two kinds of field and they must never mix. What a person
#' asked for is intent; what happened is observation. This body carries only the
#' second, and the columns are fixed here rather than assembled from the caller
#' so that a bug cannot rewrite intent: without that separation a repeated
#' transport error could switch off legitimate requests, and nobody could tell
#' "a person removed it" from "a bug removed it".
#'
#' `applied_as` is meant to carry what the channel **read back** after writing,
#' not the return code. An outcome that only said "no error" would be the same
#' thing as the four spike cases that reported `true` while doing something
#' else.
#'
#' @param record_id The register record to write to.
#' @param outcome One of `"pending"`, `"applied"`, `"data_error"`,
#'   `"transport_error"`, `"simulated"`.
#' @param detail Error codes or a human-readable note.
#' @param at When the outcome was recorded, as `YYYY-MM-DD HH:MM`.
#' @param applied_as What the re-read found.
#'
#' @return A one-row data frame with exactly the outcome columns.
#'
#' @keywords internal
outcome_payload <- function(record_id,
                            outcome,
                            detail = "",
                            at = "",
                            applied_as = "") {
  vocabulary <- outcome_vocabulary()
  stopifnot(
    is.character(record_id), length(record_id) == 1L,
    is.character(outcome), length(outcome) == 1L, outcome %in% vocabulary
  )

  data.frame(
    record_id = record_id,
    outcome = outcome,
    outcome_detail = as.character(detail),
    outcome_at = as.character(at),
    applied_as = as.character(applied_as),
    stringsAsFactors = FALSE
  )
}
