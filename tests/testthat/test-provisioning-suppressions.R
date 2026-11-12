# Le soppressioni di SendGrid lette ogni giorno e incrociate coi destinatari
# del canale. Ogni indirizzo di questo file e' inventato, su example.org; il
# dominio del tenant, dove serve, e' interno.example.org.

dominio <- "interno.example.org"
adesso <- as.POSIXct("2026-11-12 06:30", tz = "UTC")

# Secondi dall'epoca, come SendGrid scrive `created`.
secondi <- function(quando) {
  as.numeric(as.POSIXct(quando, tz = "UTC"))
}

# Le voci lette, come le restituisce suppression_read().
lette <- function(...) {
  voci <- list(...)
  list(
    ok = TRUE, errors = character(),
    voci = do.call(rbind, c(
      list(suppression_entries()),
      lapply(voci, function(v) {
        suppression_entries(
          list(list(
            email = v[["email"]], created = secondi(v[["quando"]]),
            reason = v[["motivo"]] %||% ""
          )),
          v[["lista"]]
        )
      })
    ))
  )
}

voce <- function(lista, email, quando = "2026-11-11 20:00", motivo = NULL) {
  list(lista = lista, email = email, quando = quando, motivo = motivo)
}

# Una riga del registro come il rapporto la legge.
riga_soppressioni <- function(...) {
  utils::modifyList(
    list(
      record_id = "61", server = "edc10", project_id = "9301",
      username = "lia.finta@interno.example.org",
      first_name = "Lia", last_name = "Finta",
      contact_email = "lia.esterna@example.org", identity = "created",
      requested_by = "", owned_by = "", request_status = "active",
      outcome = "applied", outcome_detail = ""
    ),
    list(...)
  )
}

registro_soppressioni <- function(...) {
  do.call(rbind, lapply(list(...), as.data.frame, stringsAsFactors = FALSE))
}

rubrica_soppressioni <- function(...) {
  directory_frame(list(...))
}

conto_soppressioni <- function(upn, mail = "", altre = character()) {
  list(
    id = "00000000-0000-0000-0000-000000000061", userPrincipalName = upn,
    givenName = "Lia", surname = "Finta", mail = mail,
    otherMails = as.list(altre), officeLocation = "",
    createdDateTime = "2026-09-12T08:00:00Z",
    lastPasswordChangeDateTime = "2026-09-12T08:00:00Z",
    accountEnabled = TRUE, userType = "Member"
  )
}

destinatari_di <- function(registro, creatori = rep("", nrow(registro)),
                           proprietari = rep("", nrow(registro)),
                           rubrica = rubrica_soppressioni(),
                           copia = "it@example.org") {
  suppression_recipients(
    registro, creatori, proprietari, rubrica, copia, domain = dominio
  )
}


# --- le liste ---------------------------------------------------------------

test_that("quattro liste sopprimono, Blocks no", {
  liste <- suppression_lists()

  expect_setequal(
    liste[["lista"]],
    c("bounces", "blocks", "spam_reports", "invalid_emails", "unsubscribes")
  )
  expect_equal(liste[["lista"]][!liste[["sopprime"]]], "blocks")
})


# --- la lettura -------------------------------------------------------------

# Un servizio finto: `pagine` dice quante voci ha ogni lista, `rifiuta` una
# risposta per una lista e una pagina. Conta le richieste fatte.
servizio_finto <- function(voci = c(bounces = 0L), rifiuta = NULL,
                           stato = 403L) {
  fatte <- new.env()
  fatte[["richieste"]] <- list()
  list(
    fatte = fatte,
    risponde = function(req) {
      fatte[["richieste"]][[length(fatte[["richieste"]]) + 1L]] <- req
      lista <- sub("^.*/suppression/([a-z_]+).*$", "\\1", req[["url"]])
      parti <- httr2::url_parse(req[["url"]])[["query"]]
      limite <- as.integer(parti[["limit"]])
      da <- as.integer(parti[["offset"]])
      pagina <- da %/% limite + 1L
      if (!is.null(rifiuta) && identical(rifiuta[["lista"]], lista) &&
            identical(rifiuta[["pagina"]], pagina)) {
        return(httr2::response(
          status_code = stato,
          body = charToRaw('{"errors":[{"message":"access forbidden"}]}')
        ))
      }
      quante <- if (lista %in% names(voci)) voci[[lista]] else 0L
      numeri <- seq_len(quante)
      numeri <- numeri[numeri > da & numeri <= da + limite]
      corpo <- lapply(numeri, function(n) {
        list(
          created = 1762900000 + n,
          email = sprintf("persona%04d@example.org", n),
          reason = "550 5.1.1 finta"
        )
      })
      httr2::response(
        status_code = 200L,
        headers = list(`Content-Type` = "application/json"),
        body = charToRaw(as.character(
          jsonlite::toJSON(corpo, auto_unbox = TRUE)
        ))
      )
    }
  )
}


