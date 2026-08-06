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


test_that("a missing surface fingerprint downgrades instead of raising", {
  # eval
  registry <- data.frame(
    redcap_major = 17L, fingerprint = "abc123def456",
    stringsAsFactors = FALSE
  )
  payload <- list(redcap_major = 17L, version_gate = "collaudata")

  # test
  # payload[["surface_fingerprint"]] is NULL here, and NULL %in% known has
  # length zero: unguarded, the if() around it raises "argument is of
  # length zero" instead of answering. A module that has not computed the
  # fingerprint yet is not an error, it is a version waiting to be tested --
  # the same treatment an unrecognized fingerprint already gets below.
  expect_equal(check_fingerprint(payload, registry), "non_collaudata")
})


test_that("a fingerprint sent as a one-element array downgrades", {
  # eval
  registry <- data.frame(
    redcap_major = 17L, fingerprint = "abc123def456",
    stringsAsFactors = FALSE
  )
  payload <- list(
    redcap_major = 17L, surface_fingerprint = list("abc123def456"),
    version_gate = "collaudata"
  )

  # test
  # jsonlite::fromJSON(simplifyVector = FALSE) turns a JSON array into an R
  # list, never a character scalar, even a one-element one. Without a shape
  # check, %in% would still evaluate this list against the known character
  # vector rather than being rejected, and a payload that sent
  # `"surface_fingerprint": ["abc123def456"]` where a scalar belongs would
  # not be told apart from one that sent the scalar itself.
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
  # module computes on a tested instance has to be one the client recognizes,
  # or every instance would silently sit in `non_collaudata`.
  expect_equal(check_fingerprint(payload), "collaudata")
})


test_that("the shipped registry declares a conformance column", {
  # eval
  registry <- tested_fingerprints()

  # test
  expect_true("conformance_passed_on" %in% names(registry))
})


test_that("a recorded date counts as conformance", {
  # eval
  registry <- data.frame(
    redcap_major = c(17L, 18L),
    fingerprint = c("abc123def456", "aaaabbbbcccc"),
    conformance_passed_on = c("2026-09-01", NA),
    stringsAsFactors = FALSE
  )

  # test
  expect_true(conformance_passed(17L, registry))
  expect_false(conformance_passed(18L, registry))
  expect_false(conformance_passed(15L, registry))
})


test_that("the fingerprint check ignores the conformance column", {
  # eval
  registry <- data.frame(
    redcap_major = 17L,
    fingerprint = "abc123def456",
    conformance_passed_on = NA_character_,
    stringsAsFactors = FALSE
  )
  payload <- list(
    redcap_major = 17L, surface_fingerprint = "abc123def456",
    version_gate = "collaudata"
  )

  # test
  # The two answer different questions: the fingerprint says whether the
  # surface is the one we tested, conformance says whether writing does what
  # we mean. Conflating them would make an untested surface pass on an old
  # conformance.
  expect_equal(check_fingerprint(payload, registry), "collaudata")
})


test_that("the test project brake must go once conformance is earned", {
  # eval
  # system.file() resolves under devtools::load_all() and inside the
  # installed copy R CMD check runs tests against; a relative path such as
  # "../../inst/..." only works under devtools::test().
  manifest <- jsonlite::fromJSON(
    system.file("redcap-module", "config.json", package = "ubep.azure")
  )
  keys <- manifest[["system-settings"]][["key"]]
  earned <- conformance_passed(17L)

  # test
  # The trigger of the phase two restraint, made mechanical. This turns red
  # the day conformance is recorded for the floor major while the module
  # still declares the brake — which is exactly when the brake should come
  # out.
  if (earned) {
    expect_false("test-project-ids" %in% keys)
  } else {
    expect_true("test-project-ids" %in% keys)
  }
})


test_that("only a recorded conformance certifies a surface", {
  # eval
  registry <- data.frame(
    redcap_major = c(17L, 17L, 18L),
    fingerprint = c("misurata", "certificata", "altra"),
    conformance_passed_on = c(NA, "2026-08-05", NA),
    stringsAsFactors = FALSE
  )

  # test
  # The two columns answer two questions. `fingerprint` says the surface was
  # measured, which is what lets a conformance run write on it in the first
  # place; the date says writing was verified there. Declaring the measured
  # ones from the ordinary caller would let a row added after a bare `state`
  # reopen writes on a surface nobody ran conformance against.
  expect_equal(certified_fingerprints(registry), "certificata")
})


test_that("a registry with no conformance certifies nothing", {
  # eval
  registry <- data.frame(
    redcap_major = 17L,
    fingerprint = "misurata",
    conformance_passed_on = NA_character_,
    stringsAsFactors = FALSE
  )

  # test
  expect_length(certified_fingerprints(registry), 0L)
  expect_type(certified_fingerprints(registry), "character")
})


test_that("a dated row with no fingerprint certifies nothing", {
  # eval
  # Not reachable through tested_fingerprints(), which already drops
  # empty-fingerprint rows -- but certified_fingerprints() takes an arbitrary
  # registry, and a raw one is exactly what a conformance run (task 8) and
  # its tests will pass.
  registry <- data.frame(
    redcap_major = c(17L, 17L),
    fingerprint = c(NA_character_, ""),
    conformance_passed_on = c("2026-08-05", "2026-08-05"),
    stringsAsFactors = FALSE
  )

  # test
  expect_length(certified_fingerprints(registry), 0L)
})
