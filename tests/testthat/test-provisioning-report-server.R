# The report's reading of the REDCap servers. Every person, address and server
# in this file is invented; the module is replaced by a stand-in that answers
# the way the real one does, entry by entry.

carla <- "carla.inventata@ubep.unipd.it"
dario <- "dario.ipotetico@ubep.unipd.it"

# One entry of an `accounts` answer, as the module shapes it and `jsonlite`
# reads it: dates as UTC strings or NULL, names as they were asked.
voce <- function(username,
                 exists = TRUE,
                 firstvisit = "2026-10-20T07:15:00Z",
                 lastlogin = "2026-11-03T08:00:00Z",
                 lastactivity = "2026-11-05T10:00:00Z") {
  list(
    username = username, exists = exists, user_creation = firstvisit,
    user_firstvisit = firstvisit, user_lastlogin = lastlogin,
    user_firstactivity = NULL, user_lastactivity = lastactivity
  )
}

voce_carla <- voce(carla)

# A module's answer, `ok` as `module_accounts()` gives it.
risposta <- function(voci) {
  list(
    ok = TRUE, errors = character(), payload = list(accounts = voci),
    gate = "collaudata"
  )
}

# The frame of a set of entries, asked for the same names they carry.
conti_di <- function(...) {
  voci <- list(...)
  chiesti <- vapply(voci, function(x) x[["username"]], character(1))
  report_accounts_frame(list(accounts = voci), chiesti)
}


# --- the frame ---------------------------------------------------------------

test_that("the frame carries the three dates as UTC times", {
  # eval
  conti <- report_accounts_frame(list(accounts = list(voce_carla)), carla)

  # test
  expect_s3_class(conti, "data.frame")
  expect_named(
    conti,
    c("username", "exists", "firstvisit", "lastlogin", "lastactivity")
  )
  expect_equal(conti[["username"]], carla)
  expect_true(conti[["exists"]])
  expect_s3_class(conti[["lastlogin"]], "POSIXct")
  expect_equal(attr(conti[["firstvisit"]], "tzone"), "UTC")
  expect_equal(
    format(conti[["lastactivity"]], tz = "UTC"), "2026-11-05 10:00:00"
  )
})


test_that("an absent date is NA, and an absent person has no dates", {
  # eval
  conti <- report_accounts_frame(
    list(accounts = list(
      voce(carla, lastlogin = NULL, lastactivity = NULL),
      voce(
        dario, exists = FALSE, firstvisit = NULL, lastlogin = NULL,
        lastactivity = NULL
      )
    )),
    c(carla, dario)
  )

  # test
  expect_true(is.na(conti[["lastlogin"]][[1L]]))
  expect_false(is.na(conti[["firstvisit"]][[1L]]))
  expect_false(conti[["exists"]][[2L]])
  expect_true(is.na(conti[["firstvisit"]][[2L]]))
})


test_that("revisione 1: una risposta che tace un nome non e' una lettura", {
  # eval
  local_mocked_bindings(
    module_accounts = function(server, secret, usernames, ...) {
      risposta(list(voce_carla))
    }
  )
  letture <- report_server_reads(
    list(edc10 = c(carla, dario)),
    c(edc10 = "edc10.example.org"), c(edc10 = "s3cret")
  )

  # test
  expect_null(
    report_accounts_frame(list(accounts = list(voce_carla)), c(carla, dario))
  )
  expect_null(report_accounts_frame(list(accounts = "rotto"), carla))
  expect_false(letture[["edc10"]][["letto"]])
  expect_equal(letture[["edc10"]][["motivo"]], "INTERNO")
})