test_that("la lettura e' a pagine, e le legge tutte", {
  servizio <- servizio_finto(voci = c(bounces = 1200L, blocks = 3L))

  letto <- httr2::with_mocked_responses(
    servizio[["risponde"]], suppression_read(finti[["chiave"]])
  )

  expect_true(letto[["ok"]])
  expect_equal(letto[["errors"]], character())
  expect_equal(sum(letto[["voci"]][["lista"]] == "bounces"), 1200L)
  expect_equal(sum(letto[["voci"]][["lista"]] == "blocks"), 3L)
  expect_equal(anyDuplicated(letto[["voci"]][["email"]][
    letto[["voci"]][["lista"]] == "bounces"
  ]), 0L)
  expect_s3_class(letto[["voci"]][["creata"]], "POSIXct")
  # Tre pagine per Bounces (500, 500, 200), una per ciascuna delle altre.
  expect_length(servizio[["fatte"]][["richieste"]], 3L + 4L)
})


test_that("la lettura chiede solo GET, con la chiave nell'intestazione", {
  servizio <- servizio_finto(voci = c(bounces = 2L))

  httr2::with_mocked_responses(
    servizio[["risponde"]], suppression_read(finti[["chiave"]])
  )

  richieste <- servizio[["fatte"]][["richieste"]]
  expect_true(all(vapply(richieste, function(r) {
    identical(httr2::req_get_method(r), "GET")
  }, NA)))
  expect_true(all(vapply(richieste, function(r) {
    startsWith(r[["url"]], "https://api.sendgrid.com/v3/suppression/")
  }, NA)))
  expect_false(any(vapply(richieste, function(r) {
    grepl(finti[["chiave"]], r[["url"]], fixed = TRUE)
  }, NA)))
  expect_equal(
    httr2::req_get_headers(richieste[[1L]], redacted = "reveal")[[
      "Authorization"
    ]],
    paste("Bearer", finti[["chiave"]])
  )
})


test_that("una lettura rifiutata, 403 o 401, non si legge e lo dice", {
  for (stato in c(403L, 401L)) {
    servizio <- servizio_finto(
      voci = c(bounces = 2L), rifiuta = list(lista = "bounces", pagina = 1L),
      stato = stato
    )

    expect_message(
      letto <- httr2::with_mocked_responses(
        servizio[["risponde"]], suppression_read(finti[["chiave"]])
      ),
      "access forbidden"
    )

    expect_false(letto[["ok"]], info = stato)
    expect_equal(
      letto[["errors"]], "TRASPORTO_SOPPRESSIONI_NON_LEGGIBILI", info = stato
    )
    expect_equal(nrow(letto[["voci"]]), 0L)
  }
})


test_that("una rete che non risponde non si legge", {
  letto <- suppressMessages(httr2::with_mocked_responses(
    function(req) stop("rete giu'"), suppression_read(finti[["chiave"]])
  ))

  expect_false(letto[["ok"]])
  expect_equal(letto[["errors"]], "TRASPORTO_SOPPRESSIONI_NON_LEGGIBILI")
})


test_that("una pagina fallita a meta' lascia la lettura incompleta", {
  servizio <- servizio_finto(
    voci = c(bounces = 1200L), rifiuta = list(lista = "bounces", pagina = 2L),
    stato = 500L
  )

  letto <- suppressMessages(httr2::with_mocked_responses(
    servizio[["risponde"]], suppression_read(finti[["chiave"]])
  ))

  expect_false(letto[["ok"]])
  expect_equal(letto[["errors"]], "TRASPORTO_SOPPRESSIONI_INCOMPLETE")
  # Ci si ferma al primo guasto.
  expect_length(servizio[["fatte"]][["richieste"]], 2L)
})


test_that("una lista che non finisce e' incompleta", {
  servizio <- servizio_finto(voci = c(bounces = 1200L))

  letto <- suppressMessages(httr2::with_mocked_responses(
    servizio[["risponde"]],
    suppression_read(finti[["chiave"]], limit = 100L, max_pages = 3L)
  ))

  expect_false(letto[["ok"]])
  expect_equal(letto[["errors"]], "TRASPORTO_SOPPRESSIONI_INCOMPLETE")
})


