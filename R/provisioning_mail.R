#' Say an outcome in both languages
#'
#' The vocabulary of outcomes is closed and counts six words. This function
#' names all six, and a test walks `outcome_vocabulary()` to say so: adding a
#' seventh outcome without a translation stops the suite instead of shipping a
#' message with an English gap in the middle of an Italian sentence. That gate
#' fired when `held` was added, which is what it is for.
#'
#' @param outcome One word of `outcome_vocabulary()`.
#'
#' @return A character vector named `it` and `en`.
#'
#' @keywords internal
mail_outcome_words <- function(outcome) {
  stopifnot(is.character(outcome), length(outcome) == 1L, !is.na(outcome))

  said <- list(
    pending         = c(it = "in lavorazione",      en = "in progress"),
    applied         = c(it = "eseguita",            en = "applied"),
    simulated       = c(it = "simulata",            en = "simulated"),
    data_error      = c(it = "errore di dato",      en = "data error"),
    transport_error = c(it = "errore di trasporto", en = "transport error"),
    # Not "sospesa" and not "bloccata": the first says the round is still
    # deciding and the second says something broke. The row is intact, the
    # round read it, and it is waiting for a person -- which is what a referent
    # has to understand from one word before reading the rest.
    held            = c(it = "trattenuta",           en = "held")
  )

  if (!outcome %in% names(said)) {
    stop(
      "mail_outcome_words(): esito fuori vocabolario: ", outcome,
      call. = FALSE
    )
  }

  said[[outcome]]
}


#' Turn the register's UTC stamp into the hour a person in Rome reads
#'
#' The register keeps UTC, which is the machine's truth and the one value the
#' comparison in `round_changed()` ignores by design. A person reading a mail
#' does not hold that convention, and the field test measured the cost: two
#' hours counted three times as latency before somebody read the code.
#'
#' The conversion belongs here, in the text a person reads, and not in the
#' field the code compares.
#'
#' @param at The register's `outcome_at`, `"%Y-%m-%d %H:%M"` in UTC.
#'
#' @return The same moment in Italian civil time, or `NA_character_` if `at`
#'   does not parse -- a wrong hour is worse than a missing one.
#'
#' @keywords internal
mail_local_time <- function(at) {
  stopifnot(is.character(at), length(at) == 1L)

  moment <- as.POSIXct(at, tz = "UTC", format = "%Y-%m-%d %H:%M")
  if (is.na(moment)) {
    return(NA_character_)
  }

  format(moment, "%Y-%m-%d %H:%M", tz = "Europe/Rome")
}


#' Say a value, or say why it is not there
#'
#' REDCap has no conditional piping, so the alert bodies gave every field a
#' line of its own and explained in prose that an empty one meant something.
#' Composing here, the empty case can change the sentence instead, which is a
#' large part of why the text moved out of REDCap at all.
#'
#' @param value The field as the register carries it.
#' @param absent What to say when it carries nothing.
#'
#' @return One string, never empty.
#'
#' @keywords internal
mail_said_or <- function(value, absent) {
  value <- if (is.null(value) || is.na(value)) "" else as.character(value)
  if (nzchar(value)) value else absent
}


#' Say what `applied` did, which is not the same thing twice
#'
#' `applied` is one word for two opposite facts and the module has no second
#' word: it means "what the row asked for was done", and what it asked for is
#' in `request_status`. The alert body had to print the vocabulary and ask the
#' reader to apply it. The mail of record 9 in the field test is what this
#' exists to prevent -- it said `applied` on a revocation, naming nobody, and
#' whoever read it understood that an access had been granted.
#'
#' @param request_status The row's `request_status`.
#'
#' @return A character vector named `it` and `en`.
#'
#' @keywords internal
mail_status_words <- function(request_status) {
  if (identical(as.character(request_status), "revoked")) {
    c(it = "l'accesso e' stato tolto", en = "the access has been removed")
  } else {
    c(it = "l'accesso e' stato concesso", en = "the access has been granted")
  }
}


