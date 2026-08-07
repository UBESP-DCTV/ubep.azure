test_that("a reachable instance reports version, fingerprint and counts", {
  state <- list(
    ok = TRUE, errors = character(), gate = "collaudata",
    payload = list(
      redcap_version = "17.3.3", redcap_major = 17L,
      version_gate = "collaudata", surface_fingerprint = "16faf46d5ab1",
      allowlist_fingerprint = "aabbccddeeff",
      results = list(
        list(username = "a", project_id = 16L, expiration = "2020-01-01"),
        list(username = "b", project_id = 16L, expiration = NULL),
        list(username = "c", project_id = 18L, expiration = "2099-01-01")
      )
    )
  )

  row <- observe_instance("edcNN", state, today = as.Date("2026-08-07"))

  expect_true(row[["raggiungibile"]])
  expect_equal(row[["redcap_version"]], "17.3.3")
  expect_equal(row[["redcap_major"]], 17L)
  expect_equal(row[["surface_fingerprint"]], "16faf46d5ab1")
  expect_equal(row[["allowlist_fingerprint"]], "aabbccddeeff")
  expect_equal(row[["coppie"]], 3L)
  expect_equal(row[["scadute"]], 1L)
  expect_equal(row[["senza_scadenza"]], 1L)
})


test_that("the expiration boundary is inclusive, as REDCap applies it", {
  # REDCap denies when `expiration <= TODAY`, so a pair expiring *today* is
  # already refused and must be counted. The date is injected rather than read
  # from the clock: a literal `today` in a fixture turns green into red on a
  # calendar date, for a reason that has nothing to do with the code.
  state <- list(
    ok = TRUE, errors = character(), gate = "collaudata",
    payload = list(
      redcap_version = "17.3.3", redcap_major = 17L,
      surface_fingerprint = "16faf46d5ab1",
      results = list(
        list(username = "a", project_id = 16L, expiration = "2026-08-07"),
        list(username = "b", project_id = 16L, expiration = "2026-08-08")
      )
    )
  )

  row <- observe_instance("edcNN", state, today = as.Date("2026-08-07"))

  expect_equal(row[["scadute"]], 1L)
})


test_that("an unreachable instance becomes a row, not an exception", {
  state <- list(
    ok = FALSE, errors = "TRASPORTO_MODULO_ASSENTE",
    payload = NULL, gate = NA_character_
  )

  row <- observe_instance("edcNN", state, today = as.Date("2026-08-07"))

  expect_false(row[["raggiungibile"]])
  expect_equal(row[["errori"]], "TRASPORTO_MODULO_ASSENTE")
  expect_true(is.na(row[["redcap_major"]]))
  expect_true(is.na(row[["coppie"]]))
})


test_that("a module that predates the allowlist fingerprint stays readable", {
  # Instances still on an older release answer without the field. Refusing
  # them would blind the audit on exactly the instances a rollout is behind on.
  state <- list(
    ok = TRUE, errors = character(), gate = "collaudata",
    payload = list(
      redcap_version = "17.3.3", redcap_major = 17L,
      surface_fingerprint = "16faf46d5ab1",
      results = list()
    )
  )

  row <- observe_instance("edcNN", state, today = as.Date("2026-08-07"))

  expect_true(row[["raggiungibile"]])
  expect_true(is.na(row[["allowlist_fingerprint"]]))
  expect_equal(row[["coppie"]], 0L)
})


test_that("the run record counts successful reads, not attempted instances", {
  observations <- rbind(
    observe_instance("a", list(
      ok = TRUE, gate = "collaudata",
      payload = list(
        redcap_major = 17L, redcap_version = "17.3.3",
        surface_fingerprint = "16faf46d5ab1", results = list()
      )
    )),
    observe_instance("b", list(
      ok = FALSE, errors = "TRASPORTO_MODULO_ASSENTE", payload = NULL
    ))
  )

  record <- run_record(observations, at = "2026-08-07 03:00")

  expect_equal(record[["istanze"]], 2L)
  expect_equal(record[["letture_riuscite"]], 1L)
  expect_equal(record[["irraggiungibili"]], 1L)
  expect_equal(record[["major_in_flotta"]], 17L)
  expect_true(record[["major_singleton"]])
})


test_that("a run that read nothing reports zero reads", {
  # The alarm on absence fires on the lack of a record with at least one
  # successful read. If the record said only "the process started", a job that
  # started, failed against every instance and exited would satisfy it — a
  # detector the fault can meet.
  observations <- observe_instance("a", list(
    ok = FALSE, errors = "TRASPORTO_MODULO_ASSENTE", payload = NULL
  ))

  record <- run_record(observations, at = "2026-08-07 03:00")

  expect_equal(record[["letture_riuscite"]], 0L)
  expect_equal(length(record[["major_in_flotta"]]), 0L)
  expect_false(record[["major_singleton"]])
})


test_that("two majors in the fleet are not a singleton", {
  # The condition the two clauses on retiring compatibility branches rest on.
  observations <- rbind(
    observe_instance("a", list(ok = TRUE, gate = "collaudata", payload = list(
      redcap_major = 17L, redcap_version = "17.3.3",
      surface_fingerprint = "16faf46d5ab1", results = list()
    ))),
    observe_instance("b", list(ok = TRUE, gate = "collaudata", payload = list(
      redcap_major = 15L, redcap_version = "15.8.4",
      surface_fingerprint = "ffffffffffff", results = list()
    )))
  )

  record <- run_record(observations, at = "2026-08-07 03:00")

  expect_equal(record[["major_in_flotta"]], c(15L, 17L))
  expect_false(record[["major_singleton"]])
  expect_equal(length(record[["impronte_superficie"]]), 2L)
})


test_that("list fields serialize as arrays even when holding one item", {
  # The length-one array trap, on the emission side this time. `auto_unbox`
  # turns a one-element vector into a scalar, so a fleet with a single instance
  # would emit a string where the alert query expects an array — and the fault
  # stays hidden until the day only one instance answers.
  observations <- observe_instance("a", list(
    ok = TRUE, gate = "collaudata",
    payload = list(
      redcap_major = 17L, redcap_version = "17.3.3",
      surface_fingerprint = "16faf46d5ab1", results = list()
    )
  ))

  json <- run_record_json(run_record(observations, at = "2026-08-07 03:00"))
  back <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  expect_true(is.list(back[["impronte_superficie"]]))
  expect_length(back[["impronte_superficie"]], 1L)
  expect_true(is.list(back[["major_in_flotta"]]))

  # scalars must stay scalars: a run with one reading is not a list of one
  expect_true(is.numeric(back[["letture_riuscite"]]))
  expect_true(is.logical(back[["major_singleton"]]))
})


test_that("an empty list-valued field stays an empty array, not null", {
  observations <- observe_instance("a", list(
    ok = FALSE, errors = "TRASPORTO_MODULO_ASSENTE", payload = NULL
  ))

  json <- run_record_json(run_record(observations, at = "2026-08-07 03:00"))
  back <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  expect_true(is.list(back[["major_in_flotta"]]))
  expect_length(back[["major_in_flotta"]], 0L)
})
