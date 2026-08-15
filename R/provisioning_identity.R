#' Fold an address to the form the comparison happens in
#'
#' The whole resolution rests on this being applied to both sides of every
#' comparison. Measured on the tenant on 2026-08-15: 74 accounts carry the
#' contact address with spaces at the edges, and a service-side `eq` would have
#' missed all 74 in silence — reporting `absent` for people who exist, which is
#' the verdict that opens the creation branch. Reading the directory whole is
#' what makes the comparison ours, and therefore able to normalize at all.
#'
#' @param values A character vector, or anything coercible to one.
#'
#' @return A character vector, trimmed and folded to lower case.
#'
#' @keywords internal
identity_normalize <- function(values) {
  tolower(trimws(as.character(values)))
}


#' The addresses a directory row can be found by
#'
#' Both carriers are read: `officeLocation`, where the historical flow put the
#' contact address and where 6.494 accounts still carry it, and `otherMails`,
#' the proper carrier this package writes from now on. The fallback retires
#' when the sweep counts zero accounts with an address in the first — a number,
#' not an intention, and one the sweep produces by itself every round.
#'
#' @param directory A directory frame as `directory_users()` returns.
#'
#' @return A list with one character vector per row, normalized, with empties
#'   dropped so that an empty criterion cannot match an empty field.
#'
#' @keywords internal
directory_contacts <- function(directory) {
  lapply(seq_len(nrow(directory)), function(i) {
    addresses <- identity_normalize(c(
      directory[["otherMails"]][[i]],
      directory[["officeLocation"]][[i]],
      # The UPN is read as a contact carrier too, and decision 12 is why: an
      # address in the tenant's domain **is** a UPN, so an internal contact
      # resolves by being found as one. Without this the second branch of that
      # rule — fill the blank username from an internal contact and go on to
      # confirm it — would have nothing to confirm against. It widens nothing
      # for an external contact, which cannot equal an address in the domain.
      directory[["userPrincipalName"]][[i]]
    ))
    addresses[nzchar(addresses)]
  })
}


#' The addresses an account carries as its own identifiers
#'
#' Wider than the matching set by one field, `mail`, and the distinction is
#' deliberate: the criterion is the contact address and the design names the
#' two carriers it lives in, while this answers a different question — does
#' this account already carry the thing the referent declared?
#'
#' `officeLocation` is in here as the legacy carrier and not as an identifier
#' of its own. It has to be: on the accounts the historical flow created `mail`
#' is `null` and `otherMails` is empty, so without it a referent who declared
#' the right person's alias would be told the row contradicts itself. It
#' retires with the fallback of decision 9.
#'
#' @param account One row of a directory frame.
#'
#' @return A normalized character vector, empties dropped.
#'
#' @keywords internal
directory_identifiers <- function(account) {
  addresses <- identity_normalize(c(
    account[["userPrincipalName"]][[1L]],
    account[["mail"]][[1L]],
    account[["otherMails"]][[1L]],
    account[["officeLocation"]][[1L]]
  ))
  addresses[nzchar(addresses)]
}


#' The rows the resolution is allowed to match against
#'
#' Guests are excluded, and by invariant rather than by measurement: whoever is
#' on the REDCap of UBEP has a `ubep.unipd.it` account, or is given one. The
#' tenant
#' holds 760 guests and they carry their external address in `otherMails`,
#' which is one of the two fields searched, so a guest matching alongside a
#' member would produce an `ambiguous` that is not an ambiguity.
#'
#' A row whose `userType` could not be read stays a candidate, which is not the
#' same as trusting it: it is kept so that it cannot silently become "nobody
#' matched", and `resolve_identity()` then refuses to grant on it. Dropping it
#' here would turn an unreadable field into a second account for a person who
#' already has one, and that is the failure this design fears most.
#'
#' @param directory A directory frame as `directory_users()` returns.
#'
#' @return A logical vector, one per row.
#'
#' @keywords internal
directory_is_candidate <- function(directory) {
  identity_normalize(directory[["userType"]]) != "guest"
}


