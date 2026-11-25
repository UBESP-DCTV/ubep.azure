test_that("ogni parola del vocabolario degli esiti ha le due lingue", {
  # eval
  detto <- lapply(outcome_vocabulary(), mail_outcome_words)

  # test
  for (parola in detto) {
    expect_named(parola, c("it", "en"))
    expect_true(all(nzchar(parola)))
  }
})


test_that("un esito fuori vocabolario si rifiuta invece di inventarsi", {
  expect_error(mail_outcome_words("inventato"), "fuori vocabolario")
})


test_that("l'ora del registro e' UTC e quella della mail e' italiana", {
  # eval
  detto <- mail_local_time("2026-08-24 12:04")

  # test
  expect_equal(detto, "2026-08-24 14:04")
})


test_that("un `outcome_at` che non e' una data non diventa un'ora sbagliata", {
  expect_true(is.na(mail_local_time("")))
  expect_true(is.na(mail_local_time("mai")))
})


test_that("la data limite e' la creazione a Roma piu' 59 giorni", {
  # test
  # 59 and not 60: the person reads "entro il" as "up to that day included",
  # while the key can stop working at any hour of the sixtieth day.
  expect_equal(
    mail_first_signin_deadline("2026-10-23T10:00:00Z"), "2026-12-21"
  )
  expect_equal(
    mail_first_signin_deadline("2027-12-31T12:00:00Z"), "2028-02-28"
  )
})


test_that("la data limite conta il giorno di Roma, non quello UTC", {
  # test
  # At 23:30 UTC it is already the next day in Rome, and the day the account
  # was born is the one the person lives in. Counted from the UTC day the
  # deadline would fall one day before; the opposite mistake, on an account
  # born just after midnight in Rome, would promise a day the key may not have.
  expect_equal(
    mail_first_signin_deadline("2026-10-23T23:30:00Z"), "2026-12-22"
  )
  expect_equal(
    mail_first_signin_deadline("2026-10-23T21:30:00Z"), "2026-12-21"
  )
})


test_that("la data limite regge le due notti del cambio d'ora", {
  # test
  # Autumn 2026: the clocks go back at 01:00 UTC on 25 October. Before it Rome
  # is two hours ahead, after it one, so 22:30 UTC is past midnight the night
  # before and not the night after.
  expect_equal(
    mail_first_signin_deadline("2026-10-24T22:30:00Z"), "2026-12-23"
  )
  expect_equal(
    mail_first_signin_deadline("2026-10-25T22:30:00Z"), "2026-12-23"
  )
  expect_equal(
    mail_first_signin_deadline("2026-10-25T23:30:00Z"), "2026-12-24"
  )
  # Spring 2027: the clocks go forward at 01:00 UTC on 28 March.
  expect_equal(
    mail_first_signin_deadline("2027-03-27T22:30:00Z"), "2027-05-25"
  )
  expect_equal(
    mail_first_signin_deadline("2027-03-28T22:30:00Z"), "2027-05-27"
  )
})


test_that("la data limite legge le frazioni di secondo di Graph", {
  expect_equal(
    mail_first_signin_deadline("2026-10-23T10:00:00.1234567Z"), "2026-12-21"
  )
})


test_that("un istante illeggibile non diventa una data limite sbagliata", {
  # A wrong deadline is worse than a missing one: the person would plan on it.
  expect_true(is.na(mail_first_signin_deadline("")))
  expect_true(is.na(mail_first_signin_deadline("ieri")))
  expect_true(is.na(mail_first_signin_deadline(NA_character_)))
  expect_true(is.na(mail_first_signin_deadline(NULL)))
})


test_that("la data limite rifiuta un istante che non finisce con Z", {
  # An offset read as if it were UTC moves the birth by hours: 23:30 at +02:00
  # is 21:30 UTC, still the 23rd in Rome, and read as 23:30 UTC it would be
  # the 24th, one day late. Graph writes UTC with a final Z, and anything else
  # gets no date rather than a wrong one.
  expect_true(is.na(mail_first_signin_deadline("2026-10-23T23:30:00+02:00")))
  expect_true(is.na(mail_first_signin_deadline("2026-10-23T23:30:00")))
  expect_true(is.na(mail_first_signin_deadline("2026-10-23T10:00:00Z ieri")))
  expect_true(is.na(mail_first_signin_deadline("2026-10-23T10:00:00ZZ")))
})


test_that("l'oggetto porta le due lingue e il numero della richiesta", {
  # eval
  detto <- mail_outcome_message(riga_di_prova())

  # test
  expect_equal(
    detto[["subject"]],
    "Richiesta 16: errore di dato / Request 16: data error"
  )
})


test_that("il corpo porta le due lingue, separate", {
  # eval
  detto <- mail_outcome_message(riga_di_prova())[["body"]]

  # test
  expect_match(detto, "La richiesta 16", fixed = TRUE)
  expect_match(detto, "Request 16", fixed = TRUE)
  expect_match(detto, "\n---\n", fixed = TRUE)
})


test_that("un account disattivato non e' detto tornare in coda da solo", {
  # eval
  disattivato <- mail_outcome_message(riga_di_prova(
    outcome = "transport_error",
    outcome_detail = "TRASPORTO_ACCOUNT_DISATTIVATO"
  ))[["body"]]
  altro <- mail_outcome_message(riga_di_prova(
    outcome = "transport_error",
    outcome_detail = "TRASPORTO_POSTA_RIFIUTATA"
  ))[["body"]]

  # test
  expect_match(
    disattivato,
    paste0(
      "L'account della persona e' disattivato, di solito perche' non e' ",
      "mai entrata."
    ),
    fixed = TRUE
  )
  expect_match(disattivato, "rispondi a questo messaggio", fixed = TRUE)
  expect_match(
    disattivato,
    paste0(
      "The person's account is deactivated, usually because they never ",
      "signed in."
    ),
    fixed = TRUE
  )
  expect_match(disattivato, "reply to this message", fixed = TRUE)
  expect_false(grepl("torna in coda da sola", disattivato, fixed = TRUE))
  expect_false(
    grepl("returns to the queue by itself", disattivato, fixed = TRUE)
  )
  expect_match(disattivato, "DATO_ riguarda", fixed = TRUE)

  expect_match(altro, "torna in coda da sola", fixed = TRUE)
  expect_false(grepl("account della persona", altro, fixed = TRUE))
})


# The fields of a row stopped on a collision: `sara.collaudozeta` is
# somebody else's account, and the round proposes `.2`.
collisione_di_prova <- list(
  username = "sara.collaudozeta.2@ubep.unipd.it", identity = "collision",
  composed = "sara.collaudozeta@ubep.unipd.it",
  outcome_detail =
    "DATO_IDENTITA_IN_COLLISIONE:sara.collaudozeta.2@ubep.unipd.it"
)


test_that("il messaggio di una collisione spiega le due risposte e nomina il campo", { # nolint: line_length_linter.
  # eval
  detto <- mail_outcome_message(
    do.call(riga_di_prova, collisione_di_prova)
  )[["body"]]
  altro <- mail_outcome_message(riga_di_prova())[["body"]]

  # test
  # The two answers, in both languages: another person, and the field to
  # paste the proposal into, with what follows; the same person, and what
  # to correct instead.
  for (frase in c(
    paste0(
      "Se quell'account non e' la persona di questa riga, incolla il nome ",
      "utente proposto"
    ),
    "\"Another person: create this username\" (distinct_username)",
    paste0(
      "al giro successivo il canale crea l'account con quel nome, manda a te ",
      "la chiave e alla persona il benvenuto"
    ),
    "La risposta vale solo per questa proposta",
    paste0(
      "Se e' la stessa persona, lascia vuoto il campo: correggi nome o ",
      "cognome della riga, oppure scrivi a IT se e' sbagliato l'account."
    ),
    "aspetta l'approvazione del referente della riga, oppure di IT",
    paste0(
      "If that account is not the person this row is for, paste the ",
      "proposed username"
    ),
    paste0(
      "on the next round the channel creates the account with that name, ",
      "and sends you the key and the person the welcome"
    ),
    "The answer holds for this proposal only",
    paste0(
      "If it is the same person, leave the field blank: correct the row's ",
      "first or last name, or write to IT if the account is wrong."
    ),
    "waits for the approval of whoever owns the row, or of IT"
  )) {
    expect_match(detto, frase, fixed = TRUE)
  }
  expect_false(grepl("distinct_username", altro, fixed = TRUE))
})


test_that("il messaggio di una collisione su una riga eseguita non invita a incollare e rimanda a IT", { # nolint: line_length_linter.
  # eval
  # The seal the round believes comes as `seal_carried`; the field of the
  # register, `applied_seal`, stands when the round did not say.
  dal_giro <- mail_outcome_message(do.call(
    riga_di_prova, c(collisione_di_prova, list(seal_carried = "a1b2c3d4e5f6"))
  ))[["body"]]
  dal_campo <- mail_outcome_message(do.call(
    riga_di_prova, c(collisione_di_prova, list(applied_seal = "a1b2c3d4e5f6"))
  ))[["body"]]
  mai_eseguita <- mail_outcome_message(
    do.call(riga_di_prova, collisione_di_prova)
  )[["body"]]
  # The field holds a seal the channel never wrote: the round says so with
  # an empty `seal_carried`, and the row is as one never carried out.
  dal_campo_altrui <- mail_outcome_message(do.call(
    riga_di_prova, c(
      collisione_di_prova,
      list(applied_seal = "a1b2c3d4e5f6", seal_carried = "")
    )
  ))[["body"]]

  # test
  # Pasting the proposal into a row already carried out ends on
  # `TRASPORTO_IDENTITA_CAMBIATA` and creates nothing: the message sends the
  # referent to IT and does not ask for a paste.
  for (corpo in list(dal_giro, dal_campo)) {
    expect_false(grepl("incolla", corpo, ignore.case = TRUE))
    expect_false(grepl("paste", corpo, ignore.case = TRUE))
    expect_false(grepl("distinct_username", corpo, fixed = TRUE))
    expect_false(
      grepl("
    sara.collaudozeta.2@ubep.unipd.it
", corpo)
    )
    expect_match(
      corpo, "e' di un account con nome o cognome diversi", fixed = TRUE
    )
    expect_match(corpo, "belongs to an account with a different", fixed = TRUE)
    expect_match(corpo, "La richiesta e' gia' stata eseguita", fixed = TRUE)
    expect_match(
      corpo, "The request has already been carried out", fixed = TRUE
    )
    expect_match(corpo, "scrivi a IT", fixed = TRUE)
    expect_match(corpo, "write to IT", fixed = TRUE)
  }
  # The rows never carried out keep the message they had.
  for (corpo in list(mai_eseguita, dal_campo_altrui)) {
    expect_match(corpo, "paste the proposed username", fixed = TRUE)
    expect_match(corpo, "distinct_username", fixed = TRUE)
    expect_false(
      grepl("La richiesta e' gia' stata eseguita", corpo, fixed = TRUE)
    )
  }
})


test_that("il messaggio di una collisione dice di riscrivere una risposta data prima della proposta", { # nolint: line_length_linter.
  # eval
  detto <- mail_outcome_message(
    do.call(riga_di_prova, collisione_di_prova)
  )[["body"]]

  # test
  # An answer written before the round wrote the proposal does not count
  # (`log_answer_stands()`), and the referent who filled it in early sees
  # the proposal already in the field. REDCap logs no write that leaves a
  # value as it was, so the message says to empty it first.
  for (frase in c(
    paste0(
      "Se il campo porta gia' questo nome, scritto prima di questo ",
      "messaggio, non vale: svuotalo, salva la riga e incollalo di nuovo."
    ),
    paste0(
      "If the field already holds this name, written before this message, ",
      "it does not count: empty it, save the row and paste it again."
    )
  )) {
    expect_match(detto, frase, fixed = TRUE)
  }
})


test_that("il messaggio di una collisione porta il nome occupato e la proposta", { # nolint: line_length_linter.
  # eval
  detto <- mail_outcome_message(
    do.call(riga_di_prova, collisione_di_prova)
  )[["body"]]
  # A row stopped before the code carried the proposal, and a round that
  # did not say which name it composed.
  vecchia <- mail_outcome_message(do.call(
    riga_di_prova,
    utils::modifyList(collisione_di_prova, list(
      outcome_detail = "DATO_IDENTITA_IN_COLLISIONE", composed = NULL
    ))
  ))[["body"]]

  # test
  # The name taken, which the referent looks up in the directory, and the
  # proposal written out on a line of its own, to be pasted as it is.
  expect_match(
    detto,
    paste0(
      "Il nome utente composto da nome e cognome della riga, ",
      "sara.collaudozeta@ubep.unipd.it, e' di un account con nome o cognome ",
      "diversi."
    ),
    fixed = TRUE
  )
  expect_match(
    detto,
    paste0(
      "The username composed from the row's first and last name, ",
      "sara.collaudozeta@ubep.unipd.it, belongs to an account with a ",
      "different first or last name."
    ),
    fixed = TRUE
  )
  expect_match(
    detto, "\n    sara.collaudozeta.2@ubep.unipd.it\n", fixed = TRUE
  )
  expect_match(
    vecchia,
    "Il nome utente composto da nome e cognome della riga e' di un account",
    fixed = TRUE
  )
  expect_match(
    vecchia, "\n    sara.collaudozeta.2@ubep.unipd.it\n", fixed = TRUE
  )
})


# A collision on a composed name free on Entra and known to REDCap (item 4
# (b') of the 0.26.0): the same code, another paragraph.
collisione_nota_a_redcap <- utils::modifyList(
  collisione_di_prova, list(known_to_redcap = TRUE)
)


test_that("una collisione su un nome noto a REDCap non manda a guardare la rubrica", { # nolint: line_length_linter.
  # eval
  detto <- mail_outcome_message(
    do.call(riga_di_prova, collisione_nota_a_redcap)
  )[["body"]]

  # test
  # Nobody on Entra holds the name: no account to look up, no "same person"
  # answer, and the proposal to paste.
  expect_false(grepl("nome o cognome diversi", detto, fixed = TRUE))
  expect_false(grepl("different first or last name", detto, fixed = TRUE))
  expect_false(grepl("lascia vuoto il campo", detto, fixed = TRUE))
  expect_false(grepl("leave the field blank", detto, fixed = TRUE))
  for (frase in c(
    paste0(
      "Il nome utente composto da nome e cognome della riga, ",
      "sara.collaudozeta@ubep.unipd.it, non e' di nessun account su Entra, ",
      "ma REDCap ricorda ancora un login con quel nome"
    ),
    "la sola risposta e' incollare il nome utente proposto",
    "\n    sara.collaudozeta.2@ubep.unipd.it\n",
    "\"Another person: create this username\" (distinct_username)",
    "La risposta vale solo per questa proposta",
    "non ritrova i progetti del vecchio login",
    "belongs to no account on Entra, but REDCap still remembers a login",
    "the only answer is to paste the proposed username",
    "do not find the old login's projects",
    "DATO_IDENTITA_IN_COLLISIONE:sara.collaudozeta.2@ubep.unipd.it"
  )) {
    expect_match(detto, frase, fixed = TRUE)
  }
})


test_that("una collisione su Entra tiene il testo di sempre", {
  # eval
  # `known_to_redcap` false, or not said by the caller.
  detti <- lapply(
    list(
      collisione_di_prova,
      utils::modifyList(collisione_di_prova, list(known_to_redcap = FALSE))
    ),
    function(campi) {
      mail_outcome_message(do.call(riga_di_prova, campi))[["body"]]
    }
  )

  # test
  for (detto in detti) {
    expect_match(detto, "e' di un account con nome o cognome diversi",
                 fixed = TRUE)
    expect_false(grepl("REDCap ricorda", detto, fixed = TRUE))
  }
})


test_that("una collisione su un nome noto a REDCap, su una riga eseguita, resta quella di L5", { # nolint: line_length_linter.
  # eval
  detto <- mail_outcome_message(do.call(
    riga_di_prova,
    c(collisione_nota_a_redcap, list(seal_carried = "a1b2c3d4e5f6"))
  ))[["body"]]

  # test
  expect_match(detto, "La richiesta e' gia' stata eseguita", fixed = TRUE)
  expect_false(grepl("incolla", detto, ignore.case = TRUE))
  expect_false(grepl("REDCap ricorda", detto, fixed = TRUE))
})


test_that("un campo vuoto cambia la frase invece di lasciare un buco", {
  # eval
  detto <- mail_outcome_message(
    riga_di_prova(username = "", applied_as = "")
  )[["body"]]

  # test
  expect_match(detto, "non ancora stabilito", fixed = TRUE)
  expect_match(detto, "l'istanza non ha risposto", fixed = TRUE)
  expect_false(grepl("Nome utente risolto: \n", detto, fixed = TRUE))
})


test_that("una revoca eseguita non dice che un accesso e' stato concesso", {
  # eval
  detto <- mail_outcome_message(riga_di_prova(
    outcome = "applied", outcome_detail = "",
    request_status = "revoked", applied_as = "absent"
  ))[["body"]]

  # test
  expect_match(detto, "l'accesso e' stato tolto", fixed = TRUE)
  expect_false(grepl("l'accesso e' stato concesso", detto, fixed = TRUE))
})


test_that("una riga scaduta chiusa sulla persona tolta non dice che un accesso e' stato concesso", { # nolint: line_length_linter.
  # eval
  detto <- mail_outcome_message(riga_di_prova(
    outcome = "applied", outcome_detail = "",
    request_status = "active", applied_as = "absent"
  ))[["body"]]
  concesso <- mail_outcome_message(riga_di_prova(
    outcome = "applied", outcome_detail = "",
    request_status = "active",
    applied_as = "role_name=data entry; dag_name=; expiration="
  ))[["body"]]

  # test
  expect_match(
    detto, "la persona non e' piu' sul progetto", fixed = TRUE
  )
  expect_match(
    detto, "the person is no longer on the project", fixed = TRUE
  )
  expect_false(grepl("l'accesso e' stato concesso", detto, fixed = TRUE))
  expect_false(grepl("has been granted", detto, fixed = TRUE))
  # An access that was granted still says so.
  expect_match(concesso, "l'accesso e' stato concesso", fixed = TRUE)
})


test_that("una riga con la scadenza gia' raggiunta non dice che un accesso e' stato concesso", { # nolint: line_length_linter.
  # eval
  scaduta <- "role_name=x; dag_name=; expiration=2026-11-01"
  detto <- mail_status_words("active", scaduta, at = "2026-11-12 03:00")

  # test
  # The person is on the project and REDCap does not let them in: neither
  # "granted" nor "the person is gone".
  expect_match(detto[["it"]], "e' passato", fixed = TRUE)
  expect_match(detto[["it"]], "REDCap non la fa entrare", fixed = TRUE)
  expect_match(detto[["en"]], "has passed", fixed = TRUE)
  expect_match(detto[["en"]], "REDCap does not let them in", fixed = TRUE)
  expect_false(grepl("concesso", detto[["it"]], fixed = TRUE))
  expect_false(grepl("granted", detto[["en"]], fixed = TRUE))
})


test_that("la scadenza uguale al giorno del giro e' raggiunta, quella del giorno dopo no", { # nolint: line_length_linter.
  # The stored day is the one after the last: on it REDCap no longer lets the
  # person in, the same rule as `validate_request()`.
  ogni <- function(giorno) {
    mail_status_words(
      "active", paste0("role_name=x; dag_name=; expiration=", giorno),
      at = "2026-11-12 03:00"
    )
  }
  expect_match(ogni("2026-11-12")[["it"]], "e' passato", fixed = TRUE)
  expect_match(
    ogni("2026-11-13")[["it"]], "l'accesso e' stato concesso", fixed = TRUE
  )
})


test_that("la scadenza si legge sul giorno di Roma del giro, non su quello UTC", { # nolint: line_length_linter.
  # The round is at 23:30 UTC on the 24th, already the 25th in Rome, where
  # REDCap judges: an expiration stored on the 25th no longer lets the
  # person in. At 22:30 UTC Rome is still on the 24th.
  ogni <- function(at) {
    mail_status_words(
      "active", "role_name=x; dag_name=; expiration=2026-11-25", at = at
    )
  }
  expect_match(ogni("2026-11-24 23:30")[["it"]], "e' passato", fixed = TRUE)
  expect_match(
    ogni("2026-11-24 23:30")[["en"]], "REDCap does not let them in",
    fixed = TRUE
  )
  expect_match(
    ogni("2026-11-24 22:30")[["it"]], "l'accesso e' stato concesso",
    fixed = TRUE
  )
  # A bare date is the day itself.
  expect_match(ogni("2026-11-25")[["it"]], "e' passato", fixed = TRUE)
  expect_match(
    ogni("2026-11-24")[["it"]], "l'accesso e' stato concesso", fixed = TRUE
  )
})


test_that("senza una scadenza leggibile o senza data del giro una riga attiva dice concesso", { # nolint: line_length_linter.
  concesso <- c(
    it = "l'accesso e' stato concesso", en = "the access has been granted"
  )
  at <- "2026-11-12 03:00"
  expect_equal(
    mail_status_words("active", "role_name=x; dag_name=; expiration=", at),
    concesso
  )
  expect_equal(mail_status_words("active", "", at), concesso)
  expect_equal(mail_status_words("active", "role_name=x", at), concesso)
  expect_equal(
    mail_status_words("active", "expiration=2026-11-01", at = ""), concesso
  )
  expect_equal(
    mail_status_words("active", "expiration=2026-11-01"), concesso
  )
})


test_that("una revoca e una riga absent dicono come prima anche con la scadenza passata", { # nolint: line_length_linter.
  at <- "2026-11-12 03:00"
  passata <- "role_name=x; dag_name=; expiration=2026-11-01"
  expect_equal(
    mail_status_words("revoked", passata, at)[["it"]],
    "l'accesso e' stato tolto"
  )
  expect_match(
    mail_status_words("active", "absent", at)[["it"]],
    "non e' piu' sul progetto", fixed = TRUE
  )
})


test_that("il messaggio d'esito di una riga con la scadenza gia' raggiunta dice che l'ultimo giorno e' passato", { # nolint: line_length_linter.
  # eval
  detto <- mail_outcome_message(riga_di_prova(
    outcome = "applied", outcome_detail = "", request_status = "active",
    applied_as = "role_name=data entry; dag_name=; expiration=2026-08-24",
    outcome_at = "2026-08-24 12:04"
  ))[["body"]]

  # test
  expect_match(
    detto, "l'ultimo giorno di accesso della richiesta", fixed = TRUE
  )
  expect_match(
    detto, "the last day of access of the request has passed", fixed = TRUE
  )
  expect_false(grepl("l'accesso e' stato concesso", detto, fixed = TRUE))
})


test_that("l'ora nel corpo e' quella italiana, e nomina il fuso", {
  # eval
  detto <- mail_outcome_message(riga_di_prova())[["body"]]

  # test
  expect_match(detto, "2026-08-24 14:04", fixed = TRUE)
  expect_match(detto, "ora italiana", fixed = TRUE)
})


test_that("le istruzioni di primo accesso non portano nessun segreto", {
  # eval
  detto <- mail_welcome_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it"
  )[["body"]]

  # test
  expect_match(detto, "sara.collaudozeta@ubep.unipd.it", fixed = TRUE)
  expect_match(detto, "cinzia@ubep.unipd.it", fixed = TRUE)
  expect_match(detto, "second factor", fixed = TRUE)
  expect_false(grepl(finti[["parola"]], detto, fixed = TRUE))
})