#' Compose the message that tells whoever filed a row how it went
#'
#' Both languages in one message, Italian above and English below: the channel
#' does not know which one the recipient reads -- `requested_by` is a UPN and
#' says nothing about it -- so sending two would double the post without
#' knowing which of them could be dropped.
#'
#' @param row One register row as a list, carrying the dictionary's fields.
#'
#' @return A list with `subject` and `body`, both length one.
#'
#' @keywords internal
mail_outcome_message <- function(row) {
  stopifnot(is.list(row), !is.null(row[["record_id"]]))

  said <- mail_outcome_words(as.character(row[["outcome"]]))
  status <- mail_status_words(row[["request_status"]])
  id <- as.character(row[["record_id"]])
  locale <- mail_said_or(mail_local_time(row[["outcome_at"]]), "non nota")

  # Only an executed row gets the sentence that says which of the two opposite
  # things `applied` meant. On every other outcome nothing was done, and the
  # sentence would be answering a question nobody asked.
  fatto <- if (identical(as.character(row[["outcome"]]), "applied")) {
    list(
      it = paste0("Che cosa e' successo: ", status[["it"]], "."),
      en = paste0("What happened: ", status[["en"]], ".")
    )
  } else {
    list(it = NULL, en = NULL)
  }

  # A held row is the only outcome that asks the reader to do something whose
  # instructions are not in the work instruction, and the value it asks them to
  # paste exists nowhere else: the current seal is computed from the row, not
  # stored beside it. A referent who is not told it cannot approve anything,
  # and a protection nobody can clear is an outage with a nicer name.
  trattenuta <- if (identical(as.character(row[["outcome"]]), "held")) {
    sigillo <- mail_said_or(row[["seal_now"]], "non disponibile, chiedi a IT")
    list(
      it = c(
        "",
        paste0(
          "Questa riga e' stata modificata dopo essere stata eseguita, e il ",
          "canale non ha riapplicato la modifica. Se la modifica e' giusta, ",
          "falla approvare da un altro referente: deve incollare questo ",
          "sigillo nel campo approved_seal della riga."
        ),
        "",
        paste0("    ", sigillo),
        "",
        paste0(
          "Vale per questa modifica e non per quelle dopo, e chi ha fatto la ",
          "modifica non puo' approvarla da se': il registro degli eventi di ",
          "REDCap dice chi ha scritto che cosa. Approvata, la modifica ",
          "diventa effettiva al giro successivo."
        )
      ),
      en = c(
        "",
        paste0(
          "This row was edited after it had been applied, and the channel did ",
          "not apply the edit. If the edit is right, have another referent ",
          "approve it: they paste this seal into the row's approved_seal ",
          "field."
        ),
        "",
        paste0("    ", sigillo),
        "",
        paste0(
          "It approves this edit and no later one, and whoever made the edit ",
          "cannot approve it themselves: REDCap's event log says who wrote ",
          "what. Once approved, the edit takes effect on the next round."
        )
      )
    )
  } else {
    list(it = NULL, en = NULL)
  }

  it <- c(
    paste0("La richiesta ", id, " del registro di provisioning ha un esito."),
    "",
    paste0("Esito: ", said[["it"]], " (", row[["outcome"]], ")"),
    fatto[["it"]],
    paste0("Dettaglio: ", mail_said_or(row[["outcome_detail"]], "nessuno")),
    paste0("Quando: ", locale, ", ora italiana."),
    "",
    paste0(
      "Riguarda: ", row[["first_name"]], " ", row[["last_name"]],
      " - ", row[["contact_email"]]
    ),
    paste0(
      "Su: ", row[["server"]], ", progetto ", row[["project_id"]],
      ", ruolo ", row[["role_name"]]
    ),
    paste0("Stato richiesto: ", row[["request_status"]]),
    paste0("Nome utente risolto: ", mail_said_or(
      row[["username"]], "non ancora stabilito dalla lavorazione"
    )),
    paste0("Letto sull'istanza: ", mail_said_or(
      row[["applied_as"]], "l'istanza non ha risposto"
    )),
    trattenuta[["it"]],
    "",
    paste0(
      "Un dettaglio che comincia per DATO_ riguarda cio' che e' stato ",
      "compilato, e va corretto nel registro. Uno che comincia per ",
      "TRASPORTO_ e' nostro: la riga torna in coda da sola e non serve ",
      "rifarla, ma se dura piu' di un giorno segnalalo a IT."
    )
  )

  en <- c(
    paste0("Request ", id, " in the provisioning register has an outcome."),
    "",
    paste0("Outcome: ", said[["en"]], " (", row[["outcome"]], ")"),
    fatto[["en"]],
    paste0("Detail: ", mail_said_or(row[["outcome_detail"]], "none")),
    paste0("When: ", locale, ", Italian local time."),
    "",
    paste0(
      "Concerns: ", row[["first_name"]], " ", row[["last_name"]],
      " - ", row[["contact_email"]]
    ),
    paste0(
      "On: ", row[["server"]], ", project ", row[["project_id"]],
      ", role ", row[["role_name"]]
    ),
    paste0("Requested status: ", row[["request_status"]]),
    paste0("Resolved user name: ", mail_said_or(
      row[["username"]], "not established yet"
    )),
    paste0("Read back on the instance: ", mail_said_or(
      row[["applied_as"]], "the instance did not answer"
    )),
    trattenuta[["en"]],
    "",
    paste0(
      "A detail starting with DATO_ concerns what was filled in, and has to ",
      "be corrected in the register. One starting with TRASPORTO_ is ours: ",
      "the row returns to the queue by itself and does not need refiling, ",
      "but if it lasts more than a day, report it to IT."
    )
  )

  list(
    subject = paste0(
      "Richiesta ", id, ": ", said[["it"]],
      " / Request ", id, ": ", said[["en"]]
    ),
    body = paste(c(it, "", "---", "", en), collapse = "\n")
  )
}


