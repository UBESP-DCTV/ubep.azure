#' The pairs one instance has to be asked about
#'
#' Two questions need a state read and they are not the same question: the diff
#' needs the grantees' rows, the scope gate needs the requesters'. Asking for
#' both in one call is not an optimization — it is what makes the gate and the
#' diff see the same instant of reality, instead of two instants a write could
#' fit between.
#'
#' @param requests The validated requests bound for this instance, each
#'   carrying `username` and `project_id`.
#' @param asks The rows of `scope_pairs()` for this instance.
#'
#' @return A list of `list(username, project_id)`, deduplicated.
#'
#' @keywords internal
round_state_pairs <- function(requests, asks) {
  stopifnot(is.list(requests), is.data.frame(asks))

  pair_of <- function(username, project_id) {
    list(
      username = trimws(as.character(username)),
      # `asks` comes straight from `scope_pairs()`, which filters its rows
      # for non-emptiness and never for form, so a `project_id` the register
      # accepted but that is not a number can reach here and coerce to NA
      # rather than raise. The NA never reaches an instance's rights table: a
      # pair whose `project_id` serializes as JSON `null` is refused by the
      # module before it reads anything (inst/redcap-module/api.php). Saying
      # why this row's `project_id` was bad is the caller's job, not this
      # one's.
      project_id = suppressWarnings(as.integer(project_id))
    )
  }

  pairs <- c(
    lapply(requests, function(request) {
      pair_of(request[["username"]], request[["project_id"]])
    }),
    lapply(seq_len(nrow(asks)), function(i) {
      pair_of(asks[["username"]][[i]], asks[["project_id"]][[i]])
    })
  )

  keys <- vapply(pairs, function(pair) {
    paste(pair[["username"]], pair[["project_id"]], sep = "\r")
  }, character(1))

  pairs[!duplicated(keys)]
}


#' Did this instance answer the question the scope gate asks
#'
#' An instance whose module is too old to report the permission answers
#' normally and carries no permission anywhere. That is an absence of the
#' answer, not a verdict, and the gate interrogates answers and never absences:
#' refusing those rows as out of scope would tell a referent "you are not
#' authorized" when the truth is "our module is behind", which is a sentence
#' they can do nothing with.
#'
#' Zero rows is a different fact and must not be folded into this one. The
#' instance answered, and what it said is "there is nothing there" — a
#' requester with no rights row is out of scope, which belongs to whoever filed
#' the request.
#'
#' @param state What `module_state()` returned.
#'
#' @return `TRUE` when the reply can be used to answer the scope question.
#'
#' @keywords internal
round_scope_readable <- function(state) {
  results <- state[["payload"]][["results"]] %||% list()

  length(results) == 0L ||
    any(vapply(
      results,
      function(row) "user_rights" %in% names(row),
      logical(1)
    ))
}


#' The rights one instance reported, in the shape the gate consumes
#'
#' The permission column is added only when the instance actually reported it.
#' Inventing a column of NAs would reach `scope_errors()`'s closed failure by a
#' different route and make the two cases indistinguishable upstream, where
#' they have to be told apart.
#'
#' @param server The instance name, which a `state` reply names once at the top
#'   and not on every row.
#' @param state What `module_state()` returned.
#'
#' @return A data frame with `server`, `project_id`, `username`, and
#'   `user_rights` only when it was reported.
#'
#' @keywords internal
round_rights <- function(server, state) {
  stopifnot(is.character(server), length(server) == 1L, is.list(state))

  results <- state[["payload"]][["results"]] %||% list()

  frame <- data.frame(
    server = rep(server, length(results)),
    project_id = vapply(
      results, function(row) as.character(row[["project_id"]]), character(1)
    ),
    username = vapply(
      results, function(row) as.character(row[["username"]]), character(1)
    ),
    stringsAsFactors = FALSE
  )

  if (!round_scope_readable(state) || length(results) == 0L) {
    return(frame)
  }

  frame[["user_rights"]] <- vapply(results, function(row) {
    value <- row[["user_rights"]]
    if (is.null(value) || length(value) != 1L) {
      NA_integer_
    } else {
      suppressWarnings(as.integer(value))
    }
  }, integer(1))

  frame
}


