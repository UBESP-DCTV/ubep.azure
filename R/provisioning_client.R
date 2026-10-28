#' Call one operation on one instance
#'
#' The only function in the package that speaks to a REDCap server, and the
#' only one that builds the URL. Keeping the base normalization here is what
#' stops the three operations from each carrying their own copy of it.
#'
#' @param server Hostname of the instance, optionally followed by the path
#'   REDCap is mounted under, as in `"host.example.org/redcap"`. The fleet is
#'   not uniform on this point, so the mount cannot be assumed.
#' @param secret Shared secret, sent as the `X-UBEP-Secret` header.
#' @param operation One of `"state"`, `"apply"`, `"revoke"`, `"accounts"`.
#' @param requests List of requests; empty reads the whole instance.
#' @param dry_run Logical; the module writes only on an explicit `FALSE`.
#' @param registry Tested fingerprints, see `check_fingerprint()`.
#' @param declare Fingerprints the caller states it has been tested against.
#'   The module refuses to write when its own is not among them, so an empty
#'   declaration writes nothing. Reads and dry runs ignore it.
#' @param accepted Integer vector of contract versions this call tolerates;
#'   `NULL` takes the default for the kind of call, `2:4` for a write and
#'   `1:4` for a read.
#'
#' @return A list with `ok`, `errors`, `payload` and `gate`.
#'
#' @keywords internal
module_call <- function(server,
                        secret,
                        operation,
                        requests = list(),
                        dry_run = TRUE,
                        registry = tested_fingerprints(),
                        declare = certified_fingerprints(registry),
                        accepted = NULL) {
  stopifnot(
    is.character(server), length(server) == 1L,
    is.logical(dry_run), length(dry_run) == 1L, !is.na(dry_run)
  )

  # A scheme is dropped rather than honored, so a base handed over as http is
  # corrected instead of silently downgrading the channel: the spec allows TLS
  # only, and this is the one place that builds the URL.
  base <- sub("^[A-Za-z][A-Za-z0-9+.-]*://", "", server)
  base <- sub("/+$", "", base)

  url <- paste0(
    "https://", base,
    "/api/?type=module&prefix=ubep_provisioning&page=api&NOAUTH"
  )

  response <- tryCatch(
    httr2::request(url) |>
      httr2::req_method("POST") |>
      httr2::req_headers(`X-UBEP-Secret` = secret) |>
      httr2::req_body_json(
        list(
          operation = operation,
          dry_run = dry_run,
          # as.list(), not the bare vector: auto_unbox turns a length-one
          # atomic vector into a scalar, and the registry holds one row.
          tested_fingerprints = as.list(as.character(declare)),
          requests = requests
        ),
        auto_unbox = TRUE
      ) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform(),
    error = function(e) NULL
  )

  if (is.null(response)) {
    return(list(
      ok = FALSE,
      errors = "TRASPORTO_NON_RAGGIUNGIBILE",
      payload = NULL,
      gate = NA_character_
    ))
  }

  # A dry run counts as a read: it changes nothing, and rollout point 1 is
  # "dry_run only, over everything", which a stricter rule would cancel.
  writing <- !dry_run && operation %in% c("apply", "revoke")

  parsed <- parse_module_response(
    httr2::resp_body_string(response),
    status = httr2::resp_status(response),
    # Writes need a contract that can enforce the surface handshake, which is
    # 2 and everything after it: 3 and 4 keep it, and 4 only adds `accounts`.
    # Pinning to exactly 2 would refuse an instance the moment its module is
    # updated: the deploy would break writing rather than extend it, and a
    # fleet with modules at 3 and at 4 side by side has to keep working.
    accepted = accepted %||% (
      if (writing) c(2L, 3L, 4L) else c(1L, 2L, 3L, 4L)
    )
  )

  # No payload means no major and no fingerprint, so any gate here would be
  # invented. NA says "not established".
  gate <- if (is.null(parsed[["payload"]])) {
    NA_character_
  } else {
    check_fingerprint(parsed[["payload"]], registry)
  }

  c(parsed, list(gate = gate))
}


#' Read the real authorization state from one REDCap instance
#'
#' Everything it returns is re-read state: the channel keeps no local copy,
#' because a copy would only be authoritative if nobody could edit REDCap
#' outside the job, which is neither true nor desirable.
#'
#' The request travels as a JSON body, not in the query string. Two reasons:
#' the assertions of the write operations would not fit in a URL, and in a GET
#' every UPN would land in the access log of each instance on every run. The
#' module declares its page in `no-csrf-pages` so the POST is not rejected —
#' see the spec for why CSRF protection does not apply to this endpoint.
#'
#' @inheritParams module_call
#' @param pairs List of (username, project_id) pairs; empty reads the whole
#'   instance, which is what the audit needs.
#'
#' @return A list with `ok`, `errors`, `payload` and `gate`.
#'
#' @keywords internal
module_state <- function(server,
                         secret,
                         pairs = list(),
                         registry = tested_fingerprints(),
                         declare = certified_fingerprints(registry)) {
  requests <- lapply(pairs, function(pair) {
    list(
      username = pair[["username"]],
      project_id = pair[["project_id"]]
    )
  })

  module_call(
    server, secret, "state",
    requests = requests, dry_run = TRUE, registry = registry,
    declare = declare
  )
}


