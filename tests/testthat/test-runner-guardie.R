test_that("the runner names neither the diff nor the writes", {
  # `dev/` is excluded from the built package, so under `R CMD check` the file
  # is not there and this skips. That is a real limit and worth naming: the
  # guard bites in the source tree, which is where the edit that would break it
  # happens, and not in CI. Whoever adds the write path runs `devtools::test()`
  # before committing; that is the gate this relies on.
  runners <- list.files(
    testthat::test_path("..", "..", "dev"),
    pattern = "^runner-.*[.]R$", full.names = TRUE
  )
  skip_if(length(runners) == 0L, "dev/ is not in the built package")
  lines <- unlist(lapply(runners, readLines, warn = FALSE))

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


test_that("nothing in the package writes on an instance without naming the gate", { # nolint: line_length_linter.
  # eval
  # This one bites under `R CMD check` too, unlike the two guards above: it
  # reads the installed function bodies instead of the source tree, so `dev/`
  # not shipping cannot make it skip.
  namespace <- asNamespace("ubep.azure")
  functions <- Filter(
    function(name) is.function(get(name, envir = namespace)),
    ls(namespace, all.names = TRUE)
  )

  # run_conformance_check is itself a write path -- it calls both
  # module_apply() and module_revoke() with dry_run = FALSE -- so it belongs
  # in `writes`, not only in `exempt`: a new function whose body calls
  # run_conformance_check() writes on an instance too, and without its name
  # here nothing would stop a caller from routing around the two write
  # primitives through this one, with no allowlist edit and nothing for a
  # reviewer to catch in a diff.
  writes <- c("module_apply", "module_revoke", "run_conformance_check")
  # run_conformance_check predates this gate and is the one deliberate second
  # write path: a calibration tool an operator runs by hand against a
  # dedicated conformance project and a dedicated test account to certify a
  # module version before its ceiling can advance -- never against
  # register-derived data, never unattended. It carries no requester and no
  # register row to gate on, so the rule this guard enforces ("could the
  # requester have granted this by hand") does not apply to it. Named here, in
  # the same commit that wires the gate, exactly as this test's own message
  # asks of a deliberate second write path -- and it stays out of `offending`
  # below because it is also in `exempt`, so it is never scanned against
  # itself.
  exempt <- c(writes, "run_conformance_check")
  offending <- Filter(function(name) {
    body <- paste(deparse(body(get(name, envir = namespace))), collapse = " ")
    calls_write <- any(vapply(
      writes, function(symbol) grepl(symbol, body, fixed = TRUE), logical(1)
    ))
    calls_write && !grepl("scope_errors", body, fixed = TRUE)
  }, setdiff(functions, exempt))

  # test
  expect_equal(
    offending, character(),
    info = paste(
      "A function that can write on an instance must name the scope gate,",
      "and that includes a function that writes only by calling",
      "run_conformance_check() -- exempt from being scanned itself (see the",
      "docblock above), but not from requiring the gate in whoever calls it.",
      "The rule the gate enforces is that the channel must not let anyone do",
      "something they could not already do by hand, and a write path that",
      "never asks is a channel that grants what nobody could have granted.",
      "The check is a coarse text search on purpose: a false red costs a",
      "minute, a false green costs an out-of-scope grant applied while nobody",
      "was looking. If you are deliberately adding a second write path, change",
      "this test in the same commit — not afterwards."
    )
  )
  # `writes` now names run_conformance_check itself, so `setdiff(exempt,
  # writes)` is empty by construction and cannot tell a stale exemption from
  # a correct one; the base primitives are the only fixed point to measure
  # `exempt` against. If this ever reports more than run_conformance_check,
  # either a second gate-free tool was exempted deliberately (name it above,
  # in the same commit) or the exemption drifted.
  expect_equal(
    setdiff(exempt, c("module_apply", "module_revoke")),
    "run_conformance_check"
  )
})


test_that("the guard on the package is coarse enough to catch a rename", {
  # eval
  # Same shape as the guard above, run against two hand-written bodies so the
  # test that guards the guard cannot pass by finding nothing.
  named <- function() module_apply(server, secret, requests)
  gated <- function() {
    errors <- scope_errors(register, rights)
    module_apply(server, secret, requests)
  }
  scan <- function(f) {
    body <- paste(deparse(body(f)), collapse = " ")
    grepl("module_apply", body, fixed = TRUE) &&
      !grepl("scope_errors", body, fixed = TRUE)
  }

  # test
  expect_true(scan(named))
  expect_false(scan(gated))
})
