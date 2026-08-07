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