#' Propose the first free UPN with a numeric suffix
#'
#' The convention was fixed by UBEP on 2026-08-15: `nome.cognome.2`, `.3`, and
#' so on, taking the first free one. It reads as a naming detail and is what
#' makes a collision workable — without a proposal the row hands a person two
#' questions and no material, and with it exactly one is left, the one only the
#' referent can close.
#'
#' The search terminates because each attempt is a value not yet in `taken`,
#' and `taken` is finite.
#'
#' @param composed The UPN `compose_upn()` built, already taken.
#' @param taken Normalized UPNs held by the whole tenant — guests included,
#'   because uniqueness is tenant-wide and not a property of the candidates.
#'
#' @return A single UPN, free in the directory that was swept.
#'
#' @keywords internal
upn_proposal <- function(composed, taken) {
  local <- sub("@.*$", "", composed)
  domain <- sub("^[^@]*@", "", composed)

  suffix <- 2L
  repeat {
    candidate <- paste0(local, ".", suffix, "@", domain)
    if (!(identity_normalize(candidate) %in% taken)) {
      return(candidate)
    }
    suffix <- suffix + 1L
  }
}


#' Say what the resolution decided about one row
#'
#' @param identity One of the five words, or `""` when the row could not be
#'   resolved and has to stop.
#' @param username The UPN, the proposal, or `""`.
#' @param errors Codes, addressed by their prefix.
#'
#' @return A list with `identity`, `username` and `errors`.
#'
#' @keywords internal
identity_verdict <- function(identity, username = "", errors = character()) {
  list(identity = identity, username = username, errors = errors)
}


#' Resolve who a register row is talking about
#'
#' Pure: a function of the row and of the swept directory, in the same shape as
#' `provisioning_diff()` and `scope_errors()`. It reads no network, writes
#' nothing, and knows the register only as a row.
#'
#' **Two queries, not one**, and the whole vocabulary rests on it: `ambiguous`
#' is read off the number of matches on the identity criterion, `collision` off
#' the composed UPN being held by somebody else. A resolver asking one question
#' could not tell `collision` from `absent`, and would either create a
#' duplicate or take a uniqueness refusal from Entra and report it as a
#' transport error — that is, as something that will pass by itself next round.
#' It will not.
#'
#' @param request One register row as a named list, carrying `first_name`,
#'   `last_name`, `contact_email`, `username` and `identity`. The last is the
#'   **previous** verdict, and it is the only memory `created` needs: a row
#'   that was `absent` and now matches is one whose account came into being
#'   because of this request. The memory lives in the register, which is where
#'   this project keeps memory.
#' @param directory A directory frame as `directory_users()` returns.
#' @param domain The tenant's verified domain, defaulting as `compose_upn()`
#'   does, so that what counts as an internal address and what a composed UPN
#'   looks like cannot drift apart.
#'
#' @return A list with `identity`, `username` and `errors`.
#'
#' @keywords internal
resolve_identity <- function(request, directory, domain = "ubep.unipd.it") {
  stopifnot(
    is.list(request),
    is.data.frame(directory),
    all(
      c("userPrincipalName", "givenName", "surname", "otherMails",
        "officeLocation", "userType") %in% names(directory)
    )
  )

  contact <- identity_normalize(request[["contact_email"]] %||% "")
  declared <- identity_normalize(request[["username"]] %||% "")
  previous <- identity_normalize(request[["identity"]] %||% "")

  # No criterion, so nothing to resolve against. `absent` here would create an
  # account for a row that carries no address to send the credential to. The
  # field is required on the form; the API is not the form.
  if (!nzchar(contact)) {
    return(identity_verdict("", errors = "DATO_RECAPITO_ASSENTE"))
  }

  suffix <- paste0("@", identity_normalize(domain))
  internal <- function(address) nzchar(address) && endsWith(address, suffix)

  # Decision 12, and it holds in both directions: whoever has an address in the
  # domain uses it, and that is where we write to them. An internal contact
  # different from the UPN would describe a person who receives mail at one
  # address and authenticates with another, which does not exist in the tenant.
  if (internal(contact) || internal(declared)) {
    if (nzchar(declared) && !identical(contact, declared)) {
      return(identity_verdict("", errors = "DATO_RECAPITO_INTERNO_DIVERGENTE"))
    }
    # Nothing to compose: the address is the UPN, so it is filled in and goes
    # on to be confirmed like any other.
    declared <- contact
  }

  candidate <- directory_is_candidate(directory)
  contacts <- directory_contacts(directory)
  matched <- candidate &
    vapply(contacts, function(addresses) contact %in% addresses, logical(1))

  if (sum(matched) > 1L) {
    return(identity_verdict("ambiguous"))
  }

  if (sum(matched) == 1L) {
    return(confirm_identity(
      request, directory[matched, , drop = FALSE], declared, previous
    ))
  }

  # The one place `absent` is suppressed, and it is counter-intuitive enough to
  # be worth the sentence: the general rule says "not there, so create", and
  # here it says "not there, so somebody mistyped". An address in the domain
  # that does not exist is a typo, and creating it would fabricate the account
  # the typo describes. It is asked before the collision so that the diagnosis
  # names the typo rather than a homonym that has nothing to do with it.
  if (internal(contact)) {
    return(identity_verdict("", errors = "DATO_RECAPITO_INTERNO_INESISTENTE"))
  }

  # Uniqueness is tenant-wide, so the second query looks at every row and not
  # only at the candidates: a UPN held by a guest is held.
  taken <- identity_normalize(directory[["userPrincipalName"]])
  composed <- compose_upn(
    as.character(request[["first_name"]] %||% ""),
    as.character(request[["last_name"]] %||% ""),
    domain = domain
  )

  if (identity_normalize(composed) %in% taken) {
    return(identity_verdict("collision", upn_proposal(composed, taken)))
  }

  identity_verdict("absent")
}