test_that("una risposta che non e' un elenco non e' una lista vuota", {
  letto <- suppressMessages(httr2::with_mocked_responses(
    function(req) {
      httr2::response(
        status_code = 200L,
        headers = list(`Content-Type` = "application/json"),
        body = charToRaw('{"result": []}')
      )
    },
    suppression_read(finti[["chiave"]])
  ))

  expect_false(letto[["ok"]])
  expect_equal(letto[["errors"]], "TRASPORTO_SOPPRESSIONI_NON_LEGGIBILI")
})


# --- i destinatari ----------------------------------------------------------

test_that("la casella di IT c'e' anche senza registro", {
  d <- suppression_recipients(NULL, character(), character(), NULL,
                              " it@example.org ")

  expect_equal(d[["classi"]], "casella_it")
  expect_equal(d[["destinatari"]][["indirizzo"]], "it@example.org")
  expect_equal(d[["destinatari"]][["record_id"]], "")
})


test_that("senza la casella di IT la sua classe non c'e'", {
  d <- destinatari_di(registro_soppressioni(riga_soppressioni()), copia = NULL)

  expect_setequal(d[["classi"]], c("referente", "recapito"))
  expect_false("casella_it" %in% d[["destinatari"]][["classe"]])
})


test_that("i referenti sono proprietari, owned_by e creatori delle attive", {
  registro <- registro_soppressioni(
    riga_soppressioni(record_id = "61", owned_by = "Ref.Uno@example.org "),
    riga_soppressioni(record_id = "62"),
    riga_soppressioni(record_id = "63", request_status = "revoked",
                      owned_by = "ref.revocata@example.org")
  )

  d <- destinatari_di(
    registro,
    creatori = c("ref.uno@example.org", "ref.due@example.org",
                 "ref.solo-revocata@example.org"),
    proprietari = c("ref.uno@example.org", NA, "ref.revocata@example.org")
  )
  referenti <- d[["destinatari"]][d[["destinatari"]][["classe"]] == "referente",
                                  , drop = FALSE]

  expect_setequal(
    tolower(referenti[["indirizzo"]]),
    c("ref.uno@example.org", "ref.due@example.org")
  )
  # Una volta per riga, qualunque sia la strada da cui arriva.
  expect_equal(sum(referenti[["record_id"]] == "61"), 1L)
})


test_that("il recapito interno e' casella ed esterno, non il nome utente", {
  registro <- registro_soppressioni(riga_soppressioni(
    contact_email = "lia.finta@interno.example.org", identity = "existing"
  ))
  rubrica <- rubrica_soppressioni(conto_soppressioni(
    "lia.finta@interno.example.org",
    mail = "Lia.Casella@interno.example.org",
    altre = "lia.altrove@example.org"
  ))

  d <- destinatari_di(registro, rubrica = rubrica)
  recapiti <- d[["destinatari"]][d[["destinatari"]][["classe"]] == "recapito",
                                 , drop = FALSE]

  expect_setequal(
    recapiti[["indirizzo"]],
    c("Lia.Casella@interno.example.org", "lia.altrove@example.org")
  )
})


test_that("Contact e-mail conta quando il canale ha creato l'account", {
  registro <- registro_soppressioni(
    riga_soppressioni(record_id = "61"),
    riga_soppressioni(record_id = "62", identity = "existing",
                      contact_email = "lia.finta@interno.example.org")
  )

  d <- destinatari_di(registro)
  recapiti <- d[["destinatari"]][d[["destinatari"]][["classe"]] == "recapito",
                                 , drop = FALSE]

  expect_equal(recapiti[["indirizzo"]], "lia.esterna@example.org")
  expect_equal(recapiti[["record_id"]], "61")
})


# --- l'incrocio -------------------------------------------------------------

test_that("un recapito in Bounces da ieri e IT in Global Unsubscribes", {
  d <- destinatari_di(registro_soppressioni(riga_soppressioni()))

  m <- suppression_match(
    lette(
      voce("bounces", "lia.esterna@example.org", motivo = "550 no\tsuch"),
      voce("unsubscribes", "it@example.org", "2026-06-01 10:00")
    ),
    d, adesso
  )

  expect_true(m[["soppressioni_lette"]])
  expect_true(m[["soppressa_casella_it"]])
  expect_equal(m[["soppressi_referenti"]], 0L)
  expect_equal(m[["soppressi_recapiti"]], 1L)
  expect_equal(m[["soppressi_recapiti_nuovi"]], 1L)
  expect_equal(m[["bloccati_nuovi"]], 0L)
  expect_equal(nrow(m[["dettaglio"]]), 2L)
  recapito <- m[["dettaglio"]][m[["dettaglio"]][["classe"]] == "recapito", ]
  expect_equal(recapito[["record_id"]], "61")
  expect_equal(recapito[["lista"]], "bounces")
  expect_equal(recapito[["creata"]], "2026-11-11 20:00")
  expect_equal(recapito[["motivo"]], "550 no such")
})