test_that("a malformed answer is not a reading", {
  # eval
  asked <- carla
  senza_exists <- list(list(username = carla))
  exists_testo <- list(list(username = carla, exists = "si"))
  senza_nome <- list(list(exists = TRUE))
  nome_na <- list(list(username = NA_character_, exists = TRUE))

  # test
  expect_null(report_accounts_frame(list(), asked))
  expect_null(report_accounts_frame(NULL, asked))
  expect_null(report_accounts_frame(list(accounts = NULL), asked))
  expect_null(report_accounts_frame(list(accounts = list()), asked))
  expect_null(report_accounts_frame(list(accounts = list("x")), asked))
  expect_null(report_accounts_frame(list(accounts = senza_exists), asked))
  expect_null(report_accounts_frame(list(accounts = exists_testo), asked))
  expect_null(report_accounts_frame(list(accounts = senza_nome), asked))
  expect_null(report_accounts_frame(list(accounts = nome_na), asked))
  # A date that is there but does not read is not "never": it is a reading
  # that failed.
  expect_null(
    report_accounts_frame(
      list(accounts = list(voce(carla, firstvisit = "non una data"))), asked
    )
  )
})


# The payload of a body as `module_call()` reads it, through the same parser.
payload_di <- function(voci) {
  body <- sprintf(
    '{"contract_version": 4, "dry_run": true, "accounts": [%s],
    "errors": []}',
    paste(voci, collapse = ", ")
  )
  parse_module_response(body, 200L, accepted = 4L)[["payload"]]
}

test_that("a missing date key is a malformed entry, a null one is not", {
  # eval
  senza_chiave <- payload_di(
    '{"username": "carla.inventata@ubep.unipd.it", "exists": true,
    "user_lastlogin": null, "user_lastactivity": null}'
  )
  senza_altre <- payload_di(
    '{"username": "carla.inventata@ubep.unipd.it", "exists": true,
    "user_firstvisit": "2026-10-20T07:15:00Z"}'
  )
  nulle <- payload_di(
    '{"username": "carla.inventata@ubep.unipd.it", "exists": true,
    "user_firstvisit": null, "user_lastlogin": null,
    "user_lastactivity": null}'
  )
  vuote <- payload_di(
    '{"username": "carla.inventata@ubep.unipd.it", "exists": true,
    "user_firstvisit": "", "user_lastlogin": "", "user_lastactivity": ""}'
  )
  conti <- report_accounts_frame(nulle, carla)

  # test
  expect_null(report_accounts_frame(senza_chiave, carla))
  expect_null(report_accounts_frame(senza_altre, carla))
  expect_s3_class(conti, "data.frame")
  expect_true(is.na(conti[["firstvisit"]]))
  expect_equal(report_server_access(conti, carla)[["stato"]], "mai_entrata")
  expect_s3_class(report_accounts_frame(vuote, carla), "data.frame")
})


test_that("no one asked, nothing to miss", {
  # eval
  conti <- report_accounts_frame(list(accounts = list()), character())

  # test
  expect_s3_class(conti, "data.frame")
  expect_equal(nrow(conti), 0L)
})


test_that("revisione 3: il nome si trova senza guardare le maiuscole", {
  # eval
  conti <- report_accounts_frame(
    list(accounts = list(voce_carla)), "Carla.Inventata@ubep.unipd.it"
  )
  accesso <- report_server_access(conti, " Carla.Inventata@UBEP.unipd.it ")

  # test
  expect_s3_class(conti, "data.frame")
  expect_equal(conti[["username"]], carla)
  expect_equal(accesso[["stato"]], "entrata")
})


test_that("the frame is found whatever capitals the server answers in", {
  # eval
  conti <- report_accounts_frame(
    list(accounts = list(voce("Carla.Inventata@ubep.unipd.it "))), carla
  )

  # test
  expect_equal(conti[["username"]], carla)
})


# --- the access --------------------------------------------------------------

