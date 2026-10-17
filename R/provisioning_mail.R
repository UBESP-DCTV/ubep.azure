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
#' does not know which one the recipient reads -- the address it goes to,
#' `mail_referent()`, is a UPN and says nothing about it -- so sending two
#' would double the post without knowing which of them could be dropped.
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
  #
  # An applied change that handed the row over says so right after it: the
  # reader is the new owner, and the message is where they learn that the
  # approvals of the row's changes are theirs now.
  fatto <- if (identical(as.character(row[["outcome"]]), "applied")) {
    passaggio <- isTRUE(row[["passed"]])
    list(
      it = c(
        paste0("Che cosa e' successo: ", status[["it"]], "."),
        if (passaggio) {
          paste0(
            "Da questa modifica la riga e' tua: le modifiche di altri ",
            "referenti aspettano la tua approvazione, oppure quella di IT."
          )
        }
      ),
      en = c(
        paste0("What happened: ", status[["en"]], "."),
        if (passaggio) {
          paste0(
            "From this change on the row is yours: changes by other ",
            "referents wait for your approval, or IT's."
          )
        }
      )
    )
  } else {
    list(it = NULL, en = NULL)
  }

  # With nobody established as the row's owner the message goes to IT alone,
  # and says so on its first lines: IT reads it without knowing which of the
  # rows it concerns would have gone elsewhere.
  senza_referente <- if (nzchar(mail_referent(row))) {
    list(it = NULL, en = NULL)
  } else {
    list(
      it = "Referente della riga non stabilito: questo messaggio va solo a IT.",
      en = paste0(
        "Whoever owns the row is not established: this message goes to IT ",
        "only."
      )
    )
  }

  # A held row is the only outcome that asks the reader to do something whose
  # instructions are not in the work instruction, and the value it asks them to
  # paste is computed from the row: a referent who is not told it cannot
  # approve anything, and a protection nobody can clear is an outage with a
  # nicer name. The message goes to whoever owns the row, the only person
  # whose approval counts, so it says that, and names who changed the row:
  # the owner is the one who has to judge the change. It does not say the
  # request had been applied: one still in the queue is held the same way.
  trattenuta <- if (identical(as.character(row[["outcome"]]), "held")) {
    sigillo <- mail_said_or(row[["seal_now"]], "non disponibile, chiedi a IT")
    list(
      it = c(
        "",
        paste0(
          "Questa richiesta e' stata modificata, prima o dopo essere stata ",
          "eseguita, e il canale non ha applicato la modifica perche' non ",
          "risulta fatta solo dal referente della riga. La puo' approvare ",
          "solo il referente della riga, oppure IT: questo messaggio va al ",
          "referente della riga."
        ),
        paste0("Modificata da: ", mail_said_or(
          row[["edited_by"]], "non stabilito dal registro degli eventi"
        )),
        "",
        paste0(
          "Se la modifica e' giusta, incolla questo sigillo nel campo ",
          "approved_seal della riga:"
        ),
        "",
        paste0("    ", sigillo),
        "",
        paste0(
          "Vale per questa versione della riga e non per quelle dopo: se la ",
          "riga cambia ancora, arriva un sigillo nuovo. Vale una volta sola: ",
          "eseguita la modifica, l'approvazione e' consumata, e un sigillo ",
          "incollato prima della modifica non la approva. L'approvazione di ",
          "qualunque altro referente, compreso chi ha fatto la modifica, non ",
          "vale: il registro degli eventi di REDCap dice di chi e' la riga e ",
          "chi ha scritto che cosa. Approvata, la modifica diventa ",
          "effettiva al giro successivo."
        ),
        "",
        paste0(
          "Se la modifica non e' giusta, riporta i campi ai valori di prima. ",
          "Una richiesta gia' eseguita torna cosi' alla versione eseguita e ",
          "non c'e' niente da approvare; una non ancora eseguita resta ferma, ",
          "e arriva il sigillo della versione ripristinata da incollare."
        )
      ),
      en = c(
        "",
        paste0(
          "This request was edited, before or after it was applied, and the ",
          "channel did not apply the edit because it is not on record as made ",
          "by whoever owns the row alone. Only whoever owns the row, or IT, ",
          "can approve it: this message goes to whoever owns the row."
        ),
        paste0("Edited by: ", mail_said_or(
          row[["edited_by"]], "not established from the event log"
        )),
        "",
        paste0(
          "If the edit is right, paste this seal into the row's approved_seal ",
          "field:"
        ),
        "",
        paste0("    ", sigillo),
        "",
        paste0(
          "It approves this version of the row and no later one: if the row ",
          "changes again, a new seal follows. It counts once: when the edit ",
          "has been applied the approval is spent, and a seal pasted before ",
          "the edit does not approve it. An approval by any other referent, ",
          "including whoever made the edit, does not count: REDCap's event ",
          "log says who owns the row and who wrote what. Once approved, ",
          "the edit takes effect on the next round."
        ),
        "",
        paste0(
          "If the edit is wrong, set the fields back to what they were. A ",
          "request already applied then returns to the version that was ",
          "applied, with nothing to approve; one not applied yet stays held, ",
          "and the seal of the restored version follows for you to paste."
        )
      )
    )
  } else {
    list(it = NULL, en = NULL)
  }

  it <- c(
    paste0("La richiesta ", id, " del registro di provisioning ha un esito."),
    senza_referente[["it"]],
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
    senza_referente[["en"]],
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


#' Who the round's mail to a row's referent goes to
#'
#' The row's owner: who the creation log names as having made the row, until
#' an approved change by another referent hands it over, which the log holds
#' as a write of `owned_by` by the channel's account. The round settles it
#' from the log and passes it on as `owner`. It is the only one whose
#' approval of a change counts, IT aside; the scope gate judges whoever wrote
#' what the round carries out, which is the owner only when nobody else
#' changed the row. Every message the round sends to whoever asked goes
#' there: the outcome, whatever it is, and the key of an account just made.
#'
#' Not `requested_by`. On the form `@USERNAME` fills it in and the two agree;
#' the Data Import Tool writes it as the CSV has it (measured on 2026-09-02
#' and again on 2026-10-16), and the round does not write it back. Sent to
#' that field, an import that left it empty lost the key and the outcome, and
#' one naming another address sent both there, to the person themselves if
#' the file said so, against the rule that the key stays with the referent.
#'
#' And there is no fallback to it. Once a row can change hands, a fallback
#' would write to a former owner, the one person who should no longer hear
#' about the row. An empty owner means the round could not settle it, and
#' the outcome then goes to IT alone and says so (see `mail_round()`). That
#' happens on a sweep of the tenant that failed, which asks no log; on a
#' creation log or an owners' log that could not be read; on a round with no
#' row to judge, which asks neither; on a creation log that does not name the
#' row; and on an owner the log leaves ambiguous, when an account other than
#' the channel's wrote a field only the channel writes. No key reaches
#' anybody then: a row whose owner the log does not name stops at the gate
#' on `TRASPORTO_AUTORE_NON_LEGGIBILE`, and nobody is made for it.
#'
#' @param row One register row as a list, with this round's outcome and the
#'   `owner` the round settled.
#'
#' @return One address, possibly empty.
#'
#' @keywords internal
mail_referent <- function(row) {
  stopifnot(is.list(row))

  mail_said_or(row[["owner"]], "")
}


#' Say where an instance opens, from the host the inventory names
#'
#' The host is the one `provisioning_reconcile()` already holds, read from the
#' inventory on the machine: the address is not composed from `server` and is
#' not written anywhere in this repository. The scheme and the trailing slashes
#' are dropped first, as `module_call()` drops them, so a host the instances
#' answer on cannot turn into an address nobody can open.
#'
#' @param host The instance's host, optionally followed by the path REDCap is
#'   mounted under.
#'
#' @return The address as a person opens it, or `NULL` when there is no host.
#'
#' @keywords internal
mail_instance_url <- function(host) {
  if (is.null(host) || length(host) != 1L || is.na(host) || !nzchar(host)) {
    return(NULL)
  }
  base <- sub("^[A-Za-z][A-Za-z0-9+.-]*://", "", as.character(host))
  base <- sub("/+$", "", base)
  if (!nzchar(base)) {
    return(NULL)
  }
  paste0("https://", base, "/")
}


#' Tell a person an account now exists for them, and what stands in the way
#'
#' It carries no way in, and that is the decision rather than an omission:
#' `contact_email` is chosen by whoever fills the form and verified by nobody,
#' so a secret sent there would let anyone who can file a request have an
#' account born in the tenant and its key delivered to an address of their own
#' choosing. The referent who asked for the account hands it over instead; this
#' message says so, and names them as `mail_referent()` does: the owner the
#' log settled, who receives the key, and not `requested_by`.
#'
#' It does name the instance, as the address REDCap opens at, and that is the
#' same decision read from the other side. A message without a secret can carry
#' the context, and of the two messages a creation sends this is the one that
#' can: the message with the key carries none of it, because context is what
#' makes a key spendable. It also says that access to the project normally
#' follows within four hours, which is the cadence of the round. Without an
#' address the message still leaves, without those two lines: a missing address
#' is no reason to lose it.
#'
#' @param row One register row as a list.
#' @param upn The account's user principal name, as created.
#' @param url The address the row's instance opens at, from
#'   `mail_instance_url()`; `NULL`, `NA` or empty leaves it out.
#'
#' @return A list with `subject` and `body`.
#'
#' @keywords internal
mail_welcome_message <- function(row, upn, url = NULL) {
  stopifnot(
    is.list(row), is.character(upn), length(upn) == 1L, nzchar(upn),
    is.null(url) || length(url) == 1L
  )

  # The person the key goes to, so the owner and not the field an import
  # writes as it likes: naming another would send the person to wait for
  # somebody who never receives it. Without an owner, a description that
  # names nobody, in each language.
  referente <- mail_said_or(mail_referent(row), "")
  chi <- if (nzchar(referente)) {
    list(it = referente, en = referente)
  } else {
    list(
      it = "il referente che ha chiesto l'account",
      en = "the referent who requested the account"
    )
  }

  # Both lines or neither: the four hours are about the instance the address
  # names, and without the address they would be a promise about a place the
  # message does not say.
  istanza <- if (is.null(url) || is.na(url) || !nzchar(url)) {
    list(it = NULL, en = NULL)
  } else {
    list(
      it = c(
        "",
        paste0("REDCap si apre da: ", url),
        paste0(
          "L'accesso al progetto per cui e' stato chiesto l'account arriva di ",
          "norma entro quattro ore da questo messaggio."
        )
      ),
      en = c(
        "",
        paste0("REDCap opens at: ", url),
        paste0(
          "Access to the project the account was requested for normally ",
          "arrives within four hours of this message."
        )
      )
    )
  }

  it <- c(
    paste0("Ciao ", row[["first_name"]], ","),
    "",
    paste0(
      "e' stato creato per te un account UBEP. Il nome con cui ti autentichi ",
      "e': ", upn
    ),
    istanza[["it"]],
    "",
    paste0(
      "La chiave d'ingresso non e' in questo messaggio: te la consegna ",
      chi[["it"]], ", che e' la persona che ha chiesto l'account per te."
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
    istanza[["en"]],
    "",
    paste0(
      "The way in is not in this message: ", chi[["en"]],
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
#' What it asks of the referent is the rule decided for handing the key over:
#' another channel if there is one, otherwise a new message with the key
#' alone, never a forward of this one, and to the address the referent knows
#' from their own correspondence rather than the one copied from the request.
#' The welcome went to the address in the request, so a referent who finds the
#' two different is asked to stop and reply instead of sending. The same
#' sentence asks them to leave the key out of the reply: a mail client quotes
#' this body by default, and the reply goes to the round's reply address,
#' where a key not yet used would stay readable.
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
      "Consegna la chiave alla persona, e non inoltrare questo messaggio. Se ",
      "hai un canale diverso dalla posta, usa quello; altrimenti scrivile una ",
      "mail nuova con la sola chiave: il nome utente le e' gia' arrivato in ",
      "un messaggio a parte. Usa l'indirizzo che conosci dalla tua ",
      "corrispondenza con lei, non quello copiato dalla richiesta. Se i due ",
      "non coincidono, fermati e rispondi a questo messaggio senza la chiave ",
      "(togli il testo citato): quel messaggio a parte e' andato ",
      "all'indirizzo della richiesta."
    ),
    "",
    "Va cambiata al primo accesso, e chi la usa per prima si prende l'account."
  )

  en <- c(
    "You requested an account, and it now exists. Here is how to get in.",
    "",
    paste0("User name: ", upn),
    paste0("Way in: ", credential),
    "",
    paste0(
      "Hand the key to the person, and do not forward this message. If you ",
      "have a channel other than e-mail, use it; otherwise write them a new ",
      "e-mail with the key alone: the user name has already reached them in a ",
      "separate message. Use the address you know from your own ",
      "correspondence with them, not the one copied from the request. If the ",
      "two differ, stop and reply to this message without the key (delete ",
      "the quoted text): that separate message went to the address in the ",
      "request."
    ),
    "",
    paste0(
      "It must be changed at first sign-in, and whoever uses it first takes ",
      "the account."
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
#' The two messages a creation sends are the asymmetry. The account is already
#' born, the round does not create it twice, and the managed identity cannot
#' repair it, so neither the welcome nor the key has a next round. Their
#' failure is not a retry: it is a person's job, and each goes out under its
#' own code, `POSTA_BENVENUTO_PERSO` and `POSTA_CREDENZIALE_PERSA`, so an alarm
#' can tell them apart from a message that will simply be retried. They are
#' counted apart from the outcome messages for the same reason, and a welcome
#' that did not leave holds no row back: holding it would not send the welcome
#' again, it would only keep the outcome out of the register.
#'
#' The welcome goes to `contact_email`, the person. The outcome and the key go
#' to the referent, `mail_referent()`: the owner `identified` carries. The
#' outcome of a row without one goes to `copy_to` alone, with a line saying
#' so; its key goes nowhere.
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
#' @param copy_to Address in copy, on the outcome message only; and the one
#'   address the outcome goes to when the row has no established owner.
#' @param reply_to Kept for the caller's symmetry with `mail_send()`; the
#'   mailer closure is what carries it to the transport.
#' @param identified What this round settled about each row, as a frame with
#'   `record_id` and the fields it settled: the identity; `owner`, who the
#'   log says the row belongs to, where the outcome and the key go
#'   (`mail_referent()`); `passed`, whether the change applied this round
#'   handed the row over; `edited_by`, who changed a held row since
#'   it was applied, as the row's log says. `register` is the register as read,
#'   on purpose; this is how the message names what the round has just
#'   established rather than what the referent typed.
#' @param hosts Named character vector, instance name to host, as
#'   `provisioning_reconcile()` receives it from the inventory. Only the
#'   welcome message reads it, to say where the row's instance opens; a row
#'   whose instance it does not name gets a welcome without that address.
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
                       identified = NULL,
                       hosts = NULL) {
  stopifnot(
    is.data.frame(changed), is.data.frame(register), is.list(born),
    is.function(mailer),
    is.logical(dry_run), length(dry_run) == 1L, !is.na(dry_run),
    is.null(hosts) || is.character(hosts)
  )

  # The address the welcome names, looked up by the row's instance. A server
  # the map does not hold is not an error here: the welcome leaves anyway,
  # without the address, because the account is born either way.
  indirizzo_di <- function(server) {
    server <- as.character(server %||% "")
    known <- length(server) == 1L && !is.na(server) && server %in% names(hosts)
    if (!known) {
      return(NULL)
    }
    mail_instance_url(hosts[[server]])
  }

  conto <- list(
    posta_partite = 0L, posta_fallite = 0L,
    credenziali_recapitate = 0L, credenziali_perse = 0L,
    benvenuti_recapitati = 0L, benvenuti_persi = 0L,
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
    found <- if (is.null(identified)) {
      NA_integer_
    } else {
      match(as.character(record_id), as.character(identified[["record_id"]]))
    }
    if (!is.na(found)) {
      for (campo in setdiff(names(identified), "record_id")) {
        riga[[campo]] <- identified[[campo]][[found]]
      }
    }
    # What the row is worth now, which a held message has to carry: it is
    # computed from the row, and the round writes it into the outcome detail
    # too. Computed after what the round settled, and not on the register as
    # read: the round has already written the resolved username when this
    # message leaves, `username` is inside the seal, and the referent pastes
    # the value into a row that carries the resolved name.
    riga[["seal_now"]] <- request_seal(
      as.data.frame(riga, stringsAsFactors = FALSE, check.names = FALSE)
    )
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
    # To IT alone when nobody owns the row, and not in copy: there is nobody
    # to copy. The message says so itself.
    destinatario <- mail_referent(riga)
    esito <- if (nzchar(destinatario)) {
      consegna(destinatario, copy_to, mail_outcome_message(riga))
    } else {
      consegna(copy_to, NULL, mail_outcome_message(riga))
    }
    partite[[i]] <- isTRUE(esito[["ok"]])
    if (!partite[[i]]) errori <- c(errori, esito[["errors"]])
  }

  for (nato in born) {
    riga <- riga_di(nato[["record_id"]])
    if (is.null(riga)) {
      # Neither message has a row to be composed from, so both are lost, and
      # they are counted the way each is counted when its own send fails.
      errori <- c(errori, "POSTA_BENVENUTO_PERSO", "POSTA_CREDENZIALE_PERSA")
      conto[["benvenuti_persi"]] <- conto[["benvenuti_persi"]] + 1L
      conto[["credenziali_perse"]] <- conto[["credenziali_perse"]] + 1L
      next
    }
    # The welcome is not retried either, for the reason the key is not: the
    # account is born and nothing in the next round sends it again. A row
    # held back for it would not bring it back, so its failure is counted and
    # coded instead, like the key's, and the outcome goes in all the same.
    benvenuto <- consegna(
      riga[["contact_email"]], NULL,
      mail_welcome_message(
        riga, upn = nato[["upn"]], url = indirizzo_di(riga[["server"]])
      )
    )
    if (isTRUE(benvenuto[["ok"]])) {
      conto[["benvenuti_recapitati"]] <- conto[["benvenuti_recapitati"]] + 1L
    } else {
      conto[["benvenuti_persi"]] <- conto[["benvenuti_persi"]] + 1L
      errori <- c(errori, "POSTA_BENVENUTO_PERSO")
    }
    # To the owner, and not to the `requested_by` the row carries: an import
    # writes that one as it likes. With no owner the key has nowhere to go and
    # is lost and counted: not even IT receives it.
    segreto <- consegna(
      mail_referent(riga), NULL,
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