test_that("il benvenuto nomina il proprietario, non chi la riga nomina", {
  # eval
  importata <- mail_welcome_message(
    riga_di_prova(
      requested_by = "nominato.da.import@example.org",
      owner = "proprietaria.riga@example.org"
    ),
    upn = "sara.collaudozeta@ubep.unipd.it"
  )[["body"]]
  senza_proprietario <- mail_welcome_message(
    riga_di_prova(owner = ""), upn = "sara.collaudozeta@ubep.unipd.it"
  )[["body"]]

  # test
  # The welcome tells the person who will hand them the key, and the key goes
  # to the row's owner: naming the address the CSV carried would send the
  # person to wait for somebody who never receives it.
  expect_match(
    importata, "te la consegna proprietaria.riga@example.org", fixed = TRUE
  )
  expect_match(
    importata, "proprietaria.riga@example.org will hand it to you",
    fixed = TRUE
  )
  expect_no_match(importata, "nominato.da.import@example.org", fixed = TRUE)
  expect_match(
    senza_proprietario,
    "te la consegna il referente che ha chiesto l'account per te.",
    fixed = TRUE
  )
  expect_match(
    senza_proprietario,
    "the referent who requested the account for you will hand it to you.",
    fixed = TRUE
  )
  expect_false(grepl("[^\\x01-\\x7F]", senza_proprietario, perl = TRUE))
  expect_no_match(senza_proprietario, "cinzia@ubep.unipd.it", fixed = TRUE)
})


test_that("il benvenuto dice da dove si apre REDCap, nelle due lingue", {
  # eval
  detto <- mail_welcome_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    url = "https://edc10.example.org/redcap/"
  )[["body"]]

  # test
  expect_match(
    detto, "REDCap si apre da: https://edc10.example.org/redcap/",
    fixed = TRUE
  )
  expect_match(
    detto, "REDCap opens at: https://edc10.example.org/redcap/", fixed = TRUE
  )
  expect_match(detto, "di norma entro quattro ore.", fixed = TRUE)
  expect_match(detto, "normally within four hours.", fixed = TRUE)
})


test_that("l'indirizzo dell'istanza segue il nome utente, non la chiave", {
  # eval
  righe <- strsplit(mail_welcome_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    url = "https://edc10.example.org/"
  )[["body"]], "\n", fixed = TRUE)[[1]]
  dove <- function(testo) grep(testo, righe, fixed = TRUE)

  # test
  # In each language: the user name, then the address and the four hours, then
  # who hands over the key. The rest of the message is where it was.
  expect_true(dove("ti autentichi")[[1]] < dove("REDCap si apre da")[[1]])
  expect_true(dove("REDCap si apre da")[[1]] < dove("quattro ore")[[1]])
  expect_true(dove("quattro ore")[[1]] < dove("non e' in questo")[[1]])
  expect_true(dove("sign in with")[[1]] < dove("REDCap opens at")[[1]])
  expect_true(dove("REDCap opens at")[[1]] < dove("four hours")[[1]])
  expect_true(dove("four hours")[[1]] < dove("The way in is not")[[1]])
})


test_that("senza indirizzo dell'istanza il benvenuto parte com'era", {
  # eval
  riga <- riga_di_prova()
  upn <- "sara.collaudozeta@ubep.unipd.it"
  com_era <- mail_welcome_message(riga, upn = upn)

  # test
  # A missing address is not a reason to lose the message: it leaves without
  # the two lines, and otherwise exactly as it did before they existed.
  for (url in list(NULL, NA_character_, "")) {
    detto <- mail_welcome_message(riga, upn = upn, url = url)
    expect_identical(detto, com_era)
    expect_false(grepl("REDCap si apre da", detto[["body"]], fixed = TRUE))
    expect_false(grepl("quattro ore", detto[["body"]], fixed = TRUE))
    expect_false(grepl("REDCap opens at", detto[["body"]], fixed = TRUE))
    expect_match(detto[["body"]], upn, fixed = TRUE)
  }
})


test_that("il benvenuto promette un'altra mail e manda prima al referente", {
  con <- mail_welcome_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    url = "https://edc10.example.org/"
  )[["body"]]
  senza_url <- mail_welcome_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it"
  )[["body"]]
  senza_referente <- mail_welcome_message(
    riga_di_prova(owner = ""), upn = "sara.collaudozeta@ubep.unipd.it"
  )[["body"]]

  expect_match(con, paste0(
    "Quando l'accesso al progetto sara' pronto riceverai un'altra mail, ",
    "di norma entro quattro ore."
  ), fixed = TRUE)
  expect_match(con, paste0(
    "When access to the project is ready you will receive another ",
    "e-mail, normally within four hours."
  ), fixed = TRUE)
  expect_no_match(senza_url, "quattro ore", fixed = TRUE)
  expect_match(senza_url, paste0(
    "Per qualunque problema scrivi prima a cinzia@ubep.unipd.it, che ha ",
    "chiesto il tuo account e risponde del tuo primo accesso. Se non ",
    "riesci a raggiungerlo, rispondi a questo messaggio: arriva a IT."
  ), fixed = TRUE)
  expect_match(senza_url, paste0(
    "For any problem write first to cinzia@ubep.unipd.it, who requested ",
    "your account and is responsible for your first sign-in. If you ",
    "cannot reach them, reply to this message: it goes to IT."
  ), fixed = TRUE)
  expect_match(senza_referente, paste0(
    "Per qualunque problema scrivi prima al referente che ha chiesto il ",
    "tuo account, che risponde del tuo primo accesso."
  ), fixed = TRUE)
  expect_match(senza_referente, paste0(
    "For any problem write first to the referent who requested your ",
    "account, who is responsible for your first sign-in."
  ), fixed = TRUE)
  for (corpo in c(con, senza_url, senza_referente)) {
    expect_no_match(corpo, "Se qualcosa non torna", fixed = TRUE)
    expect_no_match(corpo, "If anything looks wrong", fixed = TRUE)
    expect_no_match(corpo, "da questo messaggio.", fixed = TRUE)
    expect_false(grepl("[^\\x01-\\x7F]", corpo, perl = TRUE))
  }
})


test_that("la mail di accesso dice dove, come e fino a quando", {
  msg <- mail_access_message(
    riga_di_prova(dag_name = "centro-01", expiration = "2027-01-31",
                  applied_as = "role_name=x; dag_name=; expiration=2027-02-01"),
    url = "https://edc10.example.org/"
  )
  corpo <- msg[["body"]]
  expect_equal(
    msg[["subject"]], "Accesso a REDCap / REDCap access: edc10, progetto 29"
  )
  expect_match(corpo, "ora hai accesso in REDCap al progetto 29 su edc10.",
               fixed = TRUE)
  expect_match(corpo, "you now have access in REDCap to project 29 on edc10.",
               fixed = TRUE)
  expect_match(corpo, "REDCap si apre da: https://edc10.example.org/",
               fixed = TRUE)
  expect_match(corpo, "Ruolo: collaudo-canale", fixed = TRUE)
  expect_match(corpo, "Gruppo: centro-01", fixed = TRUE)
  expect_match(corpo, "Ultimo giorno di accesso: 2027-01-31", fixed = TRUE)
  expect_match(corpo, "Last day of access: 2027-01-31", fixed = TRUE)
  expect_no_match(corpo, "2027-02-01", fixed = TRUE)
  expect_match(corpo, paste0(
    "Del progetto risponde cinzia@ubep.unipd.it, il referente della ",
    "richiesta."
  ), fixed = TRUE)
  expect_match(corpo, paste0(
    "Per qualunque problema scrivi prima a cinzia@ubep.unipd.it, che ha ",
    "chiesto il tuo accesso e risponde del tuo primo accesso. Se non ",
    "riesci a raggiungerlo, rispondi a questo messaggio: arriva a IT."
  ), fixed = TRUE)
  expect_match(corpo, paste0(
    "For any problem write first to cinzia@ubep.unipd.it, who requested ",
    "your access and is responsible for your first sign-in. If you ",
    "cannot reach them, reply to this message: it goes to IT."
  ), fixed = TRUE)
  expect_match(corpo, "\n---\n", fixed = TRUE)
  expect_false(grepl("[^\\x01-\\x7F]", corpo, perl = TRUE))
})


test_that("senza gruppo, scadenza o indirizzo le righe cambiano o mancano", {
  corpo <- mail_access_message(riga_di_prova())[["body"]]
  expect_no_match(corpo, "Gruppo:", fixed = TRUE)
  expect_no_match(corpo, "REDCap si apre da", fixed = TRUE)
  for (url in list(NULL, NA_character_, "")) {
    detto <- mail_access_message(riga_di_prova(), url = url)[["body"]]
    expect_no_match(detto, "REDCap si apre da", fixed = TRUE)
    expect_no_match(detto, "REDCap opens at", fixed = TRUE)
  }
  expect_match(
    corpo, "Ultimo giorno di accesso: nessuno, l'accesso non scade.",
    fixed = TRUE
  )
  expect_match(
    corpo, "Last day of access: none, the access does not expire.",
    fixed = TRUE
  )
})


test_that("la mail di accesso non porta segreti", {
  # The fake secret sits in the fields it could leak from if the function read
  # the wrong one: what was applied, why a row failed, the unverified address.
  corpo <- mail_access_message(riga_di_prova(
    applied_as = finti[["parola"]], outcome_detail = finti[["parola"]],
    contact_email = finti[["parola"]]
  ))[["body"]]
  expect_false(grepl(finti[["parola"]], corpo, fixed = TRUE))
  expect_no_match(corpo, "Chiave", fixed = TRUE)
})