#' Tell a person an account now exists for them, and what stands in the way
#'
#' It carries no way in, and that is the decision rather than an omission:
#' `contact_email` is chosen by whoever fills the form and verified by nobody,
#' so a secret sent there would let anyone who can file a request have an
#' account born in the tenant and its key delivered to an address of their own
#' choosing. The referent who asked for the account hands it over instead; this
#' message says so, and names them.
#'
#' @param row One register row as a list.
#' @param upn The account's user principal name, as created.
#'
#' @return A list with `subject` and `body`.
#'
#' @keywords internal
mail_welcome_message <- function(row, upn) {
  stopifnot(is.list(row), is.character(upn), length(upn) == 1L, nzchar(upn))

  referente <- mail_said_or(
    row[["requested_by"]], "chi ha compilato la richiesta"
  )

  it <- c(
    paste0("Ciao ", row[["first_name"]], ","),
    "",
    paste0(
      "e' stato creato per te un account UBEP. Il nome con cui ti autentichi ",
      "e': ", upn
    ),
    "",
    paste0(
      "La chiave d'ingresso non e' in questo messaggio: te la consegna ",
      referente, ", che e' la persona che ha chiesto l'account per te."
    ),
    "",
    "Al primo accesso ti verranno chieste tre cose, in quest'ordine:",
    "",
    "- registrare un secondo fattore di autenticazione, con un tuo",
    "  dispositivo. Si fa una volta sola.",
    "- compilare il modulo con i tuoi dati di base.",
    "- confermare il tuo indirizzo di posta seguendo un link.",
    "",
    "Se qualcosa non torna, rispondi a questo messaggio."
  )

  en <- c(
    paste0("Hello ", row[["first_name"]], ","),
    "",
    paste0(
      "a UBEP account has been created for you. The name you sign in with ",
      "is: ", upn
    ),
    "",
    paste0(
      "The way in is not in this message: ", referente,
      " will hand it to you, as the person who requested the account."
    ),
    "",
    "At first sign-in you will be asked three things, in this order:",
    "",
    "- register a second factor of authentication, with a device of your",
    "  own. This is done once.",
    "- fill in the basic user information form.",
    "- confirm your e-mail address by following a link.",
    "",
    "If anything looks wrong, reply to this message."
  )

  list(
    subject = paste0("Il tuo account UBEP / Your UBEP account: ", upn),
    body = paste(c(it, "", "---", "", en), collapse = "\n")
  )
}


