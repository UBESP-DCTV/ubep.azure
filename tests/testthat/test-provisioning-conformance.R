test_that("the cases cover every governed field", {
  # eval
  cases <- conformance_cases()
  asserted <- unique(unlist(lapply(cases, function(x) names(x[["assert"]]))))
  case_names <- vapply(cases, function(x) x[["name"]], character(1))

  # test
  # A field the cases do not assert is a field the gate is blind to, so the
  # coverage is checked rather than trusted.
  expect_setequal(asserted, c("role_name", "dag_name", "expiration"))
  expect_true(length(cases) >= 4L)
  expect_true(all(vapply(cases, function(x) nzchar(x[["name"]]), logical(1))))
  # Case names double as steps() keys in run_conformance_check(): a
  # duplicate would silently overwrite one step and shrink the vector
  # all() runs over, instead of raising or being visible in the result.
  expect_equal(length(unique(case_names)), length(case_names))
})


test_that("a case that clears a field is asserted as an empty string", {
  # eval
  cleared <- request_for(
    "someone", 7L,
    list(role_name = "data entry", dag_name = NULL, expiration = "2027-06-30")
  )

  # test
  # utils::modifyList() drops a NULL-valued key instead of setting it, which
  # is exactly the omission the writer's contract forbids: an absence must
  # be asserted, never left out. request_for() is the one place that
  # translates a case's NULL into the empty string that goes on the wire.
  expect_true("dag_name" %in% names(cleared))
  expect_equal(cleared[["dag_name"]], "")
  expect_equal(cleared[["role_name"]], "data entry")
})


test_that("every case survives request building with all fields present", {
  # eval
  cases <- conformance_cases()
  requests <- lapply(
    cases, function(case) request_for("someone", 7L, case[["assert"]])
  )

  # test
  # A modifyList()-style regression would drop exactly the field a case
  # clears; checking every case's built request, not just one, is what
  # would have caught it regardless of which field a future case clears.
  governed <- c("role_name", "dag_name", "expiration")
  expect_true(all(vapply(
    requests, function(request) all(governed %in% names(request)), logical(1)
  )))
})


test_that("compare_readback reports the field that differs", {
  # eval
  expected <- list(role_name = "data entry", dag_name = "centro-01",
                   expiration = "2027-01-01")
  identical_read <- compare_readback(expected, expected)
  lost_dag <- compare_readback(
    expected,
    utils::modifyList(expected, list(dag_name = NULL))
  )

  # test
  expect_true(identical_read[["conforms"]])
  expect_equal(identical_read[["differences"]], character())
  expect_false(lost_dag[["conforms"]])
  expect_true("dag_name" %in% lost_dag[["differences"]])
})


test_that("compare_readback does not tolerate a missing row", {
  # eval
  expected <- list(role_name = "data entry", dag_name = NULL,
                   expiration = NULL)
  absent <- compare_readback(expected, NULL)

  # test
  # An assertion that produced no row at all is the loudest possible failure,
  # and it must not read as "nothing to compare, therefore fine".
  expect_false(absent[["conforms"]])
  expect_true("role_name" %in% absent[["differences"]])
})


test_that("a dry run that changed anything fails the check", {
  # eval
  before <- list(role_name = "read only", dag_name = NULL,
                 expiration = NULL)
  after_dry_run <- list(role_name = "data entry", dag_name = NULL,
                        expiration = NULL)
  verdict <- compare_readback(before, after_dry_run)

  # test
  # Step two of the run: the structural guarantee behind dry_run, measured
  # rather than asserted. If the simulation wrote, this is what sees it.
  expect_false(verdict[["conforms"]])
  expect_true("role_name" %in% verdict[["differences"]])
})


test_that("record_conformance writes the date on the matching major only", {
  # eval
  path <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(
    data.frame(
      redcap_major = c(17L, 18L),
      fingerprint = c("abc123def456", "aaaabbbbcccc"),
      conformance_passed_on = NA_character_,
      stringsAsFactors = FALSE
    ),
    path
  )

  # test
  # A column that is entirely date-like strings is read back by readr as
  # Date, not character — the same reason conformance_passed() coerces with
  # as.character() before comparing; matching that here rather than
  # asserting against a Date keeps this test about record_conformance(),
  # not about readr's type guessing.
  record_conformance(path, major = 18L, on = as.Date("2026-08-01"))
  written <- readr::read_csv(path, show_col_types = FALSE)
  passed_on <- as.character(written[["conformance_passed_on"]])
  expect_equal(passed_on[written[["redcap_major"]] == 18L], "2026-08-01")
  expect_true(is.na(passed_on[written[["redcap_major"]] == 17L]))
})


test_that("record_conformance refuses to write silently for an unknown major", {
  # eval
  path <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(
    data.frame(
      redcap_major = 17L, fingerprint = "abc123def456",
      conformance_passed_on = NA_character_, stringsAsFactors = FALSE
    ),
    path
  )

  # test
  # Assigning into an all-FALSE index is a silent no-op in R: without this
  # guard, a run against a major the registry has never heard of — the
  # exact case this mechanism exists for — would report success and write
  # nothing, indistinguishable from a run that actually recorded a date.
  expect_error(record_conformance(path, major = 21L, on = Sys.Date()))
})