test_that("senza proprietario la mail di accesso non nomina nessuno", {
  corpo <- mail_access_message(riga_di_prova(owner = ""))[["body"]]
  expect_no_match(corpo, "Del progetto risponde", fixed = TRUE)
  expect_no_match(corpo, "answers for the project", fixed = TRUE)
  expect_match(corpo, paste0(
    "Per qualunque problema scrivi prima al referente che ha chiesto il ",
    "tuo accesso, che risponde del tuo primo accesso. Se non riesci a ",
    "raggiungerlo, rispondi a questo messaggio: arriva a IT."
  ), fixed = TRUE)
  expect_match(corpo, paste0(
    "For any problem write first to the referent who requested your ",
    "access, who is responsible for your first sign-in. If you cannot ",
    "reach them, reply to this message: it goes to IT."
  ), fixed = TRUE)
  expect_false(grepl("[^\\x01-\\x7F]", corpo, perl = TRUE))
})


test_that("l'indirizzo dell'istanza si compone dall'host dell'inventario", {
  # test
  expect_equal(
    mail_instance_url("edc03.example.org"), "https://edc03.example.org/"
  )
  expect_equal(
    mail_instance_url("edc01.example.org/redcap"),
    "https://edc01.example.org/redcap/"
  )
  # The same normalization `module_call()` makes, so a host the instances
  # answer on cannot turn into an address nobody can open.
  expect_equal(
    mail_instance_url("https://edc01.example.org/redcap/"),
    "https://edc01.example.org/redcap/"
  )
  expect_null(mail_instance_url(NULL))
  expect_null(mail_instance_url(NA_character_))
  expect_null(mail_instance_url(""))
})


test_that("il messaggio d'ingresso non nomina istanza, progetto, ruolo", {
  # eval
  detto <- mail_credential_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    credential = finti[["parola"]]
  )[["body"]]

  # test
  expect_match(detto, finti[["parola"]], fixed = TRUE)
  expect_false(grepl("edc10", detto, fixed = TRUE))
  expect_false(grepl("29", detto, fixed = TRUE))
  expect_false(grepl("collaudo-canale", detto, fixed = TRUE))
})


test_that("il messaggio con la chiave dice come consegnarla", {
  # eval
  detto <- mail_credential_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    credential = finti[["parola"]]
  )[["body"]]

  # test
  # The rule the referent follows, decided on 2026-10-14: a new message with
  # the key alone, to the address they know, never a forward of this one.
  it <- c(
    paste0(
      "Consegna la chiave alla persona, e non inoltrare questo messaggio. Se ",
      "hai un canale diverso dalla posta, usa quello; altrimenti scrivile una ",
      "mail nuova con il testo pronto qui sotto, che porta la chiave senza il ",
      "nome utente: il nome utente le e' gia' arrivato in un messaggio a ",
      "parte. Usa l'indirizzo che conosci dalla tua ",
      "corrispondenza con lei, non quello copiato dalla richiesta. Se i due ",
      "non coincidono, fermati e rispondi a questo messaggio senza la chiave ",
      "(togli il testo citato): quel messaggio a parte e' andato ",
      "all'indirizzo della richiesta."
    ),
    "Va cambiata al primo accesso, e chi la usa per prima si prende l'account."
  )
  en <- c(
    paste0(
      "Hand the key to the person, and do not forward this message. If you ",
      "have a channel other than e-mail, use it; otherwise write them a new ",
      "e-mail with the ready text below, which carries the key without the ",
      "user name: the user name has already reached them in a separate ",
      "message. Use the address you know from your own ",
      "correspondence with them, not the one copied from the request. If the ",
      "two differ, stop and reply to this message without the key (delete ",
      "the quoted text): that separate message went to the address in the ",
      "request."
    ),
    paste0(
      "It must be changed at first sign-in, and whoever uses it first takes ",
      "the account."
    )
  )
  righe <- strsplit(detto, "\n", fixed = TRUE)[[1]]
  for (frase in c(it, en)) {
    expect_true(frase %in% righe, info = frase)
  }
  expect_false(grepl("per una via sicura", detto, fixed = TRUE))
  expect_false(grepl("Hand it over securely", detto, fixed = TRUE))
})


test_that("la risposta chiesta dal messaggio con la chiave la lascia fuori", {
  # eval
  detto <- mail_credential_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    credential = finti[["parola"]]
  )[["body"]]

  # test
  # A reply goes to reply_to, the shared mailbox of IT, and a mail client
  # quotes the body by default: the key, still unused, would land there. So
  # the very sentence that asks for a reply says to leave the key out of it.
  expect_match(
    detto, "rispondi a questo messaggio senza la chiave", fixed = TRUE
  )
  expect_match(detto, "reply to this message without the key", fixed = TRUE)
})


test_that("il messaggio con la chiave non porta il contesto della persona", {
  # eval
  riga <- riga_di_prova()
  detto <- mail_credential_message(
    riga, upn = "sara.collaudozeta@ubep.unipd.it",
    credential = finti[["parola"]]
  )[["body"]]

  # test
  # It tells the referent to use the address they know, and does not name the
  # one in the request: copying it from here is what the rule forbids.
  expect_false(grepl(riga[["contact_email"]], detto, fixed = TRUE))
  expect_false(grepl(riga[["last_name"]], detto, fixed = TRUE))
  expect_false(grepl("https://", detto, fixed = TRUE))
})


test_that("nessun altro messaggio puo' nominare la chiave d'ingresso", {
  # eval
  riga <- riga_di_prova()
  altri <- list(
    mail_outcome_message(riga)[["body"]],
    mail_welcome_message(riga, upn = "sara@ubep.unipd.it")[["body"]],
    mail_welcome_message(
      riga, upn = "sara@ubep.unipd.it", url = "https://edc10.example.org/"
    )[["body"]]
  )

  # test
  for (corpo in altri) {
    expect_false(grepl(finti[["parola"]], corpo, fixed = TRUE))
  }
})


# The body with the wrapped lines of a list item joined, so a sentence can be
# asserted whole wherever the text breaks it.
disteso <- function(corpo) gsub("\n  ", " ", corpo, fixed = TRUE)


test_that("il benvenuto dice entro quando entrare, nelle due lingue", {
  # eval
  detto <- disteso(mail_welcome_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    deadline = "2026-12-21"
  )[["body"]])

  # test
  for (frase in c(
    "Primo accesso entro il 2026-12-21.",
    paste0(
      "- Dopo quella data la chiave d'ingresso non vale piu': chiedine una ",
      "nuova al tuo referente."
    ),
    paste0(
      "- Senza primo accesso l'account viene disattivato, non cancellato. ",
      "Per riattivarlo scrivi al tuo referente; se non lo raggiungi, ",
      "rispondi a questo messaggio (arriva a IT)."
    ),
    "First sign-in by 2026-12-21.",
    paste0(
      "- After that date your sign-in key no longer works: ask your ",
      "referent for a new one."
    ),
    paste0(
      "- If you never sign in, your account is deactivated, not deleted. ",
      "To reactivate it, write to your referent; if you cannot reach them, ",
      "reply to this message (it goes to IT)."
    )
  )) {
    expect_match(detto, frase, fixed = TRUE, info = frase)
  }
  expect_false(grepl("[^\\x01-\\x7F]", detto, perl = TRUE))
  # One date and one thing to do: the deadline, once in each language, and no
  # other date beside it.
  expect_equal(
    regmatches(detto, gregexpr("[0-9]{4}-[0-9]{2}-[0-9]{2}", detto))[[1]],
    rep("2026-12-21", 2L)
  )
})


test_that("la data limite sta fra la chiave e i passi del primo accesso", {
  # eval
  righe <- strsplit(mail_welcome_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    url = "https://edc10.example.org/", deadline = "2026-12-21"
  )[["body"]], "\n", fixed = TRUE)[[1]]
  dove <- function(testo) grep(testo, righe, fixed = TRUE)[[1]]

  # test
  # After the user name and the word that the key comes from the referent,
  # before the steps: the date is about the key, and the steps are what to do
  # with it.
  expect_true(dove("ti autentichi") < dove("Primo accesso entro"))
  expect_true(dove("non e' in questo") < dove("Primo accesso entro"))
  expect_true(dove("Primo accesso entro") < dove("Al primo accesso ti"))
  expect_true(dove("sign in with") < dove("First sign-in by"))
  expect_true(dove("The way in is not") < dove("First sign-in by"))
  expect_true(dove("First sign-in by") < dove("At first sign-in you"))
})


test_that("senza data limite il benvenuto parte com'era", {
  # eval
  riga <- riga_di_prova()
  upn <- "sara.collaudozeta@ubep.unipd.it"
  com_era <- mail_welcome_message(riga, upn = upn)

  # test
  for (scadenza in list(NULL, NA_character_, "")) {
    detto <- mail_welcome_message(riga, upn = upn, deadline = scadenza)
    expect_identical(detto, com_era)
    expect_no_match(detto[["body"]], "Primo accesso entro", fixed = TRUE)
  }
})


test_that("il messaggio con la chiave dice al referente entro quando", {
  # eval
  righe <- strsplit(mail_credential_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    credential = finti[["parola"]], deadline = "2026-12-21"
  )[["body"]], "\n", fixed = TRUE)[[1]]
  it <- paste0(
    "Consegnala subito: il primo accesso va fatto entro il 2026-12-21. ",
    "Dopo quella data la chiave non vale piu': per una nuova rispondi a ",
    "questo messaggio senza la chiave (togli il testo citato)."
  )
  en <- paste0(
    "Hand it over now: the first sign-in must happen by 2026-12-21. After ",
    "that date the key no longer works: reply to this message for a new one, ",
    "without the key (delete the quoted text)."
  )
  dove <- function(testo) grep(testo, righe, fixed = TRUE)[[1]]

  # test
  # Under the sentence on how to hand the key over, before the one on what
  # happens at first sign-in.
  expect_true(it %in% righe)
  expect_true(en %in% righe)
  expect_true(dove("Consegna la chiave alla persona") < dove(it))
  expect_true(dove(it) < dove("Va cambiata al primo accesso"))
  expect_true(dove("Hand the key to the person") < dove(en))
  expect_true(dove(en) < dove("It must be changed at first sign-in"))
  expect_false(any(grepl("[^\\x01-\\x7F]", righe, perl = TRUE)))
  # One date: the deadline, once in each language for the referent and once
  # in each ready text for the person, and no other beside it.
  expect_equal(
    unlist(regmatches(righe, gregexpr("[0-9]{4}-[0-9]{2}-[0-9]{2}", righe))),
    rep("2026-12-21", 4L)
  )
})


test_that("senza data limite il messaggio con la chiave parte com'era", {
  # eval
  riga <- riga_di_prova()
  com_era <- mail_credential_message(
    riga, upn = "sara@ubep.unipd.it", credential = finti[["parola"]]
  )

  # test
  for (scadenza in list(NULL, NA_character_, "")) {
    expect_identical(
      mail_credential_message(
        riga, upn = "sara@ubep.unipd.it", credential = finti[["parola"]],
        deadline = scadenza
      ),
      com_era
    )
  }
})


# The ready text of one language, the lines between its two delimiters, and
# where the delimiters sit in the body. Decided on 2026-11-19 with the
# proposal of the first sign-in: a text the referent copies into a new
# e-mail to the person, delimited, because the line with the user name sits
# above it in the same message.
testo_pronto <- function(righe, inizio, fine) {
  da <- which(righe == inizio)
  a <- which(righe == fine)
  list(da = da, a = a, righe = righe[seq.int(da[[1L]] + 1L, a[[1L]] - 1L)])
}
delimitatori <- list(
  it = c(
    "----- INIZIO DEL TESTO DA COPIARE -----",
    "----- FINE DEL TESTO DA COPIARE -----"
  ),
  en = c(
    "----- START OF THE TEXT TO COPY -----",
    "----- END OF THE TEXT TO COPY -----"
  )
)


test_that("il messaggio con la chiave porta un testo pronto per lingua, delimitato", { # nolint: line_length_linter.
  # eval
  upn <- "sara.collaudozeta@ubep.unipd.it"
  righe <- strsplit(mail_credential_message(
    riga_di_prova(), upn = upn, credential = finti[["parola"]],
    deadline = "2026-12-21"
  )[["body"]], "\n", fixed = TRUE)[[1]]
  parti <- lapply(delimitatori, function(d) testo_pronto(righe, d[[1]], d[[2]]))
  dove <- function(testo) grep(testo, righe, fixed = TRUE)[[1]]

  # test
  for (lingua in names(parti)) {
    parte <- parti[[lingua]]
    # Once each, the start before the end, and the line with the user name
    # outside: what the referent copies cannot carry it along.
    expect_length(parte[["da"]], 1L)
    expect_length(parte[["a"]], 1L)
    expect_true(parte[["da"]] < parte[["a"]], info = lingua)
    expect_false(any(grepl(upn, parte[["righe"]], fixed = TRUE)), info = lingua)
    expect_true(finti[["parola"]] %in% parte[["righe"]], info = lingua)
  }
  # Each text in the half of its own language, after what the referent reads.
  expect_true(dove("Va cambiata al primo accesso") < parti[["it"]][["da"]])
  expect_true(parti[["it"]][["a"]] < which(righe == "---"))
  expect_true(which(righe == "---") < dove("Hand the key to the person"))
  expect_true(
    dove("It must be changed at first sign-in") < parti[["en"]][["da"]]
  )
  expect_false(any(grepl("[^\\x01-\\x7F]", righe, perl = TRUE)))
  # The one sentence that tells the referent to add no context to the text,
  # whole, in each half, just before the text it is about.
  istruzione <- list(
    it = paste0(
      "Il testo pronto e' fra le due righe qui sotto: copia solo quello, e ",
      "non aggiungere nome utente, indirizzo di REDCap o progetto, che la ",
      "persona riceve in altre mail. La versione inglese e' nella seconda ",
      "parte di questo messaggio."
    ),
    en = paste0(
      "The ready text is between the two lines below: copy only that, and do ",
      "not add the user name, the REDCap address or the project, which the ",
      "person receives in other e-mails. The Italian version is in the first ",
      "part of this message."
    )
  )
  for (lingua in names(istruzione)) {
    riga_istruzione <- which(righe == istruzione[[lingua]])
    expect_length(riga_istruzione, 1L)
    expect_equal(riga_istruzione, parti[[lingua]][["da"]] - 2L, info = lingua)
  }
})


test_that("il testo pronto porta nome, chiave, data e i passi del primo accesso", { # nolint: line_length_linter.
  # eval
  righe <- strsplit(mail_credential_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    credential = finti[["parola"]], deadline = "2026-12-21"
  )[["body"]], "\n", fixed = TRUE)[[1]]
  unito <- function(d) {
    paste(testo_pronto(righe, d[[1]], d[[2]])[["righe"]], collapse = "\n")
  }
  it <- unito(delimitatori[["it"]])
  en <- unito(delimitatori[["en"]])

  # test
  expect_match(it, "^Ciao Sara,\n")
  expect_match(en, "^Hello Sara,\n")
  for (frase in c(
    "Il primo accesso va fatto entro il 2026-12-21",
    "finestra privata",
    "Microsoft Authenticator",
    "tocca Verified IDs in basso a destra, poi Scan QR code",
    "Il secondo fattore si registra solo con l'app.",
    "Non scegliere Skip for now.",
    "A \"Stay signed in?\" rispondi Yes.",
    "In My Projects apri il progetto. Se non c'e' ancora, aspetta la mail",
    "\"Il tuo account UBEP / Your UBEP account\""
  )) {
    expect_match(it, frase, fixed = TRUE, info = frase)
  }
  for (frase in c(
    "Your first sign-in must happen by 2026-12-21",
    "private (incognito) browser window",
    "Microsoft Authenticator",
    "tap Verified IDs in the bottom right corner, then Scan QR code",
    "The second factor is registered only with the app.",
    "Do not choose Skip for now.",
    "At \"Stay signed in?\" answer Yes.",
    "In My Projects, open the project. If it is not there yet, wait for",
    "\"Il tuo account UBEP / Your UBEP account\""
  )) {
    expect_match(en, frase, fixed = TRUE, info = frase)
  }
  # Authenticator only, by the path checked on a current app on 2026-11-20:
  # no SMS, no call, and not the old path through + and Work or school
  # account.
  for (testo in list(it, en)) {
    expect_false(grepl("SMS", testo, fixed = TRUE))
    expect_false(grepl("Work or school", testo, fixed = TRUE))
    expect_false(grepl("**+**", testo, fixed = TRUE))
  }
})


