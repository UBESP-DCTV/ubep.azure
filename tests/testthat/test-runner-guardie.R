test_that("the runner names neither the diff nor the writes", {
  # `dev/` is excluded from the built package, so under `R CMD check` the file
  # is not there and this skips. That is a real limit and worth naming: the
  # guard bites in the source tree, which is where the edit that would break it
  # happens, and not in CI. Whoever adds the write path runs `devtools::test()`
  # before committing; that is the gate this relies on.
  runner <- testthat::test_path("..", "..", "dev", "runner-osservatore.R")
  skip_if_not(file.exists(runner), "dev/ is not in the built package")

  lines <- readLines(runner, warn = FALSE)

  forbidden <- c("provisioning_diff", "module_apply", "module_revoke")
  found <- forbidden[vapply(
    forbidden,
    function(symbol) any(grepl(symbol, lines, fixed = TRUE)),
    logical(1)
  )]

  expect_equal(
    found, character(),
    info = paste(
      "The v1 observes and does not compare. With no register every real pair",
      "would be classified as revoked, so the danger is not the write call but",
      "the comparison that feeds it. If you are deliberately adding the write",
      "path, change this test in the same commit — not afterwards."
    )
  )
})


test_that("the guard is coarse on purpose and catches a mention in a comment", {
  # A false red here costs nothing; a false green costs a mass revocation. The
  # asymmetry is the reason the check is a plain text search rather than a
  # parse of the call graph.
  lines <- c("# nothing here", "x <- 1")
  expect_false(any(grepl("provisioning_diff", lines, fixed = TRUE)))

  lines <- c("# we must never call provisioning_diff() here", "x <- 1")
  expect_true(any(grepl("provisioning_diff", lines, fixed = TRUE)))
})