#' Largest number of names one `accounts` call may carry
#'
#' The module caps the operation at this many names and answers a longer
#' request with `400` and `INTERNO`, so `module_accounts()` splits by it.
#'
#' @return `500L`.
#'
#' @keywords internal
module_accounts_limit <- function() {
  500L
}


#' Read the local REDCap accounts of a set of people from one instance
#'
#' Asks the module only for the names it is given and returns one entry per
#' name, present or not: `accounts` answers on the names asked, never on the
#' whole instance, so a person who is missing is an entry that says so and not
#' an absence the caller has to interpret.
#'
#' It accepts contract 4 and nothing else, unlike the other operations. A
#' module still at 3 does not know `accounts` and answers `501` with
#' `contract_version: 3`; with the lists the other operations use that would
#' come out as `INTERNO`, a failure of the module, when it is a module that has
#' not been updated yet. Accepting only 4 makes the parser look at the contract
#' before the status, and the answer is `TRASPORTO_CONTRATTO_DISALLINEATO`.
#'
#' The names go in chunks of [module_accounts_limit()], because a longer
#' request is refused by the module. The first chunk that fails is the answer
#' for the whole call: a partial list would read as people who have never
#' logged in. A name repeated is asked once, ignoring case and surrounding
#' blanks, the same comparison the module makes.
#' An empty set of names makes no call at all: there is nothing to ask, and a
#' request with no names is not a read of the instance.
#'
#' @inheritParams module_call
#' @param usernames Character vector of user names.
#'
#' @return A list with `ok`, `errors`, `payload` and `gate`; `payload$accounts`
#'   holds the entries of every call, in the order of the names.
#'
#' @keywords internal
module_accounts <- function(server,
                            secret,
                            usernames,
                            registry = tested_fingerprints(),
                            declare = certified_fingerprints(registry)) {
  stopifnot(is.character(usernames))

  usernames <- trimws(usernames)
  usernames <- usernames[!duplicated(tolower(usernames))]

  if (length(usernames) == 0L) {
    return(list(
      ok = TRUE,
      errors = character(),
      payload = list(accounts = list()),
      gate = NA_character_
    ))
  }

  chunks <- split(
    usernames,
    ceiling(seq_along(usernames) / module_accounts_limit())
  )

  accounts <- list()
  answer <- NULL

  for (chunk in unname(chunks)) {
    answer <- module_call(
      server, secret, "accounts",
      requests = lapply(chunk, function(username) list(username = username)),
      dry_run = TRUE, registry = registry, declare = declare,
      accepted = 4L
    )

    if (!isTRUE(answer[["ok"]])) {
      return(answer)
    }

    accounts <- c(accounts, answer[["payload"]][["accounts"]])
  }

  answer[["payload"]][["accounts"]] <- accounts
  answer
}


#' Assert the rights a set of people must hold in a set of projects
#'
#' Always asserts the complete state, never a delta: `updatePrivileges` skips
#' fields it is not given, except the DAG, which it clears instead. A delta
#' would revoke DAGs on every renewal and report success — so the caller must
#' pass everything, not just what changed.
#'
#' `dry_run` defaults to `TRUE`, and the module writes only on an explicit
#' `FALSE`. In a dry run `after` is an intention, not an outcome: REDCap can
#' accept a value, store a different one, and still report success, so a
#' green dry run is not a guarantee that the same call will apply cleanly.
#'
#' A write (`dry_run = FALSE`) must concern a single `project_id` across all
#' `requests`; the module rejects a mixed-project write with `400` and code
#' `INTERNO`, because `PROJECT_ID` is an immutable per-process PHP `define()`
#' that selects which project's log gets the trace, so a write spanning two
#' projects would leave one of them untraced. That gate lives in the module,
#' not here. Reads and dry runs are free to span more than one project.
#'
#' @inheritParams module_call
#'
#' @return A list with `ok`, `errors`, `payload` and `gate`.
#'
#' @keywords internal
module_apply <- function(server,
                         secret,
                         requests,
                         dry_run = TRUE,
                         registry = tested_fingerprints(),
                         declare = certified_fingerprints(registry)) {
  module_call(
    server, secret, "apply",
    requests = requests, dry_run = dry_run, registry = registry,
    declare = declare
  )
}


#' Remove the rights a set of people hold in a set of projects
#'
#' Carries the pair and nothing else: revocation does not care which rights
#' are there, and sending them would suggest it does.
#'
#' A write (`dry_run = FALSE`) must concern a single `project_id` across all
#' `requests`; the module rejects a mixed-project write with `400` and code
#' `INTERNO`, because `PROJECT_ID` is an immutable per-process PHP `define()`
#' that selects which project's log gets the trace, so a write spanning two
#' projects would leave one of them untraced. That gate lives in the module,
#' not here. Reads and dry runs are free to span more than one project.
#'
#' @inheritParams module_call
#'
#' @return A list with `ok`, `errors`, `payload` and `gate`.
#'
#' @keywords internal
module_revoke <- function(server,
                          secret,
                          requests,
                          dry_run = TRUE,
                          registry = tested_fingerprints(),
                          declare = certified_fingerprints(registry)) {
  pairs <- lapply(requests, function(request) {
    list(
      username = request[["username"]],
      project_id = request[["project_id"]]
    )
  })

  module_call(
    server, secret, "revoke",
    requests = pairs, dry_run = dry_run, registry = registry,
    declare = declare
  )
}