test_that("il testo pronto chiede l'indirizzo per recuperare la password", {
  # eval
  righe <- strsplit(mail_credential_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    credential = finti[["parola"]], deadline = "2026-12-21"
  )[["body"]], "\n", fixed = TRUE)[[1]]
  passo <- list(
    it = paste0(
      "5. Per recuperare la password Microsoft ti chiede anche un indirizzo ",
      "mail: scrivi un indirizzo tuo che leggi, e poi il codice che ti ",
      "arriva li'. Chiudi con Next e Done."
    ),
    en = paste0(
      "5. To recover your password, Microsoft also asks for an e-mail ",
      "address: enter an address of yours that you read, then the code that ",
      "arrives there. Finish with Next and Done."
    )
  )

  # test
  # Decided on 2026-11-24 with the configuration of Entra: the self-service
  # password reset asks for two methods, Authenticator and an e-mail
  # address, and no longer accepts a phone. The step comes after the one of
  # Authenticator and before Stay signed in?, and names no phone.
  for (lingua in names(passo)) {
    d <- delimitatori[[lingua]]
    testo <- testo_pronto(righe, d[[1]], d[[2]])[["righe"]]
    dove <- function(inizio) grep(paste0("^", inizio), testo)
    expect_true(passo[[lingua]] %in% testo, info = lingua)
    expect_equal(dove("4\\. "), which(testo == passo[[lingua]]) - 1L)
    expect_equal(dove("6\\. "), which(testo == passo[[lingua]]) + 1L)
    expect_false(grepl("telefono|phone|SMS", passo[[lingua]]))
  }
  # Done closes the registration once, at the end of it.
  expect_equal(sum(grepl("Done", righe, fixed = TRUE)), 2L)
})


test_that("il testo pronto non porta istanza, progetto, ruolo o nome utente", {
  # eval
  riga <- riga_di_prova(
    server = "edc10", project_id = "9047", role_name = "collaudo-canale",
    dag_name = "gruppo-collaudo"
  )
  upn <- "sara.collaudozeta@ubep.unipd.it"
  corpo <- mail_credential_message(
    riga, upn = upn, credential = finti[["parola"]], deadline = "2026-12-21"
  )[["body"]]
  righe <- strsplit(corpo, "\n", fixed = TRUE)[[1]]

  # test
  # Key and context do not travel together, decided by [cl] on 2026-11-19:
  # the link and the user name reach the person in the welcome, the project
  # in My Projects when the access e-mail arrives.
  for (d in delimitatori) {
    testo <- paste(
      testo_pronto(righe, d[[1]], d[[2]])[["righe"]], collapse = "\n"
    )
    for (contesto in c(
      upn, "https://", "http://", "edc10", "9047", "collaudo-canale",
      "gruppo-collaudo", riga[["last_name"]], riga[["contact_email"]]
    )) {
      expect_false(grepl(contesto, testo, fixed = TRUE), info = contesto)
    }
  }
  # Nor anywhere else in the message, so nothing sits next to the key.
  for (contesto in c(
    "https://", "edc10", "9047", "collaudo-canale", "gruppo-collaudo"
  )) {
    expect_false(grepl(contesto, corpo, fixed = TRUE), info = contesto)
  }
})


test_that("senza nome il testo pronto saluta senza lasciare uno spazio", {
  # eval
  primi <- function(nome) {
    righe <- strsplit(mail_credential_message(
      riga_di_prova(first_name = nome), upn = "sara.collaudozeta@ubep.unipd.it",
      credential = finti[["parola"]]
    )[["body"]], "\n", fixed = TRUE)[[1]]
    vapply(delimitatori, function(d) {
      testo_pronto(righe, d[[1]], d[[2]])[["righe"]][[1L]]
    }, character(1))
  }

  # test
  for (nome in list(NA_character_, "", "  ")) {
    expect_identical(
      primi(nome), c(it = "Ciao,", en = "Hello,"), info = format(nome)
    )
  }
})


test_that("senza data limite il testo pronto resta, senza la data", {
  # eval
  righe <- strsplit(mail_credential_message(
    riga_di_prova(), upn = "sara.collaudozeta@ubep.unipd.it",
    credential = finti[["parola"]]
  )[["body"]], "\n", fixed = TRUE)[[1]]

  # test
  for (d in delimitatori) {
    testo <- testo_pronto(righe, d[[1]], d[[2]])[["righe"]]
    expect_true(finti[["parola"]] %in% testo)
    expect_false(any(grepl("[0-9]{4}-[0-9]{2}-[0-9]{2}", testo)))
    expect_true(any(grepl("Verified IDs", testo, fixed = TRUE)))
  }
  expect_false(any(grepl("entro il", righe, fixed = TRUE)))
  expect_false(any(grepl("must happen by", righe, fixed = TRUE)))
})


test_that("manda al servizio di posta, col mittente e la chiave che riceve", {
  # eval
  catturata <- NULL
  detto <- httr2::with_mocked_responses(
    function(req) {
      catturata <<- req
      httr2::response(status_code = 202L)
    },
    mail_send(
      api_key = finti[["chiave"]], from = "mittente@example.org",
      to = "destinatario@example.org", subject = "oggetto", body = "corpo",
      cc = "copia@example.org", reply_to = "risposte@example.org"
    )
  )

  # test
  expect_true(detto[["ok"]])
  expect_equal(detto[["errors"]], character())
  expect_match(catturata[["url"]], "api.sendgrid.com", fixed = TRUE)
  expect_equal(catturata[["method"]], "POST")
  # `httr2` redige `Authorization` da se': letto come lista, l'header e' un
  # riferimento debole e non una stringa. `req_get_headers(redact = FALSE)` e'
  # la via pubblica per rivederlo, ed e' anche la prova che la redazione c'e' --
  # cioe' che la chiave non finisce in un `print()` della richiesta.
  expect_equal(
    httr2::req_get_headers(catturata, redacted = "reveal")[["Authorization"]],
    paste("Bearer", finti[["chiave"]])
  )
})


test_that("un rifiuto del servizio non e' un giro rotto, e' un esito", {
  # eval
  # Silenziato di proposito: le parole del servizio hanno i loro test qui
  # sotto, e questo prova che un rifiuto resta un esito e non un giro rotto.
  detto <- suppressMessages(httr2::with_mocked_responses(
    function(req) httr2::response(status_code = 403L),
    mail_send(
      api_key = finti[["chiave"]], from = "m@example.org",
      to = "d@example.org", subject = "o", body = "c"
    )
  ))

  # test
  expect_false(detto[["ok"]])
  expect_equal(detto[["errors"]], "TRASPORTO_POSTA_RIFIUTATA")
})


test_that("il servizio irraggiungibile si distingue dal servizio che rifiuta", {
  # eval
  detto <- httr2::with_mocked_responses(
    function(req) stop("rete assente"),
    mail_send(
      api_key = finti[["chiave"]], from = "m@example.org",
      to = "d@example.org", subject = "o", body = "c"
    )
  )

  # test
  expect_false(detto[["ok"]])
  expect_equal(detto[["errors"]], "TRASPORTO_POSTA_NON_RAGGIUNGIBILE")
})


test_that("un rifiuto riporta le parole del servizio, non solo il suo codice", {
  # eval
  corpo <- paste0(
    '{"errors":[{"message":"The requestor\'s IP Address is not whitelisted",',
    '"field":null,"help":null}]}'
  )

  detto <- NULL
  avviso <- testthat::capture_messages(
    detto <- httr2::with_mocked_responses(
      function(req) {
        httr2::response(status_code = 403L, body = charToRaw(corpo))
      },
      mail_send(
        api_key = finti[["chiave"]], from = "m@example.org",
        to = "d@example.org", subject = "o", body = "c"
      )
    )
  )

  # test
  # Il codice del vocabolario chiuso e' cio' che la telemetria conta, e non
  # cambia. Le parole del servizio sono cio' che dice PERCHE', e vanno sullo
  # standard di errore, cioe' nel journal, dove chi diagnostica un giro sta
  # gia' guardando. Il 2026-08-27 quella stessa condizione ha dato 403 su un
  # endpoint e 401 su un altro, con dentro la stessa frase: senza questa riga
  # si va a cercare un guasto di rete.
  expect_equal(detto[["errors"]], "TRASPORTO_POSTA_RIFIUTATA")
  expect_match(avviso, "not whitelisted", fixed = TRUE, all = FALSE)
  expect_match(avviso, "403", fixed = TRUE, all = FALSE)
})


test_that("le parole del servizio non portano con se' la chiave", {
  # eval
  avviso <- testthat::capture_messages(
    httr2::with_mocked_responses(
      function(req) {
        httr2::response(
          status_code = 401L, body = charToRaw("chiave non valida")
        )
      },
      mail_send(
        api_key = finti[["chiave"]], from = "m@example.org",
        to = "d@example.org", subject = "o", body = "c"
      )
    )
  )

  # test
  # Il corpo della risposta e' del servizio e non nostro, quindi non riecheggia
  # la richiesta. Questa guardia lo verifica invece di darlo per buono, ed e' la
  # sorella di quella sull'header che `httr2` redige.
  expect_false(any(grepl(finti[["chiave"]], avviso, fixed = TRUE)))
})


test_that("un rifiuto senza corpo resta un esito, non un errore", {
  # eval
  detto <- NULL
  avviso <- testthat::capture_messages(
    detto <- httr2::with_mocked_responses(
      function(req) httr2::response(status_code = 500L),
      mail_send(
        api_key = finti[["chiave"]], from = "m@example.org",
        to = "d@example.org", subject = "o", body = "c"
      )
    )
  )

  # test
  # Un corpo assente o illeggibile -- un proxy che risponde HTML, una risposta
  # troncata -- non deve trasformare un esito in un'eccezione: sarebbe un
  # guasto nuovo introdotto dalla diagnosi che doveva renderne leggibile un
  # altro. Lo stato resta, ed e' gia' meta' della risposta.
  expect_equal(detto[["errors"]], "TRASPORTO_POSTA_RIFIUTATA")
  expect_match(avviso, "500", fixed = TRUE, all = FALSE)
})


test_that("i due messaggi nuovi portano le due lingue", {
  # eval
  riga <- riga_di_prova()
  corpi <- c(
    mail_welcome_message(riga, upn = "sara@ubep.unipd.it")[["body"]],
    mail_credential_message(
      riga, upn = "sara@ubep.unipd.it", credential = finti[["parola"]]
    )[["body"]]
  )

  # test
  for (corpo in corpi) {
    expect_match(corpo, "\n---\n", fixed = TRUE)
  }
})


raccoglitore <- function(riesce = TRUE) {
  mandate <- list()
  list(
    mailer = function(to, cc, subject, body) {
      mandate[[length(mandate) + 1L]] <<- list(
        to = to, cc = cc, subject = subject, body = body
      )
      if (isTRUE(riesce)) {
        list(ok = TRUE, errors = character())
      } else {
        list(ok = FALSE, errors = "TRASPORTO_POSTA_RIFIUTATA")
      }
    },
    mandate = function() mandate
  )
}


colonne_cambiate <- c("record_id", "outcome", "outcome_detail", "applied_as")


# riga_di_prova() sta in helper-finti.R, che il linter non legge.
# nolint start: object_usage_linter.
registro_di_prova <- function(...) {
  as.data.frame(riga_di_prova(...), stringsAsFactors = FALSE)
}
# nolint end


test_that("l'esito va a chi ha compilato, non alla persona nominata", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  # eval
  mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = FALSE, copy_to = "it@example.org"
  )

  # test
  mandate <- posta[["mandate"]]()
  expect_length(mandate, 1L)
  expect_equal(mandate[[1L]][["to"]], "cinzia@ubep.unipd.it")
  expect_equal(mandate[[1L]][["cc"]], "it@example.org")
})


test_that("un giro che simula non manda niente, e scrive tutto", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  # eval
  detto <- mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = TRUE
  )

  # test
  expect_length(posta[["mandate"]](), 0L)
  expect_equal(nrow(detto[["recapitate"]]), 1L)
})


test_that("una riga la cui mail non parte non si puo' scrivere", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[, colonne_cambiate, drop = FALSE]

  # eval
  detto <- mail_round(
    changed, registro, born = list(),
    mailer = raccoglitore(riesce = FALSE)[["mailer"]], dry_run = FALSE
  )

  # test
  expect_equal(nrow(detto[["recapitate"]]), 0L)
  expect_equal(detto[["errori"]], "TRASPORTO_POSTA_RIFIUTATA")
  expect_equal(detto[["contatori"]][["posta_fallite"]], 1L)
})


test_that("il messaggio porta l'esito di questo giro, non quello vecchio", {
  # eval
  registro <- registro_di_prova(
    outcome = "data_error", outcome_detail = "DATO_RUOLO_INESISTENTE"
  )
  changed <- registro[, colonne_cambiate, drop = FALSE]
  changed[["outcome"]] <- "applied"
  changed[["outcome_detail"]] <- ""
  posta <- raccoglitore()

  # eval
  mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = FALSE
  )

  # test
  corpo <- posta[["mandate"]]()[[1L]][["body"]]
  expect_match(corpo, "eseguita", fixed = TRUE)
  expect_false(grepl("DATO_RUOLO_INESISTENTE", corpo, fixed = TRUE))
})


test_that("il messaggio nomina l'identita' che il giro ha stabilito", {
  # eval
  # A row as a referent files it: the UPN is not typed, the round resolves it.
  registro <- registro_di_prova(username = "", identity = "")
  changed <- registro[, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  # eval
  mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = FALSE,
    identified = data.frame(
      record_id = "16",
      username = "sara.collaudozeta@ubep.unipd.it",
      identity = "existing",
      stringsAsFactors = FALSE
    )
  )

  # test
  # The resolution happens before the mail and is already in the register by
  # the time it leaves, so the message that says it is not established yet is
  # contradicting a value this same round wrote.
  corpo <- posta[["mandate"]]()[[1L]][["body"]]
  expect_match(corpo, "sara.collaudozeta@ubep.unipd.it", fixed = TRUE)
  expect_false(grepl("non ancora stabilito", corpo, fixed = TRUE))
})


test_that("una nascita produce due messaggi, a due destinatari diversi", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()
  nati <- list(list(
    record_id = "16", upn = "sara@ubep.unipd.it",
    credential = finti[["parola"]]
  ))

  # eval
  detto <- mail_round(
    changed, registro, born = nati, mailer = posta[["mailer"]],
    dry_run = FALSE
  )

  # test
  mandate <- posta[["mandate"]]()
  expect_length(mandate, 2L)
  expect_setequal(
    vapply(mandate, function(m) m[["to"]], character(1)),
    c("sara.esterna@example.org", "cinzia@ubep.unipd.it")
  )
  expect_equal(detto[["contatori"]][["credenziali_recapitate"]], 1L)
})


test_that("benvenuto e chiave portano la data limite contata dalla nascita", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()
  # Born at 23:30 UTC, which in Rome is already the next day: the deadline is
  # counted from that day, and from nothing the round knows about itself.
  nati <- list(list(
    record_id = "16", upn = "sara@ubep.unipd.it",
    credential = finti[["parola"]], created_at = "2026-10-23T23:30:00Z"
  ))

  # eval
  mail_round(
    changed, registro, born = nati, mailer = posta[["mailer"]],
    dry_run = FALSE
  )
  mandate <- posta[["mandate"]]()
  corpo_a <- function(chi) {
    Filter(function(m) identical(m[["to"]], chi), mandate)[[1]][["body"]]
  }

  # test
  expect_match(
    corpo_a("sara.esterna@example.org"), "Primo accesso entro il 2026-12-22.",
    fixed = TRUE
  )
  expect_match(
    corpo_a("cinzia@ubep.unipd.it"), "entro il 2026-12-22.", fixed = TRUE
  )
})


# One round that applies row 16 and makes its account, with `requested_by` and
# the owner the round settled set apart. A row filed through the Data Import
# Tool carries in `requested_by` whatever the CSV had; the owner is who the
# creation log, and the approved changes after it, say the row belongs to,
# which `identified` hands to the post. The key is an argument so the fake
# value keeps coming from `finti`.
giro_con_proprietario <- function(requested_by,
                                  owner,
                                  chiave,
                                  copy_to = NULL) {
  registro <- registro_di_prova(requested_by = requested_by)
  changed <- registro[, colonne_cambiate, drop = FALSE]
  changed[["outcome"]] <- "applied"
  changed[["outcome_detail"]] <- ""
  posta <- raccoglitore()
  detto <- mail_round(
    changed, registro,
    born = list(list(
      record_id = "16", upn = "sara@ubep.unipd.it", credential = chiave
    )),
    mailer = posta[["mailer"]], dry_run = FALSE, copy_to = copy_to,
    identified = data.frame(
      record_id = "16", username = "sara.collaudozeta@ubep.unipd.it",
      identity = "existing", owner = owner, passed = FALSE, edited_by = "",
      stringsAsFactors = FALSE
    )
  )
  mandate <- posta[["mandate"]]()
  a <- function(oggetto) {
    vapply(
      Filter(function(m) grepl(oggetto, m[["subject"]], fixed = TRUE), mandate),
      function(m) m[["to"]], character(1)
    )
  }
  list(
    detto = detto,
    tutti = vapply(mandate, function(m) m[["to"]], character(1)),
    esito = a("Richiesta 16"),
    chiave = a("Accesso al nuovo account"),
    benvenuto = a("Il tuo account UBEP")
  )
}


