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
      "mail nuova con la sola chiave: il nome utente le e' gia' arrivato in ",
      "un messaggio a parte. Usa l'indirizzo che conosci dalla tua ",
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
      "e-mail with the key alone: the user name has already reached them in a ",
      "separate message. Use the address you know from your own ",
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
  # One date: the deadline, once in each language, and no other beside it.
  expect_equal(
    unlist(regmatches(righe, gregexpr("[0-9]{4}-[0-9]{2}-[0-9]{2}", righe))),
    rep("2026-12-21", 2L)
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


registro_di_prova <- function(...) {
  as.data.frame(riga_di_prova(...), stringsAsFactors = FALSE)
}


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