#' The real rows somebody actually asked about
#'
#' The one filter that keeps the mass revocation from being reachable.
#' `provisioning_diff()` classifies as `revocato` every pair present in reality
#' and absent from the desired state, and the state read carries the
#' requesters' own rows because the scope gate needed them. Handed the
#' unfiltered reply, the diff would propose revoking the referents.
#'
#' Absence means nothing (decision 5) and only an explicit `revoked` takes
#' something away. This is what makes that structural rather than remembered.
#'
#' @param results The `results` of a `state` reply.
#' @param requests The requests this instance was asked to satisfy.
#'
#' @return The subset of `results` whose pair appears in `requests`.
#'
#' @keywords internal
round_actual <- function(results, requests) {
  key_of <- function(row) {
    paste(
      trimws(as.character(row[["username"]])),
      suppressWarnings(as.integer(row[["project_id"]])),
      sep = "\r"
    )
  }

  wanted <- vapply(requests, key_of, character(1))
  Filter(function(row) key_of(row) %in% wanted, results)
}


#' Which dictionary differences stop the round and which are only reported
#'
#' Five of the seven codes change what the round reads and one of them —
#' a `@READONLY` that fell — means a requester may have typed `applied` into
#' the outcome, so the register could be carrying a success nobody produced.
#' The other two cannot: a field the round ignores does not corrupt its
#' reading, and choices that could not be compared are the declared
#' consequence of calling without the fleet list.
#'
#' @param differences The `differences` of `compare_dictionary()`.
#'
#' @return A list with `blocks`, `blocking` and `tolerated`.
#'
#' @keywords internal
round_schema_verdict <- function(differences) {
  stopifnot(is.character(differences))

  blocking <- c(
    "DIZIONARIO_COLONNA_ASSENTE",
    "DIZIONARIO_CAMPO_ASSENTE",
    "DIZIONARIO_TIPO_DIVERSO",
    "DIZIONARIO_SCELTE_DIVERSE",
    "DIZIONARIO_READONLY_CADUTO"
  )

  codes <- sub(":.*$", "", differences)
  stops <- codes %in% blocking

  list(
    blocks = any(stops),
    blocking = differences[stops],
    tolerated = differences[!stops]
  )
}


#' Split what has to be written into batches of one project each
#'
#' `api.php` refuses a write that touches more than one `project_id`, and
#' refuses it outright before touching anything: `PROJECT_ID` is an immutable
#' per-process `define()`, and it is what makes every write land in its own
#' project's log. A job that grouped by instance would take that refusal on its
#' first mixed batch, and the diagnosis would start from the wrong place.
#'
#' Simulations are batched the same way, although the module lets them span
#' projects. One rule instead of two, and a simulation that exercises exactly
#' the batching the write will use: a rehearsal shaped differently from the
#' performance cannot warn about it.
#'
#' @param entries Validated requests, each carrying `record_id`, `server` and
#'   `project_id`.
#'
#' @return A list of batches, each `list(server, project_id, record_ids,
#'   requests)`, where `requests` carry only the five fields the module reads.
#'
#' @keywords internal
round_batches <- function(entries) {
  if (length(entries) == 0L) {
    return(list())
  }

  keys <- vapply(entries, function(entry) {
    paste(
      as.character(entry[["server"]]),
      suppressWarnings(as.integer(entry[["project_id"]])),
      sep = "\r"
    )
  }, character(1))

  lapply(unique(keys), function(key) {
    members <- entries[keys == key]

    list(
      server = as.character(members[[1]][["server"]]),
      project_id = suppressWarnings(as.integer(members[[1]][["project_id"]])),
      record_ids = vapply(
        members, function(entry) as.character(entry[["record_id"]]),
        character(1)
      ),
      requests = lapply(members, function(entry) {
        # Only the keys the module reads. Sending record_id would be harmless —
        # the module rebuilds the request from five keys — and would still put
        # the register's internal numbering into the instance's log.
        request <- list(
          username = trimws(as.character(entry[["username"]])),
          project_id = suppressWarnings(as.integer(entry[["project_id"]]))
        )
        for (field in c("role_name", "dag_name", "expiration")) {
          value <- entry[[field]]
          if (!is.null(value) && length(value) == 1L && !is.na(value)) {
            request[[field]] <- as.character(value)
          }
        }
        request
      })
    )
  })
}