#' Decide whether the single match really is the person the row means
#'
#' A match on the contact address is where the confirmation starts, not where
#' it ends. Three things can stop it, and the prefix on each is a delivery
#' address rather than a label: `DATO_` closes the row against whoever filed it
#' and mails them, `TRASPORTO_` keeps it queued and mails us.
#'
#' The two `TRASPORTO_` ones are fields the account does not carry, and neither
#' is the filer's to fix. Telling the one person who cannot reach a directory
#' attribute that they are not authorized sends them to go and argue — which is
#' the same reasoning `scope_errors()` gives for its fourth case.
#'
#' @param request The register row.
#' @param account The single matching row of the directory frame.
#' @param declared The declared UPN, normalized and possibly filled in from an
#'   internal contact address.
#' @param previous The previous verdict, normalized.
#'
#' @return A list with `identity`, `username` and `errors`.
#'
#' @keywords internal
confirm_identity <- function(request, account, declared, previous) {
  # It stayed a candidate so that it could not silently become "nobody
  # matched", which would create a second account for a person who already has
  # one. Having matched, it still does not grant: it could be a guest, and the
  # invariant admits none.
  if (!nzchar(identity_normalize(account[["userType"]][[1L]]))) {
    return(identity_verdict(
      "", errors = "TRASPORTO_TIPO_UTENTE_NON_LEGGIBILE"
    ))
  }

  # Same normalizer the UPN is composed with, so what counts as the same name
  # and what a composed UPN looks like cannot drift apart.
  given <- clean_string(account[["givenName"]][[1L]])
  family <- clean_string(account[["surname"]][[1L]])

  # A name that is absent does not diverge, but it does not confirm either, and
  # the name is the only thing that confirms here.
  if (!nzchar(given) || !nzchar(family)) {
    return(identity_verdict("", errors = "TRASPORTO_NOME_NON_LEGGIBILE"))
  }

  # Decision 7 of the contract seen from the other side: granting to a person
  # other than the one meant. The row does not fall through to `absent` either,
  # which would create an account whose contact address belongs to somebody
  # else — and mail that person the credential.
  diverges <-
    !identical(given, clean_string(as.character(request[["first_name"]]))) ||
    !identical(family, clean_string(as.character(request[["last_name"]])))
  if (diverges) {
    return(identity_verdict("", errors = "DATO_NOME_DIVERGENTE"))
  }

  # Decision 6: the comparison is between identities and not between strings.
  # An alias, an `@unipd.it` address that is the same institution but not the
  # tenant's domain, a shared mailbox — divergence between the UPN and an
  # address the same person writes from is ordinary, and a string comparison
  # would refuse the ordinary case.
  if (nzchar(declared) && !(declared %in% directory_identifiers(account))) {
    return(identity_verdict("", errors = "DATO_UTENTE_DICHIARATO_DIVERSO"))
  }

  identity_verdict(
    if (identical(previous, "absent")) "created" else "existing",
    account[["userPrincipalName"]][[1L]]
  )
}