#' Hand the way in to the person who asked for the account
#'
#' It carries the UPN, the key, and nothing else. No project, no role, no
#' instance, nobody in copy: a message with a way in must not also carry the
#' context that makes it spendable.
#'
#' This message has no second chance, and that is what separates it from every
#' other one the round sends. The account is already born and the round does
#' not create it twice, so a send that fails leaves an account nobody can get
#' into -- and the managed identity cannot repair that, because `User.Create`
#' and `User.Read.All` do not touch an account that exists. `mail_round()`
#' reports the failure under its own code, so an alarm can tell it apart from a
#' message that will simply be retried.
#'
#' @param row One register row as a list.
#' @param upn The account's user principal name.
#' @param credential What the account was born with.
#'
#' @return A list with `subject` and `body`.
#'
#' @keywords internal
mail_credential_message <- function(row, upn, credential) {
  stopifnot(
    is.list(row),
    is.character(upn), length(upn) == 1L, nzchar(upn),
    is.character(credential), length(credential) == 1L, nzchar(credential)
  )

  it <- c(
    "Hai chiesto un account, ed e' stato creato. Ecco come entrarci.",
    "",
    paste0("Nome utente: ", upn),
    paste0("Chiave d'ingresso: ", credential),
    "",
    paste0(
      "Consegnala alla persona per una via sicura, e non inoltrare questo ",
      "messaggio. Va cambiata al primo accesso, e chi la usa per prima si ",
      "prende l'account."
    )
  )

  en <- c(
    "You requested an account, and it now exists. Here is how to get in.",
    "",
    paste0("User name: ", upn),
    paste0("Way in: ", credential),
    "",
    paste0(
      "Hand it over securely, and do not forward this message. It must be ",
      "changed at first sign-in, and whoever uses it first takes the account."
    )
  )

  list(
    subject = "Accesso al nuovo account / New account access",
    body = paste(c(it, "", "---", "", en), collapse = "\n")
  )
}


#' Hand one message to the mail service
#'
#' REDCap on the register's instance does not send over SMTP: it sends through
#' its mail provider's HTTP API. So does this, which is why no new dependency
#' appears -- the call is a JSON POST, the same shape `module_call()` already
#' uses.
#'
#' `202` is what success looks like, and it means "accepted", not "delivered".
#' A bounce happens afterwards and asynchronously, and never comes back into
#' the round. What the round can promise is that it did not lose the message
#' through a fault of its own; it cannot promise the referent read it.
#'
#' `from` is not a choice: the account has one verified sender identity and any
#' other address is refused. It arrives as an argument all the same, because a
#' resource name written into a public repository is a resource name published.
#'
#' @param api_key The service key, which the runner reads from Key Vault.
#' @param from The verified sender identity.
#' @param to Recipient address.
#' @param subject,body The composed message.
#' @param cc Optional address in copy.
#' @param reply_to Optional address replies should reach.
#'
#' @return A list with `ok` and `errors`.
#'
#' @keywords internal
mail_send <- function(api_key,
                      from,
                      to,
                      subject,
                      body,
                      cc = NULL,
                      reply_to = NULL) {
  stopifnot(
    is.character(api_key), length(api_key) == 1L, nzchar(api_key),
    is.character(from), length(from) == 1L, nzchar(from),
    is.character(to), length(to) == 1L, nzchar(to),
    is.character(subject), length(subject) == 1L,
    is.character(body), length(body) == 1L
  )

  destinatari <- list(to = list(list(email = to)))
  if (!is.null(cc) && nzchar(cc)) {
    destinatari[["cc"]] <- list(list(email = cc))
  }

  payload <- list(
    personalizations = list(destinatari),
    from = list(email = from),
    subject = subject,
    content = list(list(type = "text/plain", value = body))
  )
  if (!is.null(reply_to) && nzchar(reply_to)) {
    payload[["reply_to"]] <- list(email = reply_to)
  }

  # Same shape as `module_call()`, and for the same reasons: a transport that
  # cannot be reached is not an exception to propagate but an outcome to
  # report, and an HTTP error is read here rather than thrown by httr2.
  response <- tryCatch(
    httr2::request("https://api.sendgrid.com/v3/mail/send") |>
      httr2::req_method("POST") |>
      httr2::req_headers(Authorization = paste("Bearer", api_key)) |>
      httr2::req_body_json(payload, auto_unbox = TRUE) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform(),
    error = function(e) NULL
  )

  if (is.null(response)) {
    return(list(ok = FALSE, errors = "TRASPORTO_POSTA_NON_RAGGIUNGIBILE"))
  }

  if (!identical(httr2::resp_status(response), 202L)) {
    # `errors` carries a closed vocabulary: that is what telemetry counts and
    # what the alarms watch, so it stays exactly as it is. What says *why* is
    # the service's own answer, and until now it was thrown away. On
    # 2026-08-27 that same condition gave 403 on one endpoint and 401 on
    # another, both carrying "The requestor's IP Address is not whitelisted" --
    # without that sentence one goes looking for a network fault instead. It
    # goes to stderr, hence to the journal, which is where whoever is
    # diagnosing a round is already looking, and not into the outcome, so the
    # vocabulary the alarms count keeps its shape.
    detto <- tryCatch(
      httr2::resp_body_string(response),
      error = function(e) ""
    )
    message(
      "Il servizio di posta ha rifiutato (HTTP ",
      httr2::resp_status(response), "): ",
      if (nzchar(detto)) {
        substr(gsub("[[:space:]]+", " ", detto), 1L, 500L)
      } else {
        "nessun corpo nella risposta"
      }
    )
    return(list(ok = FALSE, errors = "TRASPORTO_POSTA_RIFIUTATA"))
  }

  list(ok = TRUE, errors = character())
}