#' Say what was read back, in one line a person can read
#'
#' `applied_as` carries the read-back and not the return code: an outcome that
#' only said "no error" would be the same thing as the four spike cases that
#' reported `true` while doing something else. After a revocation the read-back
#' finding nothing is the success, so absence has to be sayable too.
#'
#' The expiration shown is the value REDCap stores, which is the day after the
#' last day of access. That is the boundary, not an off-by-one: from
#' `intake_request()` onwards every component speaks the stored value.
#'
#' @param row One row of a `state` reply, or `NULL` when the pair is not there.
#'
#' @return A single string.
#'
#' @keywords internal
round_applied_as <- function(row) {
  if (is.null(row)) {
    return("absent")
  }

  field <- function(name) {
    value <- row[[name]]
    if (is.null(value) || length(value) != 1L || is.na(value)) {
      ""
    } else {
      as.character(value)
    }
  }

  paste0(
    "role_name=", field("role_name"),
    "; dag_name=", field("dag_name"),
    "; expiration=", field("expiration")
  )
}


#' Which outcome a set of module error codes deserves
#'
#' The prefix decides the recipient, which is the taxonomy the channel has used
#' since its first design: `DATO_` belongs to whoever filed the request, and
#' anything else is ours. Mixed codes fail towards ours, because a transport
#' error leaves the row in the desired state for the next round while a data
#' error closes it against the requester — and closing a row on a fault that is
#' half ours is the expensive direction.
#'
#' @param codes Character vector of codes the module reported for one entry.
#' @param dry_run Whether this round simulated.
#'
#' @return One word of `outcome_payload()`'s vocabulary.
#'
#' @keywords internal
round_outcome_kind <- function(codes, dry_run) {
  stopifnot(is.logical(dry_run), length(dry_run) == 1L, !is.na(dry_run))

  if (length(codes) == 0L) {
    return(if (dry_run) "simulated" else "applied")
  }

  if (all(startsWith(as.character(codes), "DATO_"))) {
    "data_error"
  } else {
    "transport_error"
  }
}


#' Keep only the outcomes that are not what the register already says
#'
#' `outcome_at` is deliberately outside the comparison: it changes every run by
#' construction, so including it would make every row differ and the filter
#' would filter nothing. Without the filter every quiet night rewrites every
#' row, and the alert on the outcome field becomes background noise — which is
#' the thing people stop reading, and the alert exists to be read.
#'
#' @param register The register as read.
#' @param payload The outcome rows this round produced.
#'
#' @return `payload`, reduced to the rows that changed something.
#'
#' @keywords internal
round_changed <- function(register, payload) {
  stopifnot(is.data.frame(register), is.data.frame(payload))

  if (nrow(payload) == 0L) {
    return(payload)
  }

  held <- function(record_id, field) {
    at <- match(record_id, as.character(register[["record_id"]]))
    if (is.na(at) || !field %in% names(register)) {
      return(NA_character_)
    }
    value <- as.character(register[[field]][[at]])
    if (is.na(value)) "" else value
  }

  fields <- c("outcome", "outcome_detail", "applied_as")

  same <- vapply(seq_len(nrow(payload)), function(i) {
    record_id <- as.character(payload[["record_id"]][[i]])
    all(vapply(fields, function(field) {
      identical(held(record_id, field), as.character(payload[[field]][[i]]))
    }, logical(1)))
  }, logical(1))

  payload[!same, , drop = FALSE]
}