test_that("mai entrata: riga assente o primo accesso nullo", {
  # eval
  conti_vuoti <- report_accounts_frame(list(accounts = list()), character())
  altra <- conti_di(voce(dario))
  assente <- conti_di(voce(
    carla, exists = FALSE, firstvisit = NULL, lastlogin = NULL,
    lastactivity = NULL
  ))
  conti_senza_primo <- conti_di(voce(carla, firstvisit = NULL))

  # test
  expect_equal(
    report_server_access(conti_vuoti, carla)[["stato"]], "mai_entrata"
  )
  expect_equal(report_server_access(altra, carla)[["stato"]], "mai_entrata")
  expect_equal(report_server_access(assente, carla)[["stato"]], "mai_entrata")
  expect_equal(
    report_server_access(conti_senza_primo, carla)[["stato"]], "mai_entrata"
  )
  expect_true(is.na(report_server_access(assente, carla)[["ultimo"]]))
  expect_true(
    is.na(report_server_access(conti_senza_primo, carla)[["ultimo"]])
  )
  expect_equal(report_server_access(altra, dario)[["stato"]], "entrata")
})


test_that("a missing name asks nobody in", {
  # eval
  conti <- conti_di(voce_carla)

  # test
  expect_equal(report_server_access(conti, NA)[["stato"]], "mai_entrata")
  expect_equal(report_server_access(conti, "")[["stato"]], "mai_entrata")
})


test_that("l'ultimo accesso e' il piu' recente fra login e attivita'", {
  # eval
  conti <- conti_di(voce_carla)
  conti_login <- conti_di(voce(carla, lastlogin = "2026-11-07T09:30:00Z"))
  conti_solo_primo <- conti_di(
    voce(carla, lastlogin = NULL, lastactivity = NULL)
  )
  conti_solo_login <- conti_di(voce(carla, lastactivity = NULL))
  ultimo <- function(x) {
    format(report_server_access(x, carla)[["ultimo"]], tz = "UTC")
  }

  # test
  # lastlogin 2026-11-03T08:00:00Z, lastactivity 2026-11-05T10:00:00Z
  expect_equal(ultimo(conti), "2026-11-05 10:00:00")
  expect_equal(ultimo(conti_login), "2026-11-07 09:30:00")
  expect_equal(ultimo(conti_solo_login), "2026-11-03 08:00:00")
  # both NA, firstvisit 2026-10-20T07:15:00Z
  expect_equal(ultimo(conti_solo_primo), "2026-10-20 07:15:00")
  expect_s3_class(report_server_access(conti, carla)[["ultimo"]], "POSIXct")
})


# --- the servers -------------------------------------------------------------

test_that("ogni server non letto dice perche', e gli altri si leggono", {
  # eval
  chiamati <- character()
  local_mocked_bindings(
    module_accounts = function(server, secret, usernames, ...) {
      chiamati <<- c(chiamati, server)
      if (server == "edc14.example.org") {
        return(list(
          ok = FALSE,
          errors = c("TRASPORTO_CONTRATTO_DISALLINEATO", "INTERNO"),
          payload = NULL, gate = NA_character_
        ))
      }
      risposta(lapply(usernames, voce))
    }
  )
  letture <- report_server_reads(
    list(edc10 = carla, edc12 = carla, edc14 = carla, edc16 = carla),
    hosts = c(
      edc10 = "edc10.example.org", edc12 = "edc12.example.org",
      edc14 = "edc14.example.org"
    ),
    secrets = c(edc10 = "s3cret", edc12 = NA, edc14 = "s3cret")
  )

  # test
  expect_named(letture, c("edc10", "edc12", "edc14", "edc16"))
  expect_true(letture[["edc10"]][["letto"]])
  expect_equal(letture[["edc10"]][["conti"]][["username"]], carla)
  expect_equal(
    letture[["edc12"]][["motivo"]], "TRASPORTO_SEGRETO_NON_LEGGIBILE"
  )
  expect_equal(
    letture[["edc14"]][["motivo"]], "TRASPORTO_CONTRATTO_DISALLINEATO"
  )
  expect_equal(
    letture[["edc16"]][["motivo"]], "TRASPORTO_ISTANZA_SENZA_MODULO"
  )
  expect_false(letture[["edc16"]][["letto"]])
  # A server without a host or a secret is never called.
  expect_equal(chiamati, c("edc10.example.org", "edc14.example.org"))
})


