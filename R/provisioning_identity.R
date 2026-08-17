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


#' Is this row's identity confirmed enough to act on
#'
#' The gate the whole sub-project exists to install. The channel today decides
#' by looking at whether `username` is filled, and nothing has ever put a
#' verdict beside it — so a name somebody typed into a form is, as things
#' stand, sufficient to be granted rights under.
#'
#' It admits two of the five words and refuses everything else, **including the
#' empty one**. That fourth case is the one that gets forgotten precisely
#' because it is the current one: `identity` is empty on every row of the live
#' register, so a gate that admitted it would admit everything on the day it is
#' switched on.
#'
#' The round asks this of the verdict it has **just computed**, never of the
#' one it read from the register. Writing `identity` back is the minutes of the
#' verdict, not the input to the next step: a round that gated on the stored
#' value would be looking at something up to four hours old, and on a sweep
#' that failed it would be looking at a value nothing has confirmed this round
#' at all.
#'
#' @param identity A register `identity` column, or one value.
#'
#' @return A logical vector, one per value.
#'
#' @keywords internal
identity_actionable <- function(identity) {
  identity_normalize(identity) %in% c("existing", "created")
}


#' What a row the gate refused reports about itself
#'
#' The gate says which rows stop; this says what the register then carries in
#' `outcome_detail`, which is the only sentence the referent gets. Decided by
#' Corrado on 2026-08-15: `ambiguous` and `collision` close the row as data
#' errors, so `A-13` mails whoever filed it, while `absent` carries no code at
#' all — the round creates the account in the same pass, and mailing somebody
#' about a row nobody has to touch is how an alert stops being read.
#'
#' **The two codes name what to correct rather than what was observed**, and
#' the reason is that sub-project 5 writes its message from the code. What was
#' observed is already in `identity`, where a person can read it; a code that
#' repeated it would hand the referent a diagnosis and no instruction.
#' `DATO_RECAPITO_NON_IDENTIFICA` says the one thing they can do — give a
#' contact address that picks out this person and nobody else — and it is true
#' of both ways an ambiguity arises: the address that sits on two accounts, and
#' the address that matched nothing while a namesake exists.
#'
#' The collision keeps its own code because it is a different question with a
#' different owner: not "which of these people", but "is the account that is
#' already there the one you mean". The proposal they are answering about
#' travels beside it, in the row's `username`, which is why decision 11 writes
#' it into the register instead of leaving it inside an e-mail.
#'
#' The `DATO_` prefix on both is a delivery address and not a label, the way
#' `scope_errors()` uses it: it is what `round_outcome_kind()` reads to close
#' the row against whoever filed it rather than keeping it in the queue for us.
#'
#' @param identity The verdict the resolution has just computed.
#' @param errors The codes the resolution itself produced, which win: a row
#'   stopped before any verdict already knows exactly what is wrong with it,
#'   and the generic summary would cost the referent the sentence they can act
#'   on.
#'
#' @return A character vector of codes, empty when there is nothing to report.
#'
#' @keywords internal
identity_stop_codes <- function(identity, errors = character()) {
  if (length(errors) > 0L) {
    return(as.character(errors))
  }

  switch(
    identity_normalize(identity),
    ambiguous = "DATO_RECAPITO_NON_IDENTIFICA",
    collision = "DATO_IDENTITA_IN_COLLISIONE",
    character()
  )
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


#' The rows that carry this person's name
#'
#' The surname is the criterion and the given name confirms it **only when the
#' account carries one**. An account with a surname and no given name stays in
#' play: it is not a different person, it is a person we know less about, and
#' dropping it would let a homonym through unseen.
#'
#' An account with no surname at all matches nobody. The name is what this
#' question is asked with, and an account that does not answer it cannot be the
#' one — which is why the sweep asks Graph for `givenName` and `surname`.
#'
#' Folded with `clean_string()`, the same way `compose_upn()` folds a name, so
#' what counts as the same name here and what a composed UPN looks like cannot
#' drift apart.
#'
#' @param directory A directory frame as `directory_users()` returns.
#' @param first_name,last_name The names the register row declares.
#'
#' @return A logical vector, one per row.
#'
#' @keywords internal
directory_named <- function(directory, first_name, last_name) {
  wanted_first <- clean_string(as.character(first_name))
  wanted_last <- clean_string(as.character(last_name))

  surnames <- vapply(directory[["surname"]], clean_string, character(1))
  givens <- vapply(directory[["givenName"]], clean_string, character(1))

  nzchar(surnames) &
    surnames == wanted_last &
    (!nzchar(givens) | givens == wanted_first)
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
#' @param composed The name `compose_upn()` built for this row, carried out of
#'   here so that the creation can create **the one that was checked**. It is
#'   read only on `absent`, which is the verdict that says it was free, and it
#'   is not the same thing as `username`: a name that does not exist yet is not
#'   a confirmation and does not belong in the register.
#'
#' @return A list with `identity`, `username`, `errors` and `composed`.
#'
#' @keywords internal
identity_verdict <- function(identity,
                             username = "",
                             errors = character(),
                             composed = "") {
  list(
    identity = identity, username = username, errors = errors,
    composed = composed
  )
}


#' Resolve who a register row is talking about
#'
#' The door, and the one rule that is about the round rather than about the
#' directory: **on a verdict that did not resolve, the round erases the
#' username it wrote itself and keeps the one it did not.**
#'
#' It is the writing half of the rule `51602c1` installed for reading, and it
#' hangs on the same discriminator, the previous verdict. Read in both
#' directions it is a single sentence: an empty `identity` means the `username`
#' beside it belongs to whoever filed the row, and a filled one means it
#' belongs to the round.
#'
#' **Why the round must not empty a declaration.** Measured on rows 2 to 4 of
#' the live register on 2026-08-16. Emptying it, the next round reads the blank
#' as a field the referent left empty -- a row an error stops carries an empty
#' `identity` by construction, so the rule of `51602c1` never speaks -- and
#' decision 12 takes its other branch, fills the username from the internal
#' contact and finds the account's surname is another person's. Two different
#' diagnoses reach the referent for a row they never touched, and the field
#' they are being asked to correct has been blanked, so the mistake is no
#' longer in front of them.
#'
#' **Why it must still empty its own.** A row that was `existing` carries the
#' canonical UPN, which is in the tenant's domain, beside a contact address
#' which ordinarily is not. Kept past the verdict that backed it, that value
#' would be read as a declaration on the next pass and closed as
#' `DATO_RECAPITO_INTERNO_DIVERGENTE` -- the referent blamed for a word the
#' round wrote, which is the oscillation of `51602c1` again with the sides
#' swapped. Both branches settle in one step.
#'
#' @inheritParams resolve_against_directory
#'
#' @return A list with `identity`, `username`, `errors` and `composed`.
#'
#' @keywords internal
resolve_identity <- function(request, directory, domain = "ubep.unipd.it") {
  answer <- resolve_against_directory(request, directory, domain)

  if (nzchar(answer[["identity"]])) {
    return(answer)
  }

  if (nzchar(identity_normalize(request[["identity"]] %||% ""))) {
    answer[["username"]] <- ""
    return(answer)
  }

  # Kept as it was written and not normalized: this is the referent's own
  # value going back into the field they have to correct, not a comparison.
  # The register can hand a field back as `NA`, and what this feeds takes a
  # string -- without the guard the round would write the two letters of a
  # missing value into a field a person reads.
  own <- request[["username"]] %||% ""
  answer[["username"]] <- if (length(own) != 1L || is.na(own)) {
    ""
  } else {
    as.character(own)
  }

  answer
}


#' Ask the swept directory who a register row is talking about
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
#'   this project keeps memory. It also says what `username` is: a claim by
#'   whoever filed the row while the verdict is empty, and this round's own
#'   earlier answer once one sits beside it, because the two are never written
#'   apart.
#' @param directory A directory frame as `directory_users()` returns.
#' @param domain The tenant's verified domain, defaulting as `compose_upn()`
#'   does, so that what counts as an internal address and what a composed UPN
#'   looks like cannot drift apart.
#'
#' @return A list with `identity`, `username` and `errors`. The username is
#'   what the **directory** says, so it is empty on every verdict that did not
#'   resolve; giving the row back what its filer typed is `resolve_identity()`,
#'   which is the only caller and the only place that knows whose the value is.
#'
#' @keywords internal
resolve_against_directory <- function(request,
                                      directory,
                                      domain = "ubep.unipd.it") {
  stopifnot(
    is.list(request),
    is.data.frame(directory),
    all(
      c("userPrincipalName", "givenName", "surname", "otherMails",
        "officeLocation", "userType") %in% names(directory)
    )
  )

  contact <- identity_normalize(request[["contact_email"]] %||% "")
  previous <- identity_normalize(request[["identity"]] %||% "")

  # `username` is a claim by whoever filed the row only until the round has
  # answered it. The two fields are never written apart — decision 5, and
  # `identity_payload()` is the single door — so a row carrying a verdict
  # carries a username this round wrote, and reading it back as a declaration
  # is reading our own handwriting as somebody else's.
  #
  # It is not a nicety. The round writes the canonical UPN, which is in the
  # tenant's domain, next to a contact address which ordinarily is not: read as
  # a declaration that is exactly the shape decision 12 refuses, so the row
  # oscillated with period two — resolved, then closed against the referent
  # with `DATO_RECAPITO_INTERNO_DIVERGENTE`, then resolved again — and every
  # other round mailed them about it. Invisible until the round read its own
  # writing back, which is why it survived the pure layer's own tests.
  #
  # Nothing is lost by dropping it. Decision 6 confirms the declared UPN on the
  # first resolution, which is the one that has a declaration to confirm; from
  # then on the round re-derives the account from the criterion every pass,
  # which is also what makes a renamed login show up as a changed verdict
  # instead of as `DATO_UTENTE_DICHIARATO_DIVERSO` blamed on the referent.
  declared <- if (nzchar(previous)) {
    ""
  } else {
    identity_normalize(request[["username"]] %||% "")
  }

  # No criterion, so nothing to resolve against. `absent` here would create an
  # account for a row that carries no address to send the credential to. The
  # field is required on the form; the API is not the form.
  if (!nzchar(contact)) {
    return(identity_verdict("", errors = "DATO_RECAPITO_ASSENTE"))
  }

  # The surname is the other half of the criterion, and its absence is the same
  # kind of hole: with nothing to match on, every account the directory has no
  # surname for would answer, and a UPN composed from a blank would be created.
  if (!nzchar(clean_string(as.character(request[["last_name"]] %||% "")))) {
    return(identity_verdict("", errors = "DATO_COGNOME_ASSENTE"))
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
  named <- candidate & directory_named(
    directory, request[["first_name"]] %||% "", request[["last_name"]] %||% ""
  )
  carries <- vapply(
    directory_contacts(directory),
    function(addresses) contact %in% addresses,
    logical(1)
  )

  # Decision 12: an address in the domain **is** a UPN, so it names one account
  # outright instead of being searched for. The name rule below would not find
  # that account when the row's surname is somebody else's, and the row would
  # fall through to a creation.
  if (internal(contact)) {
    held <- candidate &
      identity_normalize(directory[["userPrincipalName"]]) == contact

    if (any(held)) {
      if (!any(held & named)) {
        # The row makes two claims of identity that cannot both hold: this
        # login, and that surname. Only the filer knows which human they meant.
        return(identity_verdict("", errors = "DATO_NOME_DIVERGENTE"))
      }
      return(confirm_identity(
        directory[held & named, , drop = FALSE], declared, previous
      ))
    }

    # The one place `absent` is suppressed, and it is counter-intuitive enough
    # to be worth the sentence: the general rule says "not there, so create",
    # and here it says "not there, so somebody mistyped". An address in the
    # domain that does not exist is a typo, and creating it would fabricate the
    # account the typo describes.
    return(identity_verdict("", errors = "DATO_RECAPITO_INTERNO_INESISTENTE"))
  }

  # A contact address on an account whose surname is unknown is the one case
  # the name rule cannot judge. It is not a different person — it is a person
  # the directory says nothing about — and letting it fall through would create
  # a second account for somebody who already has one.
  if (any(candidate & carries & !nzchar(
    vapply(directory[["surname"]], clean_string, character(1))
  ))) {
    return(identity_verdict("", errors = "TRASPORTO_NOME_NON_LEGGIBILE"))
  }

  matched <- named & carries

  if (sum(matched) > 1L) {
    # Same surname and the same contact address on more than one account: a
    # duplicate record rather than an ambiguity about who is meant. Choosing
    # which of the two to grant under is still not ours to make.
    return(identity_verdict("ambiguous"))
  }

  if (sum(matched) == 1L) {
    return(confirm_identity(
      directory[matched, , drop = FALSE], declared, previous
    ))
  }

  # One homonym is enough. There is an account carrying this surname whose
  # contact address is not the one given, and nothing here can tell "the same
  # person, with an address we did not know" from "somebody else with the same
  # name". Only the referent can, and until they do the round must not create a
  # second account for a person who may already have one.
  if (any(named)) {
    return(identity_verdict("ambiguous"))
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
    return(identity_verdict(
      "collision", upn_proposal(composed, taken), composed = composed
    ))
  }

  identity_verdict("absent", composed = composed)
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
#' @param account The single matching row of the directory frame.
#' @param declared The declared UPN, normalized and possibly filled in from an
#'   internal contact address. Empty once a verdict exists on the row, because
#'   then the register's `username` is this round's own earlier answer and not
#'   a declaration to confirm.
#' @param previous The previous verdict, normalized.
#'
#' @return A list with `identity`, `username` and `errors`.
#'
#' @keywords internal
confirm_identity <- function(account, declared, previous) {
  # It stayed a candidate so that it could not silently become "nobody
  # matched", which would create a second account for a person who already has
  # one. Having matched, it still does not grant: it could be a guest, and the
  # invariant admits none.
  if (!nzchar(identity_normalize(account[["userType"]][[1L]]))) {
    return(identity_verdict(
      "", errors = "TRASPORTO_TIPO_UTENTE_NON_LEGGIBILE"
    ))
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
