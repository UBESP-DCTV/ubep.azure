# The floor below is a convention, and conventions rot silently, so it is
# written once here and read by both tests.
fixture_project_floor <- 900L


fixture_project_ids <- function(file) {
  # Lines are joined before matching, because a fixture may split the key from
  # its value across two lines: a per-line search reads a split one as carrying
  # no identifier at all, which is a false green on the only shape that
  # matters.
  text <- paste(readLines(file, warn = FALSE), collapse = " ")

  # One window covers the three syntaxes this repository writes the same thing
  # in — `project_id = 0L` in R, `'project_id' => 0` in PHP and
  # `"project_id": 0` in JSON — plus the comparison form,
  # `[["project_id"]], 0L`. Anchoring on the key and taking the first run of
  # digits after it is coarse on purpose: a false red costs a minute, a false
  # green costs the rule this guards.
  hits <- regmatches(text, gregexpr("project_id[^0-9]{0,8}[0-9]+", text))[[1]]

  # The key carries no digit of its own, and neither does the window, so what
  # is left after dropping the non-digits is the value and nothing else.
  as.integer(gsub("[^0-9]", "", hits))
}


test_that("no fixture carries a project identifier the fleet could own", {
  # `R/provisioning_conformance.R` states the rule this enforces: server,
  # secret, project and usernames come from the caller, and none of them may
  # appear in this repository.
  #
  # A guard that listed the forbidden identifiers would have to write them into
  # a file that sits in the same public repository, so it cannot ask "is this
  # one of the real ones?". It asks the question no real value can answer
  # wrongly instead: a fixture project lives in a reserved block above the
  # floor, well past the range the fleet has reached, so a real identifier
  # pasted into a fixture lands below it and this goes red. The day the fleet
  # itself reaches the floor, this test is where the block gets moved.
  module_tests <- system.file(
    "redcap-module", "tests",
    package = "ubep.azure"
  )
  # system.file() answers "" when it does not find the directory, and
  # list.files("") lists the working directory instead of nothing: without this
  # the guard would scan the wrong tree and stay green on an empty search.
  skip_if_not(
    nzchar(module_tests) && dir.exists(module_tests),
    "the packaged module is not there"
  )

  r_tests <- list.files(
    testthat::test_path("."),
    pattern = "^test-.*[.]R$", full.names = TRUE
  )
  # This file is excluded because it writes the key next to the digits of its
  # own window, and would otherwise match itself. The comparison is on the base
  # name and not on the path: test_path() and list.files() spell the same file
  # differently, and a setdiff() between the two forms excludes nothing while
  # looking like it does.
  sources <- c(
    r_tests[basename(r_tests) != "test-fixture-identificativi.R"],
    list.files(
      testthat::test_path("fixtures"),
      pattern = "[.]json$", full.names = TRUE
    ),
    list.files(module_tests, pattern = "[.]php$", full.names = TRUE)
  )

  ids <- lapply(sources, fixture_project_ids)

  # An assertion that read nothing is not a passing assertion. The way this
  # guard would go quiet is a rename of the field, not fixtures that got
  # cleaner, and a rename leaves no other trace.
  expect_gt(length(unlist(ids)), 50L)

  # The failure names the file and not the value: a guard that echoed the
  # identifier it found would publish it a second time, in the log of a public
  # CI run.
  below <- vapply(ids, function(x) any(x < fixture_project_floor), logical(1))
  expect_equal(
    basename(sources[below]), character(),
    info = paste(
      "A project identifier below", fixture_project_floor, "is a number the",
      "fleet could own, and this repository is public. Fixture projects live",
      "above that floor; pick the next free one."
    )
  )
})


test_that("the guard reads every shape an identifier is written in", {
  file <- withr::local_tempfile(lines = c(
    "  project_id = 0L,",
    "  'project_id' => 0,",
    '  "project_id": 0,',
    '  expect_equal(sent[["project_id"]], 0L)',
    "  project_id =",
    "    0L"
  ))

  # The last two lines are the split one, which is the shape a per-line search
  # misses and the reason the file is read joined. Five hits from six lines is
  # the point of the assertion: the count is what tells a silent miss from a
  # clean file.
  expect_equal(fixture_project_ids(file), rep(0L, 5L))
})


test_that("the guard goes red on a planted identifier", {
  clean <- withr::local_tempfile(lines = "  project_id = 9003L,")
  planted <- withr::local_tempfile(lines = "  project_id = 0L,")

  expect_false(any(fixture_project_ids(clean) < fixture_project_floor))
  expect_true(any(fixture_project_ids(planted) < fixture_project_floor))
})
