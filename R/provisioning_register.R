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
#' @return A character vector of field names.
#'
#' @keywords internal
register_readonly_fields <- function() {
  c(
    "identity", "requested_by", "outcome", "outcome_detail",
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


#' Who last wrote one of these fields on this row
#'
#' Reads `details`, which REDCap fills with the fields an edit touched and the
#' values it gave them — `role_name = 'read only'` — so the question "who
#' changed what was asked" is answerable without holding a copy of the row.
#'
#' The most recent matching event wins, and recency is the **order of the
#' answer** rather than the timestamp: REDCap stamps the log to the minute, and
#' an edit and the approval that follows it can easily share one. The order is
#' REDCap's own, newest first.
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

  mine <- events[
    trimws(as.character(events[["record"]])) == as.character(record), ,
    drop = FALSE
  ]
  if (nrow(mine) == 0L || length(fields) == 0L) {
    return("")
  }

  # `\b` and `=` together: without the word boundary `seal_state` would match
  # inside nothing, but `name` would match inside `role_name`, and the answer
  # would be an author who touched a different field.
  pattern <- paste0(
    "\\b(", paste(fields, collapse = "|"), ")\\s*="
  )
  hit <- grepl(pattern, as.character(mine[["details"]]))
  if (!any(hit)) {
    return("")
  }

  trimws(as.character(mine[["username"]][which(hit)[[1L]]]))
}


#' Whether a change to an applied row has been approved
#'
#' Two conditions, and neither is enough on its own.
#'
#' The approval has to carry **this** row's seal. A value that is some other
#' seal approves some other version of the row, and accepting it would make one
#' approval stand for every change that came after it.
#'
#' And it has to come from **somebody else**. Otherwise the protection is a
#' formality: whoever edits another referent's row would paste the seal on the
#' way out, and the round would apply a change nobody but its author ever saw.
#' The seal detects that the row moved; only the log can say who moved it,
#' because it names whoever was authenticated rather than a value somebody
#' typed — which is the same reason `requested_by` cannot be trusted alone.
#'
#' An unreadable log is not this function's to decide. It answers about the
#' events it was handed, and a caller holding no events gets `FALSE` on every
#' changed row: the row waits, which is the direction that does not grant.
#'
#' @param register The register as read, one row per request.
#' @param events The event log, as `register_log()` returns it.
#'
#' @return A logical vector, one answer per row.
#'
#' @keywords internal
seal_approved <- function(register, events) {
  stopifnot(is.data.frame(register), is.data.frame(events))

  current <- request_seal(register)
  approved <- trimws(as.character(register[["approved_seal"]] %||% ""))
  approved[is.na(approved)] <- ""
  ids <- as.character(register[["record_id"]])
  intent <- register_intent_fields()

  vapply(seq_len(nrow(register)), function(i) {
    if (!nzchar(approved[[i]]) || !identical(approved[[i]], current[[i]])) {
      return(FALSE)
    }

    approver <- log_last_author(events, ids[[i]], "approved_seal")
    editor <- log_last_author(events, ids[[i]], intent)

    nzchar(approver) && !identical(approver, editor)
  }, logical(1))
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
