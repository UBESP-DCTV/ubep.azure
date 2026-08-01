test_that("a known fingerprint keeps the gate the module declared", {
  # eval
  registry <- data.frame(
    redcap_major = 17L,
    fingerprint = "abc123def456",
    stringsAsFactors = FALSE
  )
  payload <- list(
    redcap_major = 17L,
    surface_fingerprint = "abc123def456",
    version_gate = "collaudata"
  )

  # test
  expect_equal(check_fingerprint(payload, registry), "collaudata")
})


test_that("an unknown fingerprint downgrades a tested instance", {
  # eval
  registry <- data.frame(
    redcap_major = 17L,
    fingerprint = "abc123def456",
    stringsAsFactors = FALSE
  )
  payload <- list(
    redcap_major = 17L,
    surface_fingerprint = "999999999999",
    version_gate = "collaudata"
  )

  # test
  # Same major, changed surface: exactly what comparing versions cannot see.
  expect_equal(check_fingerprint(payload, registry), "non_collaudata")
})


test_that("the fingerprint never upgrades a gate", {
  # eval
  registry <- data.frame(
    redcap_major = c(17L, 18L),
    fingerprint = c("abc123def456", "aaaabbbbcccc"),
    stringsAsFactors = FALSE
  )
  below <- check_fingerprint(
    list(
      redcap_major = 15L, surface_fingerprint = "abc123def456",
      version_gate = "sotto_minimo"
    ),
    registry
  )
  untested <- check_fingerprint(
    list(
      redcap_major = 18L, surface_fingerprint = "aaaabbbbcccc",
      version_gate = "non_collaudata"
    ),
    registry
  )

  # test
  expect_equal(below, "sotto_minimo")
  expect_equal(untested, "non_collaudata")
})


test_that("an empty registry downgrades everything", {
  # eval
  registry <- data.frame(
    redcap_major = integer(), fingerprint = character(),
    stringsAsFactors = FALSE
  )
  payload <- list(
    redcap_major = 17L, surface_fingerprint = "abc123def456",
    version_gate = "collaudata"
  )

  # test
  expect_equal(check_fingerprint(payload, registry), "non_collaudata")
})


test_that("a fingerprint known for another major does not count", {
  # eval
  registry <- data.frame(
    redcap_major = 18L, fingerprint = "abc123def456",
    stringsAsFactors = FALSE
  )
  payload <- list(
    redcap_major = 17L, surface_fingerprint = "abc123def456",
    version_gate = "collaudata"
  )

  # test
  expect_equal(check_fingerprint(payload, registry), "non_collaudata")
})


test_that("the shipped registry carries the surface measured on the fleet", {
  # eval
  registry <- tested_fingerprints()

  # test
  # The registry is the record of what has actually been tested, so an entry
  # appearing without a measurement behind it is the failure mode to guard.
  expect_true(nrow(registry) >= 1L)
  expect_true(all(grepl("^[0-9a-f]{12}$", registry[["fingerprint"]])))
  expect_true(17L %in% registry[["redcap_major"]])
})


test_that("the shipped registry accepts the captured response", {
  # eval
  payload <- jsonlite::fromJSON(
    testthat::test_path("fixtures", "state-response.json"),
    simplifyVector = FALSE
  )

  # test
  # Closes the loop between the module and the registry: the fingerprint the
  # module computes on a tested instance has to be one the client recognises,
  # or every instance would silently sit in `non_collaudata`.
  expect_equal(check_fingerprint(payload), "collaudata")
})