test_that("una voce di dieci giorni fa e' uno stato, non una novita'", {
  d <- destinatari_di(registro_soppressioni(riga_soppressioni()))

  m <- suppression_match(
    lette(voce("bounces", "lia.esterna@example.org", "2026-11-02 06:00")),
    d, adesso
  )

  expect_equal(m[["soppressi_recapiti"]], 1L)
  expect_equal(m[["soppressi_recapiti_nuovi"]], 0L)
  expect_false(m[["soppressa_casella_it"]])
})


test_that("la casella interna conta, il nome utente no", {
  registro <- registro_soppressioni(riga_soppressioni(
    contact_email = "lia.finta@interno.example.org", identity = "existing"
  ))
  rubrica <- rubrica_soppressioni(conto_soppressioni(
    "lia.finta@interno.example.org",
    mail = "lia.casella@interno.example.org"
  ))
  d <- destinatari_di(registro, rubrica = rubrica)

  casella <- suppression_match(
    lette(voce("bounces", "lia.casella@interno.example.org")), d, adesso
  )
  nome <- suppression_match(
    lette(voce("bounces", "lia.finta@interno.example.org")), d, adesso
  )

  expect_equal(casella[["soppressi_recapiti"]], 1L)
  expect_equal(nome[["soppressi_recapiti"]], 0L)
  expect_equal(nrow(nome[["dettaglio"]]), 0L)
})


test_that("Blocks e' un evento contato, e non sopprime", {
  d <- destinatari_di(registro_soppressioni(riga_soppressioni()))

  ieri <- suppression_match(
    lette(voce("blocks", "lia.esterna@example.org")), d, adesso
  )
  vecchio <- suppression_match(
    lette(voce("blocks", "lia.esterna@example.org", "2026-11-01 06:00")),
    d, adesso
  )

  expect_equal(ieri[["bloccati_nuovi"]], 1L)
  expect_equal(ieri[["soppressi_recapiti"]], 0L)
  expect_equal(ieri[["soppressi_recapiti_nuovi"]], 0L)
  expect_equal(ieri[["dettaglio"]][["lista"]], "blocks")
  expect_equal(vecchio[["bloccati_nuovi"]], 0L)
  expect_equal(nrow(vecchio[["dettaglio"]]), 0L)
})


test_that("maiuscole e spazi diversi fra lista e registro si trovano", {
  d <- destinatari_di(registro_soppressioni(riga_soppressioni(
    contact_email = " Lia.Esterna@Example.org "
  )))

  m <- suppression_match(
    lette(voce("invalid_emails", "lia.esterna@example.ORG  ")), d, adesso
  )

  expect_equal(m[["soppressi_recapiti"]], 1L)
})


test_that("un referente su due strade conta una volta", {
  registro <- registro_soppressioni(
    riga_soppressioni(record_id = "61", owned_by = "ref.uno@example.org"),
    riga_soppressioni(record_id = "62"),
    riga_soppressioni(record_id = "63", request_status = "revoked")
  )
  d <- destinatari_di(
    registro,
    creatori = c("ref.due@example.org", "ref.uno@example.org",
                 "ref.revocata@example.org"),
    proprietari = c("ref.uno@example.org", "", "")
  )

  m <- suppression_match(
    lette(
      voce("spam_reports", "REF.UNO@example.org"),
      voce("bounces", "ref.uno@example.org"),
      voce("bounces", "ref.revocata@example.org")
    ),
    d, adesso
  )

  expect_equal(m[["soppressi_referenti"]], 1L)
  referente <- m[["dettaglio"]][m[["dettaglio"]][["classe"]] == "referente", ]
  expect_setequal(referente[["record_id"]], "61,62")
  expect_setequal(referente[["lista"]], c("spam_reports", "bounces"))
})


test_that("approvatori e indirizzo delle risposte non sono destinatari", {
  d <- destinatari_di(registro_soppressioni(riga_soppressioni()))

  m <- suppression_match(
    lette(
      voce("bounces", "approvatore-it"),
      voce("bounces", "risposte@example.org")
    ),
    d, adesso
  )

  expect_equal(m[["soppressi_referenti"]], 0L)
  expect_equal(m[["soppressi_recapiti"]], 0L)
  expect_false(m[["soppressa_casella_it"]])
})