#' Put a redirected message's real recipient into the message
#'
#' A field test runs on real data with every recipient replaced by one address.
#' The line saying who it would have gone to is what makes the run readable; the
#' counter saying the round was redirected is what keeps a forgotten redirect
#' from being silent.
#'
#' @param body The composed body.
#' @param to,cc Who the message was addressed to before the redirect.
#'
#' @return The body, with the declaration on top.
#'
#' @keywords internal
mail_redirect_note <- function(body, to, cc) {
  paste(
    c(
      "[PROVA] Questo messaggio e' stato dirottato.",
      paste0("[PROVA] Sarebbe andato a: ", to),
      if (!is.null(cc) && nzchar(cc)) paste0("[PROVA] In copia a: ", cc),
      "",
      body
    ),
    collapse = "\n"
  )
}


#' Send this round's messages, and say which rows may now be written
#'
#' The order is the decision: send first, write after. A row whose message did
#' not leave stays as the register has it, so the next round finds it changed
#' again and retries -- the queue is the register, and no second state exists
#' to keep aligned. The cost accepted in exchange is a duplicate, never a loss.
#'
#' The credential message is the asymmetry. The account is already born, the
#' round does not create it twice, and the managed identity cannot repair it.
#' So its failure is not a retry: it is a person's job, and it goes out under
#' its own code so an alarm can tell the two apart.
#'
#' @param changed The rows this round would write, from `round_changed()`.
#' @param register The register as read, carrying every field the messages
#'   name.
#' @param born The accounts created this round: lists with `record_id`, `upn`
#'   and `credential`.
#' @param mailer `function(to, cc, subject, body)` returning `ok` and `errors`.
#' @param dry_run When `TRUE` nothing is sent and every row comes back
#'   writable -- the round behaves as it did before this file existed.
#' @param redirect_to One address replacing every recipient, for a field test.
#' @param copy_to Address in copy, on the outcome message only.
#' @param reply_to Kept for the caller's symmetry with `mail_send()`; the
#'   mailer closure is what carries it to the transport.
#' @param identified The identity this round settled, as a frame with
#'   `record_id` and the fields it settled. `register` is the register as
#'   read, on purpose; this is how the message names what the round has just
#'   established rather than what the referent typed.
#'
#' @return A list with `recapitate`, `errori` and `contatori`.
#'
#' @keywords internal
mail_round <- function(changed,
                       register,
                       born,
                       mailer,
                       dry_run,
                       redirect_to = NULL,
                       copy_to = NULL,
                       reply_to = NULL,
                       identified = NULL) {
  stopifnot(
    is.data.frame(changed), is.data.frame(register), is.list(born),
    is.function(mailer),
    is.logical(dry_run), length(dry_run) == 1L, !is.na(dry_run)
  )

  conto <- list(
    posta_partite = 0L, posta_fallite = 0L,
    credenziali_recapitate = 0L, credenziali_perse = 0L,
    posta_dirottata = !is.null(redirect_to)
  )

  if (isTRUE(dry_run)) {
    return(list(recapitate = changed, errori = character(), contatori = conto))
  }

  # `register` is the register as read, and it stays that way: it is the metro
  # the change was measured against. But the round settles `username` and
  # `identity` earlier and writes them through their own door, before the mail
  # leaves -- so a message composed from `register` alone would tell the
  # referent the UPN is not established yet, about a value this same round has
  # already put in the register. This is the only place that difference is
  # visible, so it is repaired here rather than by widening what `changed`
  # carries: that frame is also what gets imported, and the two doors stay
  # separate.
  riga_di <- function(record_id) {
    at <- match(as.character(record_id), as.character(register[["record_id"]]))
    if (is.na(at)) {
      return(NULL)
    }
    riga <- as.list(register[at, , drop = FALSE])
    # What the row is worth now, which a held message has to carry: it is
    # computed from the row and stored nowhere, so this is the only place it
    # exists. Taken from `register` -- the register as read -- for the reason
    # the whole frame is: a seal computed from what the round has been
    # rewriting would name a version of the row the referent is not looking at.
    riga[["seal_now"]] <- request_seal(register[at, , drop = FALSE])
    if (is.null(identified)) {
      return(riga)
    }
    found <- match(
      as.character(record_id), as.character(identified[["record_id"]])
    )
    if (is.na(found)) {
      return(riga)
    }
    for (campo in setdiff(names(identified), "record_id")) {
      riga[[campo]] <- identified[[campo]][[found]]
    }
    riga
  }

  consegna <- function(to, cc, message) {
    if (is.null(to) || is.na(to) || !nzchar(to)) {
      return(list(ok = FALSE, errors = "POSTA_SENZA_DESTINATARIO"))
    }
    corpo <- message[["body"]]
    if (!is.null(redirect_to)) {
      corpo <- mail_redirect_note(corpo, to, cc)
      cc <- NULL
      to <- redirect_to
    }
    mailer(to = to, cc = cc, subject = message[["subject"]], body = corpo)
  }

  errori <- character()
  partite <- logical(nrow(changed))

  for (i in seq_len(nrow(changed))) {
    riga <- riga_di(changed[["record_id"]][[i]])
    if (is.null(riga)) {
      errori <- c(errori, "POSTA_RIGA_NON_TROVATA")
      next
    }
    # The message describes THIS round's answer, not the one the register still
    # carries: `register` is what `changed` was measured against, so it holds
    # the previous outcome and would tell the referent yesterday's news.
    for (campo in intersect(names(changed), names(riga))) {
      riga[[campo]] <- changed[[campo]][[i]]
    }
    esito <- consegna(
      riga[["requested_by"]], copy_to, mail_outcome_message(riga)
    )
    partite[[i]] <- isTRUE(esito[["ok"]])
    if (!partite[[i]]) errori <- c(errori, esito[["errors"]])
  }

  for (nato in born) {
    riga <- riga_di(nato[["record_id"]])
    if (is.null(riga)) {
      errori <- c(errori, "POSTA_CREDENZIALE_PERSA")
      conto[["credenziali_perse"]] <- conto[["credenziali_perse"]] + 1L
      next
    }
    consegna(
      riga[["contact_email"]], NULL,
      mail_welcome_message(riga, upn = nato[["upn"]])
    )
    segreto <- consegna(
      riga[["requested_by"]], NULL,
      mail_credential_message(
        riga, upn = nato[["upn"]], credential = nato[["credential"]]
      )
    )
    if (isTRUE(segreto[["ok"]])) {
      conto[["credenziali_recapitate"]] <-
        conto[["credenziali_recapitate"]] + 1L
    } else {
      conto[["credenziali_perse"]] <- conto[["credenziali_perse"]] + 1L
      # The code carries no value with it: this string reaches the telemetry
      # record, which is shipped to a workspace and kept.
      errori <- c(errori, "POSTA_CREDENZIALE_PERSA")
    }
  }

  conto[["posta_partite"]] <- sum(partite)
  conto[["posta_fallite"]] <- sum(!partite)

  list(
    recapitate = changed[partite, , drop = FALSE],
    errori = errori,
    contatori = conto
  )
}