test_that("a secret that is missing or empty is not readable", {
  # eval
  local_mocked_bindings(
    module_accounts = function(server, secret, usernames, ...) {
      risposta(lapply(usernames, voce))
    }
  )
  letture <- report_server_reads(
    list(edc10 = carla, edc12 = carla),
    c(edc10 = "edc10.example.org", edc12 = "edc12.example.org"),
    c(edc10 = "s3cret")
  )
  vuoto <- report_server_reads(
    list(edc10 = carla), c(edc10 = "edc10.example.org"), c(edc10 = "")
  )

  # test
  expect_true(letture[["edc10"]][["letto"]])
  expect_equal(
    letture[["edc12"]][["motivo"]], "TRASPORTO_SEGRETO_NON_LEGGIBILE"
  )
  expect_equal(
    vuoto[["edc10"]][["motivo"]], "TRASPORTO_SEGRETO_NON_LEGGIBILE"
  )
})


test_that("blank and missing names are not asked", {
  # eval
  chiesti <- NULL
  local_mocked_bindings(
    module_accounts = function(server, secret, usernames, ...) {
      chiesti <<- usernames
      risposta(lapply(usernames, voce))
    }
  )
  letture <- report_server_reads(
    list(edc10 = c(carla, NA, "", "  ", dario)),
    c(edc10 = "edc10.example.org"), c(edc10 = "s3cret")
  )

  # test
  expect_equal(chiesti, c(carla, dario))
  expect_true(letture[["edc10"]][["letto"]])
})


test_that("a server asked nobody about is still a reading", {
  # eval
  local_mocked_bindings(
    module_accounts = function(server, secret, usernames, ...) {
      risposta(list())
    }
  )
  letture <- report_server_reads(
    list(edc10 = character()), c(edc10 = "edc10.example.org"),
    c(edc10 = "s3cret")
  )

  # test
  expect_true(letture[["edc10"]][["letto"]])
  expect_equal(nrow(letture[["edc10"]][["conti"]]), 0L)
})


test_that("a failure with no code is still not a reading", {
  # eval
  local_mocked_bindings(
    module_accounts = function(server, secret, usernames, ...) {
      list(ok = FALSE, errors = character(), payload = NULL, gate = NA)
    }
  )
  letture <- report_server_reads(
    list(edc10 = carla), c(edc10 = "edc10.example.org"), c(edc10 = "s3cret")
  )

  # test
  expect_false(letture[["edc10"]][["letto"]])
  expect_equal(letture[["edc10"]][["motivo"]], "INTERNO")
})


test_that("a server whose call raises is not read, and the others are", {
  # eval
  local_mocked_bindings(
    module_accounts = function(server, secret, usernames, ...) {
      if (server == "edc14.example.org") {
        stop("values must be length 1")
      }
      risposta(lapply(usernames, voce))
    }
  )
  letture <- report_server_reads(
    list(edc10 = carla, edc14 = carla, edc16 = carla),
    c(
      edc10 = "edc10.example.org", edc14 = "edc14.example.org",
      edc16 = "edc16.example.org"
    ),
    c(edc10 = "s3cret", edc14 = "s3cret", edc16 = "s3cret")
  )

  # test
  expect_false(letture[["edc14"]][["letto"]])
  expect_equal(letture[["edc14"]][["motivo"]], "INTERNO")
  expect_true(letture[["edc10"]][["letto"]])
  expect_true(letture[["edc16"]][["letto"]])
})


test_that("a contract 4 answer with a malformed errors field is not read", {
  # eval
  corpi <- c(
    '{"contract_version": 4, "errors": [{"message": "x"}]}',
    '{"contract_version": 4, "errors": "x"}'
  )
  for (corpo in corpi) {
    local_mocked_bindings(
      module_accounts = function(server, secret, usernames, ...) {
        parse_module_response(corpo, 200L, accepted = 4L)
      }
    )
    letture <- report_server_reads(
      list(edc10 = carla), c(edc10 = "edc10.example.org"),
      c(edc10 = "s3cret")
    )

    # test
    expect_false(letture[["edc10"]][["letto"]])
    expect_equal(letture[["edc10"]][["motivo"]], "INTERNO")
  }
})