test_that("una riga importata per altri manda esito e chiave al proprietario", {
  # eval
  visto <- giro_con_proprietario(
    requested_by = "nominato.da.import@example.org",
    owner = "proprietaria.riga@example.org", chiave = finti[["parola"]]
  )

  # test
  # The key stays with the referent the row belongs to. An import that names
  # somebody else, the person themselves included, does not move it.
  expect_equal(visto[["esito"]], "proprietaria.riga@example.org")
  expect_equal(visto[["chiave"]], "proprietaria.riga@example.org")
  expect_equal(visto[["benvenuto"]], "sara.esterna@example.org")
  expect_false("nominato.da.import@example.org" %in% visto[["tutti"]])
  expect_equal(visto[["detto"]][["contatori"]][["credenziali_recapitate"]], 1L)
})


test_that("una riga importata senza requested_by non perde la chiave", {
  # eval
  visto <- giro_con_proprietario(
    requested_by = "", owner = "proprietaria.riga@example.org",
    chiave = finti[["parola"]]
  )

  # test
  # Sent to the empty field, the key had no recipient: the account was born
  # and nobody could get into it, and the outcome stayed out of the register.
  expect_equal(visto[["esito"]], "proprietaria.riga@example.org")
  expect_equal(visto[["chiave"]], "proprietaria.riga@example.org")
  expect_equal(visto[["detto"]][["contatori"]][["credenziali_recapitate"]], 1L)
  expect_equal(visto[["detto"]][["contatori"]][["credenziali_perse"]], 0L)
  expect_false("POSTA_SENZA_DESTINATARIO" %in% visto[["detto"]][["errori"]])
  expect_false("POSTA_CREDENZIALE_PERSA" %in% visto[["detto"]][["errori"]])
  expect_equal(nrow(visto[["detto"]][["recapitate"]]), 1L)
})


test_that("una riga del modulo, dove i due coincidono, resta com'era", {
  # eval
  visto <- giro_con_proprietario(
    requested_by = "referente.modulo@example.org",
    owner = "referente.modulo@example.org", chiave = finti[["parola"]]
  )

  # test
  expect_equal(visto[["esito"]], "referente.modulo@example.org")
  expect_equal(visto[["chiave"]], "referente.modulo@example.org")
  expect_equal(visto[["benvenuto"]], "sara.esterna@example.org")
})


test_that("la chiave non va a nessuno che non sia il proprietario stabilito", {
  # eval
  visto <- giro_con_proprietario(
    requested_by = "nominato.da.import@example.org", owner = "",
    chiave = finti[["parola"]], copy_to = "it@example.org"
  )

  # test
  expect_length(visto[["chiave"]], 0L)
  expect_false("nominato.da.import@example.org" %in% visto[["tutti"]])
  expect_equal(visto[["detto"]][["contatori"]][["credenziali_perse"]], 1L)
  expect_true("POSTA_CREDENZIALE_PERSA" %in% visto[["detto"]][["errori"]])
})


test_that("il benvenuto porta l'indirizzo dell'istanza della sua riga", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()
  nati <- list(list(
    record_id = "16", upn = "sara@ubep.unipd.it",
    credential = finti[["parola"]]
  ))

  # eval
  mail_round(
    changed, registro, born = nati, mailer = posta[["mailer"]],
    dry_run = FALSE,
    hosts = c(edc10 = "edc10.example.org/redcap", edc12 = "edc12.example.org")
  )

  # test
  mandate <- posta[["mandate"]]()
  a <- function(chi) {
    Filter(function(m) identical(m[["to"]], chi), mandate)[[1L]][["body"]]
  }
  benvenuto <- a("sara.esterna@example.org")
  chiave <- a("cinzia@ubep.unipd.it")
  expect_match(
    benvenuto, "REDCap si apre da: https://edc10.example.org/redcap/",
    fixed = TRUE
  )
  expect_false(grepl("edc12", benvenuto, fixed = TRUE))
  # The message with the key carries no context, and an address is context:
  # with it, a key that leaked would come with the door it opens.
  expect_false(grepl("example.org", chiave, fixed = TRUE))
  expect_false(grepl("https://", chiave, fixed = TRUE))
  expect_false(grepl("edc10", chiave, fixed = TRUE))
})


test_that("un'istanza che l'inventario non conosce non ferma il benvenuto", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  nati <- list(list(
    record_id = "16", upn = "sara@ubep.unipd.it",
    credential = finti[["parola"]]
  ))

  for (hosts in list(NULL, c(edc12 = "edc12.example.org"))) {
    posta <- raccoglitore()

    # eval
    mail_round(
      changed, registro, born = nati, mailer = posta[["mailer"]],
      dry_run = FALSE, hosts = hosts
    )

    # test
    benvenuto <- Filter(
      function(m) identical(m[["to"]], "sara.esterna@example.org"),
      posta[["mandate"]]()
    )
    expect_length(benvenuto, 1L)
    expect_false(
      grepl("REDCap si apre da", benvenuto[[1L]][["body"]], fixed = TRUE)
    )
  }
})


test_that("una chiave d'ingresso non recapitata ha un codice suo", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  nati <- list(list(
    record_id = "16", upn = "sara@ubep.unipd.it",
    credential = finti[["parola"]]
  ))

  # eval
  detto <- mail_round(
    changed, registro, born = nati,
    mailer = raccoglitore(riesce = FALSE)[["mailer"]], dry_run = FALSE
  )

  # test
  expect_true("POSTA_CREDENZIALE_PERSA" %in% detto[["errori"]])
  expect_equal(detto[["contatori"]][["credenziali_perse"]], 1L)
})


# A mailer that fails for one recipient only, so a test can lose the welcome
# and keep the key, or the other way round.
rifiuta_a <- function(chi) {
  mandate <- list()
  list(
    mailer = function(to, cc, subject, body) {
      mandate[[length(mandate) + 1L]] <<- list(to = to, subject = subject)
      if (identical(to, chi)) {
        list(ok = FALSE, errors = "TRASPORTO_POSTA_RIFIUTATA")
      } else {
        list(ok = TRUE, errors = character())
      }
    },
    mandate = function() mandate
  )
}


nascita_di_prova <- function(credential, record_id = "16") {
  list(list(
    record_id = record_id, upn = "sara@ubep.unipd.it", credential = credential
  ))
}


test_that("un benvenuto recapitato si conta, accanto alla chiave", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]

  # eval
  detto <- mail_round(
    changed, registro, born = nascita_di_prova(finti[["parola"]]),
    mailer = raccoglitore()[["mailer"]], dry_run = FALSE
  )

  # test
  conto <- detto[["contatori"]]
  expect_equal(conto[["benvenuti_recapitati"]], 1L)
  expect_equal(conto[["benvenuti_persi"]], 0L)
  expect_equal(conto[["credenziali_recapitate"]], 1L)
  expect_equal(conto[["credenziali_perse"]], 0L)
  # Not added to the outcome messages: those have a next round, and these two
  # do not.
  expect_equal(conto[["posta_partite"]], 0L)
  expect_equal(conto[["posta_fallite"]], 0L)
  expect_equal(detto[["errori"]], character())
})


test_that("un benvenuto non recapitato ha un codice suo", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]

  # eval
  detto <- mail_round(
    changed, registro, born = nascita_di_prova(finti[["parola"]]),
    mailer = rifiuta_a("sara.esterna@example.org")[["mailer"]],
    dry_run = FALSE
  )

  # test
  # The code alone, as for the key: the transport's word is in the journal,
  # and this string reaches the telemetry record.
  conto <- detto[["contatori"]]
  expect_equal(detto[["errori"]], "POSTA_BENVENUTO_PERSO")
  expect_equal(conto[["benvenuti_persi"]], 1L)
  expect_equal(conto[["benvenuti_recapitati"]], 0L)
  expect_equal(conto[["credenziali_recapitate"]], 1L)
  expect_equal(conto[["credenziali_perse"]], 0L)
  expect_equal(conto[["posta_fallite"]], 0L)
})


test_that("un benvenuto senza destinatario e' un benvenuto perso", {
  # eval
  registro <- registro_di_prova(contact_email = "")
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  # eval
  detto <- mail_round(
    changed, registro, born = nascita_di_prova(finti[["parola"]]),
    mailer = posta[["mailer"]], dry_run = FALSE
  )

  # test
  expect_length(posta[["mandate"]](), 1L)
  expect_equal(detto[["errori"]], "POSTA_BENVENUTO_PERSO")
  expect_equal(detto[["contatori"]][["benvenuti_persi"]], 1L)
  expect_equal(detto[["contatori"]][["credenziali_recapitate"]], 1L)
})


test_that("benvenuto e chiave persi insieme si contano tutti e due", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]

  # eval
  detto <- mail_round(
    changed, registro, born = nascita_di_prova(finti[["parola"]]),
    mailer = raccoglitore(riesce = FALSE)[["mailer"]], dry_run = FALSE
  )

  # test
  conto <- detto[["contatori"]]
  expect_equal(
    detto[["errori"]], c("POSTA_BENVENUTO_PERSO", "POSTA_CREDENZIALE_PERSA")
  )
  expect_equal(conto[["benvenuti_persi"]], 1L)
  expect_equal(conto[["credenziali_perse"]], 1L)
  expect_equal(conto[["benvenuti_recapitati"]], 0L)
  expect_equal(conto[["credenziali_recapitate"]], 0L)
})


test_that("una nascita senza riga nel registro perde benvenuto e chiave", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[0, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  # eval
  detto <- mail_round(
    changed, registro,
    born = nascita_di_prova(finti[["parola"]], record_id = "99"),
    mailer = posta[["mailer"]], dry_run = FALSE
  )

  # test
  # Neither message has anybody to go to, and both are lost the same way.
  expect_length(posta[["mandate"]](), 0L)
  expect_equal(
    detto[["errori"]], c("POSTA_BENVENUTO_PERSO", "POSTA_CREDENZIALE_PERSA")
  )
  expect_equal(detto[["contatori"]][["benvenuti_persi"]], 1L)
  expect_equal(detto[["contatori"]][["credenziali_perse"]], 1L)
})


test_that("un benvenuto perso non si ritenta, e non trattiene nessuna riga", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[, colonne_cambiate, drop = FALSE]

  # eval
  detto <- mail_round(
    changed, registro, born = nascita_di_prova(finti[["parola"]]),
    mailer = rifiuta_a("sara.esterna@example.org")[["mailer"]],
    dry_run = FALSE
  )

  # test
  # The account is already born and the round does not create it twice, so
  # the next round has no occasion to send the welcome again. Holding the row
  # back would not bring it back: it would only stop the outcome being written.
  expect_equal(nrow(detto[["recapitate"]]), 1L)
  expect_equal(detto[["errori"]], "POSTA_BENVENUTO_PERSO")
  expect_equal(detto[["contatori"]][["posta_partite"]], 1L)
})


test_that("un giro che simula o non manda porta i sei contatori a zero", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[, colonne_cambiate, drop = FALSE]

  # eval
  detto <- mail_round(
    changed, registro, born = nascita_di_prova(finti[["parola"]]),
    mailer = raccoglitore()[["mailer"]], dry_run = TRUE, granted = "16"
  )

  # test
  for (campo in c(
    "benvenuti_recapitati", "benvenuti_persi",
    "credenziali_recapitate", "credenziali_perse",
    "accessi_recapitati", "accessi_persi"
  )) {
    expect_identical(detto[["contatori"]][[campo]], 0L)
  }
})


test_that("il dirottamento sostituisce i destinatari e lo dichiara nel corpo", {
  # eval
  registro <- registro_di_prova()
  changed <- registro[, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  # eval
  detto <- mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = FALSE, redirect_to = "corrado@example.org",
    copy_to = "it@example.org"
  )

  # test
  mandata <- posta[["mandate"]]()[[1L]]
  expect_equal(mandata[["to"]], "corrado@example.org")
  expect_null(mandata[["cc"]])
  expect_match(mandata[["body"]], "cinzia@ubep.unipd.it", fixed = TRUE)
  expect_true(detto[["contatori"]][["posta_dirottata"]])
})


test_that("una riga trattenuta dice quale sigillo incollare, e dove", {
  # eval
  messaggio <- mail_outcome_message(list(
    record_id = "42", outcome = "held", outcome_detail = "SIGILLO_DIVERSO",
    outcome_at = "2026-09-02 04:02", request_status = "active",
    first_name = "Mario", last_name = "Rossi",
    contact_email = "mario.rossi@example.org",
    server = "edc10", project_id = "9003", role_name = "data entry",
    username = "mario.rossi@ubep.unipd.it", applied_as = "",
    seal_now = "9f3c1a7b04de"
  ))

  # test
  # The approval is a value to paste, not a box to tick, and the only place
  # that value exists is this message: the current seal is computed, not
  # stored, so a referent who is not told it cannot approve anything. A
  # protection nobody can clear is an outage with a nicer name.
  expect_true(grepl("9f3c1a7b04de", messaggio[["body"]], fixed = TRUE))
  expect_true(grepl("approved_seal", messaggio[["body"]], fixed = TRUE))
})


riga_trattenuta <- function(...) {
  utils::modifyList(
    list(
      record_id = "42", outcome = "held",
      outcome_detail = "SIGILLO_DIVERSO:9f3c1a7b04de",
      outcome_at = "2026-09-02 04:02", request_status = "active",
      first_name = "Mario", last_name = "Rossi",
      contact_email = "mario.rossi@example.org",
      server = "edc10", project_id = "9003", role_name = "data entry",
      username = "mario.rossi@ubep.unipd.it", applied_as = "",
      seal_now = "9f3c1a7b04de"
    ),
    list(...)
  )
}


test_that("la riga trattenuta dice che approva solo il proprietario, o IT", {
  # eval
  corpo <- mail_outcome_message(
    riga_trattenuta(edited_by = "bruno.verdi@ubep.unipd.it")
  )[["body"]]

  # test
  # The message goes to the row's owner and has to say why: the approval of any
  # other referent, the author of the change included, does not count.
  # Sending the reader to "another referent" would ask for an act the round
  # ignores. IT approves too since 2026-10-15, and the message says so.
  expect_match(corpo, "solo il referente della riga, oppure IT", fixed = TRUE)
  expect_match(corpo, "Only whoever owns the row, or IT,", fixed = TRUE)
  expect_false(grepl("un altro referente", corpo, fixed = TRUE))
  expect_false(grepl("another referent", corpo, fixed = TRUE))
  # Who changed the row is what the owner needs to judge the change.
  expect_match(
    corpo, "Modificata da: bruno.verdi@ubep.unipd.it", fixed = TRUE
  )
  expect_match(corpo, "Edited by: bruno.verdi@ubep.unipd.it", fixed = TRUE)
})


test_that("la riga trattenuta vale anche per una richiesta non ancora eseguita", { # nolint: line_length_linter.
  # eval
  corpo <- mail_outcome_message(riga_trattenuta())[["body"]]

  # test
  # A request is held for somebody else's change before the round applies it
  # as well as after, so the message cannot say it was applied. And the
  # approval is spent by the execution it allows: said otherwise, a referent
  # would expect an old seal to approve the row again.
  expect_false(
    grepl("modificata dopo essere stata eseguita", corpo, fixed = TRUE)
  )
  expect_false(grepl("after it had been applied", corpo, fixed = TRUE))
  expect_match(corpo, "Vale una volta sola", fixed = TRUE)
  expect_match(corpo, "It counts once", fixed = TRUE)
  expect_match(corpo, "non ancora eseguita resta ferma", fixed = TRUE)
  expect_match(corpo, "not applied yet stays held", fixed = TRUE)
})


test_that("la riga trattenuta dice quando il log non nomina chi l'ha cambiata", { # nolint: line_length_linter.
  # eval
  corpo <- mail_outcome_message(riga_trattenuta())[["body"]]

  # test
  expect_match(corpo, "Modificata da: non stabilito", fixed = TRUE)
  expect_match(corpo, "Edited by: not established", fixed = TRUE)
})


