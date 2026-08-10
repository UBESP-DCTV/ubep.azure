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


test_that("no dev script carries a resource name as a fallback value", {
  # Same limit as the guard above, and for the same reason: `dev/` is not in
  # the built package, so this skips under `R CMD check` and bites in the
  # source tree, which is where the edit that would break it happens.
  dev <- testthat::test_path("..", "..", "dev")
  skip_if_not(dir.exists(dev), "dev/ is not in the built package")

  # The rule is on the *shape* of the fallback, not on a list of forbidden
  # strings, and it has to be: a guard that named the values it forbids would
  # have to write them into this file, which sits in the same public
  # repository. So it asks the one question no value can answer wrongly — is
  # this fallback a path on the machine, or a name that identifies something
  # inside the subscription?
  #
  # It is also the lesson that cost the most on 2026-08-10, in the form that
  # survives: checking for classes rather than for examples. A hand-written
  # search for "the Key Vault, the workspace, the stream" enumerates the
  # values somebody already thought of, and the one nobody thought of is
  # exactly the one that gets through.
  offending <- as.character(unlist(lapply(
    list.files(dev, pattern = "[.]R$", full.names = TRUE),
    function(file) {
      # Lines are joined before matching, because a Sys.getenv() call may be
      # split across lines: a per-line search reads the split ones as having
      # no fallback at all, which is a false green on the only shape that
      # matters here.
      text <- paste(readLines(file, warn = FALSE), collapse = " ")
      calls <- regmatches(
        text, gregexpr("Sys[.]getenv\\([^)]*,[^)]*\\)", text)
      )[[1]]
      fallbacks <- sub('^.*,\\s*"([^"]*)".*$', "\\1", calls)
      bad <- calls[nzchar(fallbacks) & !startsWith(fallbacks, "/")]
      if (length(bad)) paste0(basename(file), ": ", bad) else NULL
    }
  )))

  expect_equal(
    offending, character(),
    info = paste(
      "A fallback that is not a path on the machine is a resource name, and a",
      "resource name written as a default is a resource name published: this",
      "repository is public, and a default is not less present in the file for",
      "being less visible. Read it from the environment of the unit instead,",
      "the way UBEP_DCE and UBEP_DCR already are. A fallback that really is a",
      "path starts with a slash, and this guard stays quiet."
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