test_that("liste non lette: tutto nullo, e nessun dettaglio", {
  d <- destinatari_di(registro_soppressioni(riga_soppressioni()))

  for (lettura in list(
    NULL,
    list(ok = FALSE, errors = "TRASPORTO_SOPPRESSIONI_NON_LEGGIBILI",
         voci = suppression_entries())
  )) {
    m <- suppression_match(lettura, d, adesso)

    expect_false(m[["soppressioni_lette"]])
    expect_true(is.na(m[["soppressa_casella_it"]]))
    expect_true(is.na(m[["soppressi_referenti"]]))
    expect_true(is.na(m[["soppressi_recapiti"]]))
    expect_true(is.na(m[["soppressi_recapiti_nuovi"]]))
    expect_true(is.na(m[["bloccati_nuovi"]]))
    expect_equal(nrow(m[["dettaglio"]]), 0L)
  }
})


test_that("registro non letto: la casella di IT si giudica, il resto no", {
  d <- suppression_recipients(NULL, character(), character(), NULL,
                              "it@example.org")

  m <- suppression_match(
    lette(voce("bounces", "it@example.org")), d, adesso
  )

  expect_false(m[["soppressioni_lette"]])
  expect_true(m[["soppressa_casella_it"]])
  expect_true(is.na(m[["soppressi_referenti"]]))
  expect_true(is.na(m[["soppressi_recapiti"]]))
  expect_true(is.na(m[["bloccati_nuovi"]]))
})


test_that("ogni richiesta delle soppressioni ha un tempo massimo", {
  # Dalla revisione del 2026-11-12 (R2): la lettura sta prima del rapporto,
  # in un'unita' oneshot senza TimeoutStartSec, e un servizio che accetta la
  # connessione e non risponde la terrebbe ferma.
  viste <- list()
  httr2::local_mocked_responses(function(req) {
    viste[[length(viste) + 1L]] <<- req
    httr2::response_json(body = list())
  })

  esito <- suppression_read(api_key = finti[["chiave"]])

  expect_true(esito[["ok"]])
  expect_length(viste, 5L)
  for (req in viste) {
    expect_false(is.null(req[["options"]][["timeout_ms"]]))
  }
})


test_that("un tempo scaduto e' una lettura non riuscita", {
  letto <- suppressMessages(httr2::with_mocked_responses(
    function(req) {
      stop(structure(
        class = c("httr2_failure", "httr2_error", "rlang_error", "error",
                  "condition"),
        list(message = "Timeout was reached", call = NULL)
      ))
    },
    suppression_read(finti[["chiave"]])
  ))

  expect_false(letto[["ok"]])
  expect_equal(letto[["errors"]], "TRASPORTO_SOPPRESSIONI_NON_LEGGIBILI")
})


test_that("una voce nuova si conta un giorno solo, nemmeno col ritardo", {
  # Dalla revisione del 2026-11-12 (R3): con una lavorazione ogni 24 ore e
  # una finestra di 26 le due ore di sovrapposizione si contavano due volte.
  # Il timer parte alle 06:30 UTC con fino a cinque minuti di ritardo.
  d <- list(
    destinatari = data.frame(
      indirizzo = "lia.esterna@example.org", classe = "recapito",
      record_id = "61", stringsAsFactors = FALSE
    ),
    classi = c("casella_it", "referente", "recapito")
  )
  nuove <- function(creata, corse) {
    lettura <- lette(voce("bounces", "lia.esterna@example.org", creata))
    vapply(corse, function(quando) {
      suppression_match(
        lettura, d, as.POSIXct(quando, tz = "UTC")
      )[["soppressi_recapiti_nuovi"]]
    }, 0L, USE.NAMES = FALSE)
  }

  # Prima del taglio delle 06:30: conta l'11, non il 12.
  expect_equal(nuove("2026-11-11 05:00",
                     c("2026-11-11 06:30", "2026-11-12 06:30")), c(1L, 0L))
  # Fra il taglio e la corsa in ritardo: conta il giorno dopo, una volta.
  expect_equal(
    nuove("2026-11-11 06:32", c("2026-11-11 06:34", "2026-11-12 06:31",
                                "2026-11-13 06:33")),
    c(0L, 1L, 0L)
  )
  # Una corsa a mano nel pomeriggio conta come quella del mattino.
  expect_equal(nuove("2026-11-11 05:00", "2026-11-11 15:00"), 1L)
})