test_that("la riga trattenuta dice che cosa fa l'approvazione e che cosa no", {
  # eval
  corpo <- mail_outcome_message(
    riga_trattenuta(edited_by = "bruno.verdi@ubep.unipd.it")
  )[["body"]]

  # test
  # The gate asks the rights of whoever wrote the change, not of whoever
  # approves it: an approval with no condition attached would promise a
  # change the round then refuses. And approving somebody else's change hands
  # the row over to them, which the owner has to know before pasting.
  expect_false(grepl("diventa effettiva", corpo, fixed = TRUE))
  expect_false(grepl("takes effect", corpo, fixed = TRUE))
  expect_match(
    corpo,
    "si esegue se chi l'ha scritta ha User Rights con Full Access sul progetto",
    fixed = TRUE
  )
  expect_match(
    corpo,
    "is applied on the next round if whoever wrote it holds User Rights",
    fixed = TRUE
  )
  expect_match(
    corpo, "la rifiuta con DATO_AMBITO_NON_AUTORIZZATO", fixed = TRUE
  )
  expect_match(
    corpo, "refuses it with DATO_AMBITO_NON_AUTORIZZATO", fixed = TRUE
  )
  expect_match(
    corpo, "approvandola cedi la riga a chi l'ha scritta per ultimo",
    fixed = TRUE
  )
  expect_match(
    corpo, "approving it hands the row over to whoever wrote it last",
    fixed = TRUE
  )
  expect_match(corpo, "salvo che sia solo una revoca", fixed = TRUE)
  expect_match(corpo, "unless it is only a revocation", fixed = TRUE)
})


test_that("ogni esito va al proprietario, mai a requested_by", {
  # eval
  riga <- list(
    record_id = "42", requested_by = "nominato.da.import@example.org",
    owner = "proprietaria.riga@example.org"
  )

  # test
  # `requested_by` is what `@USERNAME` wrote on the form, and what the CSV
  # carried on an import: the Data Import Tool writes it verbatim. The owner is
  # settled from the log, so every outcome goes there and not only the held
  # one, and there is no fallback: after a hand-over it would write to a
  # former owner.
  for (esito in outcome_vocabulary()) {
    expect_equal(
      mail_referent(c(riga, outcome = esito)), "proprietaria.riga@example.org"
    )
  }
  expect_equal(mail_referent(c(riga[1:2], owner = "")), "")
  expect_equal(
    mail_referent(list(
      record_id = "42", creator = "creatrice.riga@example.org",
      requested_by = "nominato.da.import@example.org"
    )),
    ""
  )
  expect_equal(
    mail_referent(list(record_id = "42", requested_by = NA, owner = NA)), ""
  )
})


test_that("senza proprietario l'esito va solo a IT, e lo dice", {
  # eval
  registro <- registro_di_prova(owner = "")
  changed <- registro[, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()
  detto <- mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = FALSE, copy_to = "it@example.org"
  )

  # test
  mandate <- posta[["mandate"]]()
  expect_length(mandate, 1L)
  expect_equal(mandate[[1L]][["to"]], "it@example.org")
  expect_null(mandate[[1L]][["cc"]])
  expect_match(
    mandate[[1L]][["body"]],
    "Referente della riga non stabilito: questo messaggio va solo a IT.",
    fixed = TRUE
  )
  expect_match(
    mandate[[1L]][["body"]],
    "Whoever owns the row is not established: this message goes to IT only.",
    fixed = TRUE
  )
  expect_equal(nrow(detto[["recapitate"]]), 1L)

  # eval
  senza_it <- mail_round(
    changed, registro, born = list(), mailer = raccoglitore()[["mailer"]],
    dry_run = FALSE
  )

  # test
  expect_equal(nrow(senza_it[["recapitate"]]), 0L)
  expect_true("POSTA_SENZA_DESTINATARIO" %in% senza_it[["errori"]])
})


test_that("l'esito che passa la riga lo dice al nuovo proprietario", {
  # eval
  passata <- mail_outcome_message(riga_di_prova(
    outcome = "applied", outcome_detail = "", passed = TRUE
  ))[["body"]]
  ferma <- mail_outcome_message(riga_di_prova(
    outcome = "held", passed = TRUE, seal_now = "9f3c1a7b04de"
  ))[["body"]]

  # test
  expect_match(passata, paste0(
    "Da questa modifica la riga e' tua: le modifiche di altri referenti ",
    "aspettano la tua approvazione, oppure quella di IT."
  ), fixed = TRUE)
  expect_match(passata, paste0(
    "From this change on the row is yours: changes by other referents ",
    "wait for your approval, or IT's."
  ), fixed = TRUE)
  expect_no_match(ferma, "la riga e' tua", fixed = TRUE)
  expect_no_match(
    mail_outcome_message(riga_di_prova(outcome = "applied"))[["body"]],
    "la riga e' tua", fixed = TRUE
  )
})


test_that("gli altri esiti non parlano di sigilli", {
  # eval
  messaggio <- mail_outcome_message(list(
    record_id = "42", outcome = "applied", outcome_detail = "",
    outcome_at = "2026-09-02 04:02", request_status = "active",
    first_name = "Mario", last_name = "Rossi",
    contact_email = "mario.rossi@example.org",
    server = "edc10", project_id = "9003", role_name = "data entry",
    username = "mario.rossi@ubep.unipd.it", applied_as = "role_name=data entry",
    seal_now = "9f3c1a7b04de"
  ))

  # test
  # Instructions for a situation the reader is not in are the fastest way to
  # make the rest of the message unread.
  expect_false(grepl("approved_seal", messaggio[["body"]], fixed = TRUE))
})


test_that("il giro mette nel messaggio il sigillo che la riga vale adesso", {
  # eval
  registro <- registro_di_prova(outcome = "held")
  changed <- registro[, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()

  mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = FALSE
  )
  corpo <- posta[["mandate"]]()[[1L]][["body"]]

  # test
  # The current seal is computed from the row and stored nowhere, so it exists
  # only here. `register` is the register as read, which is exactly the frame
  # the seal has to be computed from: computing it from what the round has
  # been rewriting would hand the referent a value for a row that no longer
  # matches what they are looking at.
  expect_true(grepl(request_seal(registro), corpo, fixed = TRUE))
})


test_that("il sigillo del messaggio porta lo username che il giro ha appena scritto", { # nolint: line_length_linter.
  # eval
  registro <- registro_di_prova(outcome = "held", username = "")
  changed <- registro[, colonne_cambiate, drop = FALSE]
  posta <- raccoglitore()
  risolto <- registro
  risolto[["username"]] <- "mario.rossi@ubep.unipd.it"

  mail_round(
    changed, registro, born = list(), mailer = posta[["mailer"]],
    dry_run = FALSE,
    identified = data.frame(
      record_id = registro[["record_id"]],
      username = "mario.rossi@ubep.unipd.it", identity = "existing",
      stringsAsFactors = FALSE
    )
  )
  corpo <- posta[["mandate"]]()[[1L]][["body"]]

  # test
  # The round writes the username it resolved through its own door before the
  # message leaves, and `username` is inside the seal. By the time the
  # referent pastes the value the row holds the resolved name, so the seal
  # computed from the row as read would never match it.
  expect_true(grepl(request_seal(risolto), corpo, fixed = TRUE))
  expect_false(grepl(request_seal(registro), corpo, fixed = TRUE))
})


test_that("la mail di accesso va alla persona e a nessun altro", {
  registro <- registro_di_prova()
  posta <- raccoglitore()
  detto <- mail_round(
    registro[0, colonne_cambiate, drop = FALSE], registro, born = list(),
    mailer = posta[["mailer"]], dry_run = FALSE,
    copy_to = "it@example.org", granted = "16"
  )
  mandate <- posta[["mandate"]]()
  expect_length(mandate, 1L)
  expect_equal(mandate[[1L]][["to"]], "sara.esterna@example.org")
  expect_null(mandate[[1L]][["cc"]])
  expect_match(mandate[[1L]][["subject"]], "^Accesso a REDCap")
  expect_identical(detto[["contatori"]][["accessi_recapitati"]], 1L)
  expect_identical(detto[["contatori"]][["accessi_persi"]], 0L)
})


test_that("una mail di accesso persa ha un codice suo e non si ritenta", {
  registro <- registro_di_prova()
  posta <- rifiuta_a("sara.esterna@example.org")
  detto <- mail_round(
    registro[0, colonne_cambiate, drop = FALSE], registro, born = list(),
    mailer = posta[["mailer"]], dry_run = FALSE, granted = "16"
  )
  expect_length(posta[["mandate"]](), 1L)
  expect_equal(detto[["errori"]], "POSTA_ACCESSO_PERSA")
  expect_identical(detto[["contatori"]][["accessi_persi"]], 1L)
  expect_identical(detto[["contatori"]][["posta_fallite"]], 0L)
})


test_that("senza indirizzo o senza riga la mail di accesso e' persa", {
  senza <- registro_di_prova(contact_email = "")
  posta <- raccoglitore()
  a <- mail_round(
    senza[0, colonne_cambiate, drop = FALSE], senza, born = list(),
    mailer = posta[["mailer"]], dry_run = FALSE, granted = "16"
  )
  b <- mail_round(
    senza[0, colonne_cambiate, drop = FALSE], senza, born = list(),
    mailer = posta[["mailer"]], dry_run = FALSE, granted = "99"
  )
  expect_length(posta[["mandate"]](), 0L)
  expect_equal(c(a[["errori"]], b[["errori"]]), rep("POSTA_ACCESSO_PERSA", 2L))
  for (detto in list(a, b)) {
    expect_identical(detto[["contatori"]][["accessi_persi"]], 1L)
    expect_identical(detto[["contatori"]][["accessi_recapitati"]], 0L)
  }
})


test_that("benvenuto e accesso nello stesso giro: prima il benvenuto", {
  registro <- registro_di_prova()
  posta <- raccoglitore()
  mail_round(
    registro[0, colonne_cambiate, drop = FALSE], registro,
    born = nascita_di_prova(finti[["parola"]]), mailer = posta[["mailer"]],
    dry_run = FALSE, granted = "16"
  )
  oggetti <- vapply(posta[["mandate"]](), `[[`, "", "subject")
  expect_lt(
    grep("Il tuo account UBEP", oggetti), grep("Accesso a REDCap", oggetti)
  )
})


test_that("la mail di accesso si dirotta e non parte in simulazione", {
  registro <- registro_di_prova()
  posta <- raccoglitore()
  mail_round(
    registro[0, colonne_cambiate, drop = FALSE], registro, born = list(),
    mailer = posta[["mailer"]], dry_run = FALSE,
    redirect_to = "prova@example.org", granted = "16"
  )
  expect_equal(posta[["mandate"]]()[[1L]][["to"]], "prova@example.org")
  expect_match(posta[["mandate"]]()[[1L]][["body"]], "^\\[PROVA\\]")
  finta <- raccoglitore()
  simulato <- mail_round(
    registro[0, colonne_cambiate, drop = FALSE], registro, born = list(),
    mailer = finta[["mailer"]], dry_run = TRUE, granted = "16"
  )
  expect_length(finta[["mandate"]](), 0L)
  expect_identical(simulato[["contatori"]][["accessi_recapitati"]], 0L)
})


# The fields the round settles for a row it carried out on edc10, project
# 9003, for Sara, and that now names another pair.
coppia_di_prova <- list(
  outcome = "data_error", outcome_detail = "DATO_COPPIA_CAMBIATA",
  server = "edc12", executed_server = "edc10", executed_project_id = "9029",
  executed_username = "sara.collaudozeta@ubep.unipd.it",
  pair_changed = "server", edited_by = "bruno@ubep.unipd.it"
)


test_that("il messaggio di una coppia cambiata dice che cosa e com'era", {
  # eval
  corpo <- mail_outcome_message(
    do.call(riga_di_prova, coppia_di_prova)
  )[["body"]]

  # test
  # What happened, what was carried out, and that nothing moved on the
  # instance: the referent sets the fields back to those values, so the
  # message has to name them.
  expect_match(
    corpo,
    paste0(
      "Questa richiesta e' gia' stata eseguita, e la riga ora chiede ",
      "un'altra istanza"
    ),
    fixed = TRUE
  )
  expect_match(
    corpo,
    "Eseguita su: edc10, progetto 9029, per sara.collaudozeta@ubep.unipd.it.",
    fixed = TRUE
  )
  expect_match(
    corpo, "Il canale non ha scritto niente sull'istanza", fixed = TRUE
  )
  expect_match(corpo, "Modificata da: bruno@ubep.unipd.it", fixed = TRUE)
  expect_match(
    corpo,
    "This request has already been applied, and the row now asks for another instance", # nolint: line_length_linter.
    fixed = TRUE
  )
  expect_match(
    corpo,
    "Applied on: edc10, project 9029, for sara.collaudozeta@ubep.unipd.it.",
    fixed = TRUE
  )
  expect_match(corpo, "The channel wrote nothing on the instance", fixed = TRUE)
})


test_that("il messaggio di una coppia cambiata dice le due uscite", {
  # eval
  corpo <- mail_outcome_message(
    do.call(riga_di_prova, coppia_di_prova)
  )[["body"]]

  # test
  # Setting the fields back, or revoking and filing anew; and the revocation
  # holds only on the pair carried out, so the fields go back first. An
  # approval does not help, and the message says so before somebody tries.
  expect_match(corpo, "riporta istanza, progetto, nome, cognome", fixed = TRUE)
  expect_match(corpo, "porta Requested state a revoked", fixed = TRUE)
  expect_match(corpo, "crea una richiesta nuova", fixed = TRUE)
  expect_match(
    corpo, "Revocata senza riportare i campi, la riga resta ferma",
    fixed = TRUE
  )
  expect_match(corpo, "Non serve approvare", fixed = TRUE)
  expect_match(
    corpo, "set instance, project, first name, last name", fixed = TRUE
  )
  expect_match(corpo, "set Requested state to revoked", fixed = TRUE)
  expect_match(corpo, "file a new request", fixed = TRUE)
  expect_match(corpo, "No approval is needed", fixed = TRUE)
  expect_false(grepl("approved_seal", corpo, fixed = TRUE))
})


