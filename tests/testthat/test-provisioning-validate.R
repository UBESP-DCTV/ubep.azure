test_that("compose_upn normalises names into an identity", {
  # eval
  plain <- compose_upn("Mario", "Rossi")
  accented <- compose_upn("Niccolò", "Dall'Acqua")
  spaced <- compose_upn("  Anna   Maria ", "De  Luca")

  # test
  expect_equal(plain, "mario.rossi@ubep.unipd.it")
  expect_equal(accented, "niccolo.dallacqua@ubep.unipd.it")
  expect_equal(spaced, "anna.maria.de.luca@ubep.unipd.it")
  expect_equal(
    compose_upn("Mario", "Rossi", domain = "example.org"),
    "mario.rossi@example.org"
  )
})


test_that("validate_request accepts a complete request", {
  # eval
  request <- list(
    username = "mario.rossi@ubep.unipd.it",
    contact_email = "mario.rossi@example.org",
    project_id = 27L,
    role_name = "data entry",
    dag_name = "centro-01",
    expiration = "2026-12-31"
  )

  # test
  expect_equal(validate_request(request), character())
})


test_that("validate_request reports data errors by code", {
  # eval
  no_upn <- validate_request(list(username = "not-an-upn", project_id = 27L))
  no_project <- validate_request(
    list(username = "mario.rossi@ubep.unipd.it", project_id = "abc")
  )
  past <- validate_request(list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 27L,
    expiration = "1999-01-01"
  ))
  malformed <- validate_request(list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 27L,
    expiration = "31/12/2026"
  ))

  # test
  expect_true("DATO_UTENTE_NON_VALIDO" %in% no_upn)
  expect_true("DATO_PROGETTO_INESISTENTE" %in% no_project)
  expect_true("DATO_SCADENZA_NON_VALIDA" %in% past)
  expect_true("DATO_SCADENZA_NON_VALIDA" %in% malformed)
})


test_that("an expiration of today is already refused", {
  # eval
  today <- validate_request(list(
    username = "mario.rossi@ubep.unipd.it",
    project_id = 27L,
    expiration = as.character(Sys.Date())
  ))

  # test
  # REDCap applies `expiration <= TODAY`, so the day written is already out:
  # accepting today would grant an access that never happens.
  expect_true("DATO_SCADENZA_NON_VALIDA" %in% today)
})


test_that("validate_request only ever returns data codes", {
  # eval
  every_error <- validate_request(list(
    username = "not-an-upn",
    project_id = "abc",
    expiration = "31/12/2026"
  ))

  # test
  # This layer is pure: it cannot know whether a server is reachable or which
  # version it runs, so a transport code from here would be a guess. The split
  # is by recipient, and everything decidable here belongs to the requester.
  expect_length(every_error, 3L)
  expect_true(all(grepl("^DATO_", every_error)))
})