test_that("il messaggio di una coppia cambiata nella sola persona non dice che la revoca resta ferma", { # nolint: line_length_linter.
  # eval
  corpo <- function(cambiato) {
    mail_outcome_message(do.call(
      riga_di_prova,
      utils::modifyList(coppia_di_prova, list(pair_changed = cambiato))
    ))[["body"]]
  }
  persona <- corpo("person")
  progetto <- corpo("project_id,person")
  ignoto <- corpo("")

  # test
  # On the person alone, a revocation with the fields not set back revokes
  # the name carried out (`revocation_exits()`): the row does not stay
  # stopped. With the instance or the project moved it does.
  expect_false(grepl("la riga resta ferma qui", persona, fixed = TRUE))
  expect_false(grepl("the row stays stopped here", persona, fixed = TRUE))
  expect_match(
    persona, "poi crea una richiesta nuova.
", fixed = FALSE
  )
  expect_match(persona, "then file a new request.
", fixed = FALSE)
  expect_match(
    progetto, "Revocata senza riportare i campi, la riga resta ferma qui.",
    fixed = TRUE
  )
  expect_match(
    progetto,
    "Revoked without setting the fields back, the row stays stopped here.",
    fixed = TRUE
  )
  # What moved unknown, the message names everything and keeps the sentence.
  expect_match(ignoto, "la riga resta ferma qui", fixed = TRUE)
})


test_that("il messaggio di una coppia cambiata segue il giro su quando la revoca resta ferma", { # nolint: line_length_linter.
  # eval
  corpo <- function(resta) {
    mail_outcome_message(do.call(
      riga_di_prova,
      utils::modifyList(
        coppia_di_prova,
        list(pair_changed = "person", revocation_stays = resta)
      )
    ))[["body"]]
  }

  # test
  # The round knows whether the revocation would leave on the name carried
  # out; the message says what the round says, and without it falls back on
  # the instance and the project.
  expect_match(corpo("yes"), "la riga resta ferma qui", fixed = TRUE)
  expect_match(corpo("yes"), "the row stays stopped here", fixed = TRUE)
  expect_false(grepl("la riga resta ferma qui", corpo("no"), fixed = TRUE))
  expect_false(grepl("the row stays stopped here", corpo("no"), fixed = TRUE))
  expect_false(grepl("la riga resta ferma qui", corpo(""), fixed = TRUE))
})


test_that("il messaggio nomina tutto cio' che e' cambiato", {
  # eval
  corpo <- mail_outcome_message(do.call(
    riga_di_prova,
    utils::modifyList(
      coppia_di_prova, list(pair_changed = "project_id,person")
    )
  ))[["body"]]

  # test
  expect_match(
    corpo, "la riga ora chiede un altro progetto e un'altra persona",
    fixed = TRUE
  )
  expect_match(
    corpo, "the row now asks for another project and another person",
    fixed = TRUE
  )
})


test_that("il messaggio di un account cambiato su Entra va a IT e non chiede niente al referente", { # nolint: line_length_linter.
  # eval
  rinominato <- mail_outcome_message(riga_di_prova(
    outcome = "transport_error",
    outcome_detail = "TRASPORTO_IDENTITA_CAMBIATA",
    username = "sara.nuova@ubep.unipd.it",
    executed_server = "edc10", executed_project_id = "9029",
    executed_username = "sara.collaudozeta@ubep.unipd.it",
    pair_changed = "account"
  ))[["body"]]
  cancellato <- mail_outcome_message(riga_di_prova(
    outcome = "transport_error",
    outcome_detail = "TRASPORTO_IDENTITA_CAMBIATA", username = "",
    executed_username = "sara.collaudozeta@ubep.unipd.it",
    pair_changed = "account"
  ))[["body"]]

  # test
  expect_match(
    rinominato,
    paste0(
      "La persona di questa richiesta non corrisponde piu', su Entra, ",
      "all'account a cui il canale aveva dato l'accesso"
    ),
    fixed = TRUE
  )
  expect_match(
    rinominato, "rinominato o cancellato, oppure ha cambiato nome o cognome",
    fixed = TRUE
  )
  expect_match(
    rinominato, "sull'istanza non e' cambiato niente", fixed = TRUE
  )
  expect_match(
    rinominato,
    "Eseguita per: sara.collaudozeta@ubep.unipd.it, su edc10, progetto 9029.",
    fixed = TRUE
  )
  expect_match(
    rinominato, "Account trovato ora: sara.nuova@ubep.unipd.it", fixed = TRUE
  )
  expect_match(cancellato, "Account trovato ora: nessuno", fixed = TRUE)
  expect_match(rinominato, "IT verifica l'account su Entra", fixed = TRUE)
  expect_match(rinominato, "non serve modificare la riga", fixed = TRUE)
  expect_match(
    rinominato,
    paste0(
      "The person of this request no longer matches, on Entra, the account ",
      "the channel had given the access to"
    ),
    fixed = TRUE
  )
  expect_match(rinominato, "nothing has changed on the instance", fixed = TRUE)
  expect_match(rinominato, "IT checks the account on Entra", fixed = TRUE)
  # It does not clear by itself, and the message does not say it does.
  expect_false(grepl("torna in coda da sola", rinominato, fixed = TRUE))
  expect_false(
    grepl("returns to the queue by itself", rinominato, fixed = TRUE)
  )
})


# A row closed on a person gone from Entra and set back to active, stopped
# because the channel could not establish whether the account holding the
# name granted is the one of then (item 14 of the limits, 0.29.0).
riattivata_indecisa <- list(
  outcome = "transport_error",
  outcome_detail = "TRASPORTO_IDENTITA_CAMBIATA",
  username = "sara.collaudozeta@ubep.unipd.it",
  executed_server = "edc10", executed_project_id = "9029",
  executed_username = "sara.collaudozeta@ubep.unipd.it",
  pair_changed = "account"
)


test_that("il messaggio della riga riattivata che il canale non sa giudicare dice il suo paragrafo (T15)", { # nolint: line_length_linter.
  # eval
  corpo <- function(...) {
    mail_outcome_message(do.call(
      riga_di_prova, utils::modifyList(riattivata_indecisa, list(...))
    ))[["body"]]
  }
  indecisa <- corpo(reopened_undecided = "yes")
  di_sempre <- corpo()
  vuota <- corpo(reopened_undecided = "")

  # test
  expect_match(
    indecisa,
    paste0(
      "Questa richiesta era stata revocata e chiusa quando la persona non ",
      "era piu' su Entra, ed e' stata riattivata."
    ),
    fixed = TRUE
  )
  expect_match(
    indecisa, "Il canale non e' riuscito a stabilire se l'account",
    fixed = TRUE
  )
  expect_match(
    indecisa,
    paste0(
      "Eseguita per: sara.collaudozeta@ubep.unipd.it, su edc10, progetto ",
      "9029."
    ),
    fixed = TRUE
  )
  expect_match(
    indecisa, "Account trovato ora: sara.collaudozeta@ubep.unipd.it",
    fixed = TRUE
  )
  expect_match(
    indecisa, "IT verifica su Entra quando e' stato creato l'account",
    fixed = TRUE
  )
  expect_match(indecisa, "revocala e compila una richiesta nuova", fixed = TRUE)
  expect_match(indecisa, "IT toglie a mano il vecchio login", fixed = TRUE)
  expect_match(
    indecisa,
    paste0(
      "This request had been revoked and closed when the person was no ",
      "longer on Entra, and was set back to active."
    ),
    fixed = TRUE
  )
  expect_match(
    indecisa, "The channel could not establish whether the account",
    fixed = TRUE
  )
  expect_match(
    indecisa, "IT checks on Entra when the account holding the name was",
    fixed = TRUE
  )
  expect_match(indecisa, "IT takes the old login off by hand", fixed = TRUE)
  expect_false(grepl("non serve modificare la riga", indecisa, fixed = TRUE))
  expect_false(grepl("the row needs no edit", indecisa, fixed = TRUE))
  expect_false(grepl(
    "La persona di questa richiesta non corrisponde piu'", indecisa,
    fixed = TRUE
  ))
  # Without the column, or with it empty, the text of every other row.
  for (testo in list(di_sempre, vuota)) {
    expect_match(
      testo, "La persona di questa richiesta non corrisponde piu'",
      fixed = TRUE
    )
    expect_match(testo, "non serve modificare la riga", fixed = TRUE)
    expect_false(grepl("era stata revocata e chiusa", testo, fixed = TRUE))
  }
})


test_that("il messaggio della riga riattivata che il canale non sa giudicare non dice che la riga riparte da sola (RV11)", { # nolint: line_length_linter.
  # eval
  # On V4b and V4c the log does not change from one round to the next, and
  # the round does not write the identifier: the row stays stopped until it
  # is revoked. The line on the TRASPORTO_ codes says so, and the paragraph
  # does not say the opposite.
  corpo <- mail_outcome_message(do.call(
    riga_di_prova,
    utils::modifyList(riattivata_indecisa, list(reopened_undecided = "yes"))
  ))[["body"]]

  # test
  expect_false(grepl("riparte da sola", corpo, fixed = TRUE))
  expect_false(grepl("starts again by itself", corpo, fixed = TRUE))
  expect_match(corpo, "questo non si risolve da solo", fixed = TRUE)
  expect_match(corpo, "this one does not clear by itself", fixed = TRUE)
})


test_that("il messaggio della riga riattivata che il canale non sa giudicare, senza account trovato, non dice che la riga tiene la coppia (RV1)", { # nolint: line_length_linter.
  # eval
  # V4b and V4c stop the row before the round looks at the directory, also
  # with the person still absent. Revoked, the row closes again and holds no
  # pair: IT has no old row to delete before the new request.
  corpo <- mail_outcome_message(do.call(
    riga_di_prova,
    utils::modifyList(riattivata_indecisa, list(
      username = "", reopened_undecided = "yes", closed_reopened = "yes"
    ))
  ))[["body"]]

  # test
  expect_match(corpo, "Account trovato ora: nessuno", fixed = TRUE)
  expect_match(corpo, "Account found now: none", fixed = TRUE)
  expect_false(grepl("IT toglie a mano il vecchio login", corpo, fixed = TRUE))
  expect_false(grepl("cancella la riga vecchia", corpo, fixed = TRUE))
  expect_false(grepl("IT takes the old login off by hand", corpo, fixed = TRUE))
  expect_false(grepl("deletes the old row", corpo, fixed = TRUE))
  expect_false(grepl("l'account porta il nome", corpo, fixed = TRUE))
  expect_false(grepl("the account holds the name", corpo, fixed = TRUE))
  expect_match(
    corpo, "Il canale non ha trovato su Entra un account per la persona",
    fixed = TRUE
  )
  expect_match(
    corpo,
    paste0(
      "Revocata, la riga si chiude di nuovo e non tiene la coppia contro la ",
      "richiesta nuova."
    ),
    fixed = TRUE
  )
  expect_match(
    corpo, "The channel found no account on Entra for the person",
    fixed = TRUE
  )
  expect_match(
    corpo,
    paste0(
      "Revoked, the row is closed again and does not hold the pair against ",
      "the new request."
    ),
    fixed = TRUE
  )
  expect_match(corpo, "revocala e compila una richiesta nuova", fixed = TRUE)
})


test_that("il messaggio della riga riattivata che il canale non sa giudicare manda IT alla data di creazione dell'account, non ai soli Audit logs", { # nolint: line_length_linter.
  # eval
  # The Audit logs of Entra keep 7 days with Entra ID Free and 30 with P1
  # or P2: a closure and a name given again months before are no longer
  # there. The date of creation of the account stays.
  corpo <- mail_outcome_message(do.call(
    riga_di_prova,
    utils::modifyList(riattivata_indecisa, list(reopened_undecided = "yes"))
  ))[["body"]]

  # test
  expect_match(
    corpo,
    paste0(
      "IT verifica su Entra quando e' stato creato l'account che porta il ",
      "nome (proprieta' dell'utente, Created date time)"
    ),
    fixed = TRUE
  )
  expect_match(
    corpo,
    paste0(
      "IT checks on Entra when the account holding the name was created ",
      "(user properties, Created date time)"
    ),
    fixed = TRUE
  )
  expect_match(corpo, "che tengono da 7 a 30 giorni", fixed = TRUE)
  expect_match(corpo, "which keep 7 to 30 days", fixed = TRUE)
  expect_false(grepl("da quando l'account porta il nome", corpo, fixed = TRUE))
  expect_false(grepl("since when the account holds", corpo, fixed = TRUE))
})


test_that("il messaggio dell'account rinominato su una riga chiusa e riattivata dice che il vecchio login lo toglie IT (E1)", { # nolint: line_length_linter.
  # eval
  # D4 of the design of the 0.29.0: revoked, a closed row revokes the name
  # the round finds now and keeps the pair against the new request.
  corpo <- function(...) {
    mail_outcome_message(riga_di_prova(
      outcome = "transport_error",
      outcome_detail = "TRASPORTO_ACCOUNT_RINOMINATO",
      executed_server = "edc10", executed_project_id = "9029",
      executed_username = "sara.collaudozeta@ubep.unipd.it",
      entra_now = "sara.nuova@ubep.unipd.it", pair_changed = "account", ...
    ))[["body"]]
  }
  chiusa <- corpo(closed_reopened = "yes")
  di_sempre <- corpo()

  # test
  expect_match(chiusa, "IT toglie a mano il vecchio login", fixed = TRUE)
  expect_match(chiusa, "IT takes the old login off by hand", fixed = TRUE)
  expect_false(grepl("IT toglie a mano il vecchio login", di_sempre,
                     fixed = TRUE))
  # The same on the code of the identity changed with an account found.
  trovato <- mail_outcome_message(do.call(
    riga_di_prova,
    utils::modifyList(riattivata_indecisa, list(
      username = "sara.nuova@ubep.unipd.it", closed_reopened = "yes"
    ))
  ))[["body"]]
  expect_match(trovato, "IT toglie a mano il vecchio login", fixed = TRUE)
  expect_match(trovato, "La persona di questa richiesta", fixed = TRUE)
  # Nobody found, a person to create: the revocation closes and holds no
  # pair, and the request filed then creates the person.
  assente <- mail_outcome_message(do.call(
    riga_di_prova,
    utils::modifyList(riattivata_indecisa, list(
      username = "", closed_reopened = "yes"
    ))
  ))[["body"]]
  expect_false(grepl("IT toglie a mano il vecchio login", assente,
                     fixed = TRUE))
})


# The access message of a row whose contact is the person's UBEP address, the
# UPN by decision 12. `identified` carries what the sweep read on the account
# the row resolved to: `mailbox`, its `mail`, and `external`, its first
# address outside the tenant's domain.
accesso_interno <- function(mailbox = "",
                            external = "",
                            owner = "cinzia@ubep.unipd.it",
                            contact_email = "sara.collaudozeta@ubep.unipd.it",
                            copy_to = "it@example.org",
                            redirect_to = NULL) {
  registro <- registro_di_prova(contact_email = contact_email)
  posta <- raccoglitore()
  detto <- mail_round(
    registro[0, colonne_cambiate, drop = FALSE], registro, born = list(),
    mailer = posta[["mailer"]], dry_run = FALSE,
    copy_to = copy_to, redirect_to = redirect_to, granted = "16",
    identified = data.frame(
      record_id = "16", username = "sara.collaudozeta@ubep.unipd.it",
      identity = "existing", owner = owner,
      mailbox = mailbox, external = external,
      stringsAsFactors = FALSE
    )
  )
  list(mandate = posta[["mandate"]](), detto = detto)
}


test_that("un recapito interno manda l'accesso alla casella e all'esterno insieme", { # nolint: line_length_linter.
  # eval
  esito <- accesso_interno(
    mailbox = "sara.collaudozeta@ubep.unipd.it",
    external = "sara.privata@example.org"
  )

  # test
  # One message, two recipients: the person reads it wherever they read.
  expect_length(esito[["mandate"]], 1L)
  expect_equal(
    esito[["mandate"]][[1L]][["to"]],
    c("sara.collaudozeta@ubep.unipd.it", "sara.privata@example.org")
  )
  expect_null(esito[["mandate"]][[1L]][["cc"]])
  expect_match(esito[["mandate"]][[1L]][["body"]], "^Ciao Sara,")
  expect_identical(esito[["detto"]][["contatori"]][["accessi_recapitati"]], 1L)
})


test_that("con una sola delle due l'accesso va a quella", {
  # eval
  casella <- accesso_interno(mailbox = "sara.collaudozeta@ubep.unipd.it")
  esterno <- accesso_interno(external = "sara.privata@example.org")

  # test
  expect_equal(
    casella[["mandate"]][[1L]][["to"]], "sara.collaudozeta@ubep.unipd.it"
  )
  expect_equal(esterno[["mandate"]][[1L]][["to"]], "sara.privata@example.org")
})


test_that("la casella uguale all'esterno riceve l'accesso una volta sola", {
  # eval
  esito <- accesso_interno(
    mailbox = "Sara.Privata@example.org", external = "sara.privata@example.org "
  )

  # test
  # The mail service refuses a personalization that names the same address
  # twice, and the person would read the message twice.
  expect_length(esito[["mandate"]], 1L)
  expect_equal(esito[["mandate"]][[1L]][["to"]], "Sara.Privata@example.org")
})


test_that("senza casella ne' esterno l'accesso va al referente, che avvisa la persona", { # nolint: line_length_linter.
  # eval
  esito <- accesso_interno()
  messaggio <- esito[["mandate"]][[1L]]

  # test
  # Never to the UPN alone: without a mailbox the tenant refuses it, and the
  # mail service then drops every later message to it in silence.
  expect_length(esito[["mandate"]], 1L)
  expect_equal(messaggio[["to"]], "cinzia@ubep.unipd.it")
  expect_null(messaggio[["cc"]])
  expect_match(messaggio[["subject"]], "^Accesso a REDCap")
  # The request comes first, in each language, and names the person.
  parti <- strsplit(messaggio[["body"]], "\n---\n", fixed = TRUE)[[1L]]
  expect_match(parti[[1L]], "^Avvisa tu ", perl = TRUE)
  expect_match(parti[[2L]], "^\nPlease tell ", perl = TRUE)
  for (parte in parti) {
    expect_match(parte, "sara.collaudozeta@ubep.unipd.it", fixed = TRUE)
    expect_match(parte, "Sara Collaudozeta", fixed = TRUE)
  }
  # The message to the person follows unchanged.
  expect_match(parti[[1L]], "Ciao Sara,", fixed = TRUE)
  expect_match(parti[[1L]], "ora hai accesso in REDCap", fixed = TRUE)
  # Recapitato: the referent is who the message is for now.
  expect_identical(esito[["detto"]][["contatori"]][["accessi_recapitati"]], 1L)
  expect_identical(esito[["detto"]][["contatori"]][["accessi_persi"]], 0L)
  expect_equal(esito[["detto"]][["errori"]], character())
})


test_that("senza casella, esterno ne' proprietario l'accesso va a IT e lo dice", { # nolint: line_length_linter.
  # eval
  esito <- accesso_interno(owner = "")
  messaggio <- esito[["mandate"]][[1L]]

  # test
  expect_length(esito[["mandate"]], 1L)
  expect_equal(messaggio[["to"]], "it@example.org")
  expect_null(messaggio[["cc"]])
  parti <- strsplit(messaggio[["body"]], "\n---\n", fixed = TRUE)[[1L]]
  expect_match(parti[[1L]], "^Referente della riga non stabilito", perl = TRUE)
  expect_match(parti[[2L]], "^\nWhoever owns the row", perl = TRUE)
  expect_match(parti[[1L]], "sara.collaudozeta@ubep.unipd.it", fixed = TRUE)
  expect_identical(esito[["detto"]][["contatori"]][["accessi_recapitati"]], 1L)
})


test_that("un recapito esterno riceve l'accesso come prima, qualunque casella abbia l'account", { # nolint: line_length_linter.
  # eval
  esito <- accesso_interno(
    contact_email = "sara.esterna@example.org",
    mailbox = "sara.collaudozeta@ubep.unipd.it",
    external = "sara.privata@example.org"
  )

  # test
  expect_length(esito[["mandate"]], 1L)
  expect_equal(esito[["mandate"]][[1L]][["to"]], "sara.esterna@example.org")
  expect_match(esito[["mandate"]][[1L]][["body"]], "^Ciao Sara,")
})


test_that("redirect_to vince anche sui destinatari dell'accesso interno", {
  # eval
  due <- accesso_interno(
    mailbox = "sara.collaudozeta@ubep.unipd.it",
    external = "sara.privata@example.org",
    redirect_to = "prova@example.org"
  )
  referente <- accesso_interno(redirect_to = "prova@example.org")

  # test
  expect_equal(due[["mandate"]][[1L]][["to"]], "prova@example.org")
  expect_match(
    due[["mandate"]][[1L]][["body"]],
    paste0(
      "[PROVA] Sarebbe andato a: sara.collaudozeta@ubep.unipd.it, ",
      "sara.privata@example.org\n"
    ),
    fixed = TRUE
  )
  expect_equal(referente[["mandate"]][[1L]][["to"]], "prova@example.org")
  expect_match(
    referente[["mandate"]][[1L]][["body"]],
    "[PROVA] Sarebbe andato a: cinzia@ubep.unipd.it\n", fixed = TRUE
  )
})


test_that("il servizio di posta riceve piu' destinatari in un messaggio solo", {
  # eval
  catturata <- NULL
  detto <- httr2::with_mocked_responses(
    function(req) {
      catturata <<- req # nolint: assignment_linter.
      httr2::response(status_code = 202L)
    },
    mail_send(
      api_key = finti[["chiave"]], from = "mittente@example.org",
      to = c("uno@example.org", "due@example.org"),
      subject = "oggetto", body = "corpo"
    )
  )
  inviato <- httr2::req_get_body(catturata)

  # test
  expect_true(detto[["ok"]])
  expect_length(inviato[["personalizations"]], 1L)
  expect_equal(
    vapply(inviato[["personalizations"]][[1L]][["to"]], `[[`, "", "email"),
    c("uno@example.org", "due@example.org")
  )
})


# A mailer that refuses a message with more than one recipient, as the mail
# service does when one address of a personalization is not valid, and takes
# one with a single recipient unless `anche_uno` says otherwise.
rifiuta_i_molti <- function(anche_uno = FALSE) {
  mandate <- list()
  list(
    mailer = function(to, cc, subject, body) {
      mandate[[length(mandate) + 1L]] <<- list( # nolint: assignment_linter.
        to = to, cc = cc, subject = subject, body = body
      )
      if (length(to) > 1L || isTRUE(anche_uno)) {
        list(ok = FALSE, errors = "TRASPORTO_POSTA_RIFIUTATA")
      } else {
        list(ok = TRUE, errors = character())
      }
    },
    mandate = function() mandate
  )
}


interno_di_prova <- "sara.collaudozeta@ubep.unipd.it"


accesso_ritentato <- function(posta,
                              mailbox,
                              external,
                              contact_email = interno_di_prova) {
  registro <- registro_di_prova(contact_email = contact_email)
  mail_round(
    registro[0, colonne_cambiate, drop = FALSE], registro, born = list(),
    mailer = posta[["mailer"]], dry_run = FALSE,
    copy_to = "it@example.org", granted = "16",
    identified = data.frame(
      record_id = "16", username = "sara.collaudozeta@ubep.unipd.it",
      identity = "existing", owner = "cinzia@ubep.unipd.it",
      mailbox = mailbox, external = external, stringsAsFactors = FALSE
    )
  )
}


test_that("rifiutato a due destinatari, l'accesso si ritenta alla sola casella", { # nolint: line_length_linter.
  # eval
  posta <- rifiuta_i_molti()
  detto <- accesso_ritentato(
    posta, "sara.collaudozeta@ubep.unipd.it", "sara.privata@example.org"
  )
  mandate <- posta[["mandate"]]()

  # test
  # The mailbox is the recipient the message reached before the external
  # address existed for it, so a refusal of the two must not cost it.
  expect_length(mandate, 2L)
  expect_equal(
    mandate[[1L]][["to"]],
    c("sara.collaudozeta@ubep.unipd.it", "sara.privata@example.org")
  )
  expect_equal(mandate[[2L]][["to"]], "sara.collaudozeta@ubep.unipd.it")
  expect_equal(mandate[[2L]][["body"]], mandate[[1L]][["body"]])
  expect_identical(detto[["contatori"]][["accessi_recapitati"]], 1L)
  expect_identical(detto[["contatori"]][["accessi_persi"]], 0L)
  expect_equal(detto[["errori"]], character())
})


test_that("rifiutato anche alla casella, l'accesso e' perso una volta sola", {
  # eval
  posta <- rifiuta_i_molti(anche_uno = TRUE)
  detto <- accesso_ritentato(
    posta, "sara.collaudozeta@ubep.unipd.it", "sara.privata@example.org"
  )

  # test
  expect_length(posta[["mandate"]](), 2L)
  expect_identical(detto[["contatori"]][["accessi_recapitati"]], 0L)
  expect_identical(detto[["contatori"]][["accessi_persi"]], 1L)
  expect_equal(detto[["errori"]], "POSTA_ACCESSO_PERSA")
})


test_that("un invio a un destinatario solo che fallisce non si ritenta", {
  # eval
  # The external address alone, the mailbox alone, and a contact outside the
  # domain on an account that has a mailbox: one recipient each, so nothing
  # to fall back to, and the contact outside the domain stays as it was.
  casi <- list(
    list(mailbox = "", external = "sara.privata@example.org"),
    list(mailbox = "sara.collaudozeta@ubep.unipd.it", external = ""),
    list(
      mailbox = "sara.collaudozeta@ubep.unipd.it",
      external = "sara.privata@example.org",
      contact_email = "sara.esterna@example.org"
    )
  )

  for (caso in casi) {
    posta <- rifiuta_i_molti(anche_uno = TRUE)
    detto <- do.call(accesso_ritentato, c(list(posta), caso))

    # test
    expect_length(posta[["mandate"]](), 1L)
    expect_identical(detto[["contatori"]][["accessi_persi"]], 1L)
    expect_equal(detto[["errori"]], "POSTA_ACCESSO_PERSA")
  }
})


# What the round did not read is not what the account does not have. A row
# whose addresses `identified` does not carry, or that `identified` does not
# hold, has nobody the round knows to write to; sent to the referent, the
# message would tell them the account has neither a mailbox nor an external
# address, which nobody checked.
test_that("senza gli indirizzi letti la mail di accesso di un interno e' persa, non mandata al referente", { # nolint: line_length_linter.
  # eval
  registro <- registro_di_prova(contact_email = interno_di_prova)
  manda <- function(identified) {
    posta <- raccoglitore()
    detto <- mail_round(
      registro[0, colonne_cambiate, drop = FALSE], registro, born = list(),
      mailer = posta[["mailer"]], dry_run = FALSE,
      copy_to = "it@example.org", granted = "16", identified = identified
    )
    list(mandate = posta[["mandate"]](), detto = detto)
  }
  casi <- list(
    senza_colonne = data.frame(
      record_id = "16", username = interno_di_prova, identity = "existing",
      owner = "cinzia@ubep.unipd.it", stringsAsFactors = FALSE
    ),
    senza_riga = data.frame(
      record_id = "99", username = interno_di_prova, identity = "existing",
      owner = "cinzia@ubep.unipd.it", mailbox = "", external = "",
      stringsAsFactors = FALSE
    ),
    senza_identified = NULL
  )

  for (nome in names(casi)) {
    esito <- manda(casi[[nome]])

    # test
    expect_length(esito[["mandate"]], 0L)
    expect_identical(
      esito[["detto"]][["contatori"]][["accessi_persi"]], 1L, info = nome
    )
    expect_identical(
      esito[["detto"]][["contatori"]][["accessi_recapitati"]], 0L, info = nome
    )
    expect_equal(esito[["detto"]][["errori"]], "POSTA_ACCESSO_PERSA")
  }
})


test_that("i campi assenti non sono campi vuoti", {
  # eval
  riga <- riga_di_prova(contact_email = interno_di_prova)
  letti <- utils::modifyList(riga, list(mailbox = "", external = ""))

  # test
  # NULL is "the round did not say", character(0) is "the account has none".
  expect_null(mail_access_recipients(riga))
  expect_null(mail_access_recipients(utils::modifyList(
    riga, list(mailbox = "sara.collaudozeta@ubep.unipd.it")
  )))
  expect_identical(mail_access_recipients(letti), character())
  # A contact outside the domain needs neither field.
  expect_identical(
    mail_access_recipients(riga_di_prova()), "sara.esterna@example.org"
  )
})


# A mailer that answers each call with the next answer of its script, and
# repeats the last one past its end.
posta_a_copione <- function(...) {
  risposte <- list(...)
  mandate <- list()
  list(
    mailer = function(to, cc, subject, body) {
      mandate[[length(mandate) + 1L]] <<- list( # nolint: assignment_linter.
        to = to, cc = cc, subject = subject, body = body
      )
      risposte[[min(length(mandate), length(risposte))]]
    },
    mandate = function() mandate
  )
}


test_that("un trasporto non raggiungibile non fa ritentare la casella", {
  # eval
  # The connection can fail after the service has taken the message: a 202
  # nobody read. A second send would deliver it to the mailbox twice.
  posta <- posta_a_copione(
    list(ok = FALSE, errors = "TRASPORTO_POSTA_NON_RAGGIUNGIBILE"),
    list(ok = TRUE, errors = character())
  )
  detto <- accesso_ritentato(
    posta, interno_di_prova, "sara.privata@example.org"
  )

  # test
  expect_length(posta[["mandate"]](), 1L)
  expect_identical(detto[["contatori"]][["accessi_persi"]], 1L)
  expect_identical(detto[["contatori"]][["accessi_recapitati"]], 0L)
  expect_equal(detto[["errori"]], "POSTA_ACCESSO_PERSA")
})


test_that("con redirect_to un rifiuto non si ritenta", {
  # eval
  # Redirected, the message has one recipient, the test address: a refusal
  # of it cannot come from the external address, and a second send would go
  # to the same test address again.
  posta <- posta_a_copione(
    list(ok = FALSE, errors = "TRASPORTO_POSTA_RIFIUTATA"),
    list(ok = TRUE, errors = character())
  )
  registro <- registro_di_prova(contact_email = interno_di_prova)
  detto <- mail_round(
    registro[0, colonne_cambiate, drop = FALSE], registro, born = list(),
    mailer = posta[["mailer"]], dry_run = FALSE,
    redirect_to = "prova@example.org", copy_to = "it@example.org",
    granted = "16",
    identified = data.frame(
      record_id = "16", username = interno_di_prova, identity = "existing",
      owner = "cinzia@ubep.unipd.it", mailbox = interno_di_prova,
      external = "sara.privata@example.org", stringsAsFactors = FALSE
    )
  )

  # test
  expect_length(posta[["mandate"]](), 1L)
  expect_equal(posta[["mandate"]]()[[1L]][["to"]], "prova@example.org")
  expect_identical(detto[["contatori"]][["accessi_persi"]], 1L)
  expect_equal(detto[["errori"]], "POSTA_ACCESSO_PERSA")
})


test_that("il messaggio di un nome riassegnato su Entra dice che cosa fare, nelle due lingue", { # nolint: line_length_linter.
  # eval
  corpo <- disteso(mail_outcome_message(riga_di_prova(
    outcome = "transport_error",
    outcome_detail = "TRASPORTO_NOME_RIASSEGNATO",
    executed_server = "edc10", executed_project_id = "9029",
    executed_username = "sara.collaudozeta@ubep.unipd.it",
    pair_changed = "account"
  ))[["body"]])

  # test
  expect_match(
    corpo,
    paste0(
      "Il nome utente a cui il canale aveva dato l'accesso ora e' di un ",
      "altro account su Entra"
    ),
    fixed = TRUE
  )
  expect_match(
    corpo,
    "Eseguita per: sara.collaudozeta@ubep.unipd.it, su edc10, progetto 9029.",
    fixed = TRUE
  )
  expect_match(
    corpo, "IT verifica su Entra chi porta ora il nome", fixed = TRUE
  )
  # The owner revokes the row in any case, decided on 2026-11-15 with the
  # documents 00.05: the name carried out, with the access, belongs now to
  # another account. A person who still needs the access gets a new request.
  expect_match(
    corpo,
    paste0(
      "Non modificare la riga: revocala in ogni caso, perche' il nome ",
      "eseguito, con l'accesso, ora e' di un altro account, e la revoca ",
      "toglie l'accesso a quel nome. Se alla persona l'accesso serve ancora, ",
      "compila poi una richiesta nuova."
    ),
    fixed = TRUE
  )
  expect_match(
    corpo,
    "The username the channel had given the access to belongs now to another",
    fixed = TRUE
  )
  expect_match(corpo, "IT checks on Entra who holds the name now", fixed = TRUE)
  expect_match(
    corpo,
    paste0(
      "Do not edit the row: revoke it in any case, because the username ",
      "applied, with the access, belongs now to another account, and the ",
      "revocation takes the access away from that name. If the person still ",
      "needs the access, then fill in a new request."
    ),
    fixed = TRUE
  )
  expect_false(grepl("non serve piu'", corpo, fixed = TRUE))
  expect_false(grepl("no longer needed", corpo, fixed = TRUE))
  # It does not clear by itself, and the message does not say it does.
  expect_match(corpo, "questo non si risolve da solo", fixed = TRUE)
  expect_match(corpo, "this one does not clear by itself", fixed = TRUE)
  expect_false(grepl("Account trovato ora:", corpo, fixed = TRUE))
  expect_false(grepl("Nome utente dell'account ora:", corpo, fixed = TRUE))
})


test_that("il messaggio di un account rinominato su Entra nomina il nome nuovo", { # nolint: line_length_linter.
  # eval
  corpo <- disteso(mail_outcome_message(riga_di_prova(
    outcome = "transport_error",
    outcome_detail = "TRASPORTO_ACCOUNT_RINOMINATO",
    executed_server = "edc10", executed_project_id = "9029",
    executed_username = "sara.collaudozeta@ubep.unipd.it",
    entra_now = "sara.nuova@ubep.unipd.it",
    pair_changed = "account"
  ))[["body"]])
  senza <- disteso(mail_outcome_message(riga_di_prova(
    outcome = "transport_error",
    outcome_detail = "TRASPORTO_ACCOUNT_RINOMINATO",
    executed_username = "sara.collaudozeta@ubep.unipd.it"
  ))[["body"]])

  # test
  expect_match(
    corpo,
    "L'account a cui il canale aveva dato l'accesso e' stato rinominato",
    fixed = TRUE
  )
  expect_match(
    corpo, "Nome utente dell'account ora: sara.nuova@ubep.unipd.it",
    fixed = TRUE
  )
  expect_match(corpo, "Non serve modificare la riga", fixed = TRUE)
  expect_match(corpo, "compila una richiesta nuova", fixed = TRUE)
  expect_match(
    corpo, "Username of the account now: sara.nuova@ubep.unipd.it",
    fixed = TRUE
  )
  expect_match(corpo, "The row needs no edit", fixed = TRUE)
  expect_match(corpo, "questo non si risolve da solo", fixed = TRUE)
  expect_false(grepl("Account trovato ora:", corpo, fixed = TRUE))
  expect_match(senza, "Nome utente dell'account ora: non noto", fixed = TRUE)
  expect_match(senza, "Username of the account now: unknown", fixed = TRUE)
})
