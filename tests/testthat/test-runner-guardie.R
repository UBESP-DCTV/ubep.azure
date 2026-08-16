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

  forbidden <- c(
    "provisioning_diff", "module_apply", "module_revoke", "credenziali"
  )
  found <- forbidden[vapply(
    forbidden,
    function(symbol) any(grepl(symbol, lines, fixed = TRUE)),
    logical(1)
  )]

  expect_equal(
    found, character(),
    info = paste(
      "The observer reads an instance's state whole, with no pairs named, so",
      "a comparison here would classify every real pair as revoked no matter",
      "how populated the register is -- the danger is not the write call but",
      "the comparison that feeds it. And a runner that names `credenziali`",
      "has a credential in a file whose whole job is to print things: what",
      "this one prints is collected by the timer and kept. Sub-project 5 will",
      "deliver them, and this is where that decision gets made again. If you",
      "are deliberately adding either, change this test in the same commit —",
      "not afterwards."
    )
  )
})


test_that("the measurement script only reads", {
  # Same limit as the runner guard above: `dev/` is not in the built package,
  # so this bites in the source tree rather than in CI.
  #
  # It is a guard of its own rather than a widening of the runner one, because
  # the runner pattern cannot simply be loosened to every dev script:
  # `riqualifica-superficie.R` calls run_conformance_check(), which writes on
  # an instance deliberately. The rule is per-script, so the exemption is too.
  script <- testthat::test_path("..", "..", "dev", "misura-canale.R")
  skip_if_not(file.exists(script), "dev/ is not in the built package")
  lines <- readLines(script, warn = FALSE)

  forbidden <- c(
    "provisioning_diff", "module_apply", "module_revoke",
    "run_conformance_check", "register_import"
  )
  found <- forbidden[vapply(
    forbidden,
    function(symbol) any(grepl(symbol, lines, fixed = TRUE)),
    logical(1)
  )]

  expect_equal(
    found, character(),
    info = paste(
      "This script exists to say what the served instances currently look",
      "like, and it is run precisely when somebody is unsure of that -- after",
      "an upgrade, after a module release, while diagnosing an alert. A",
      "measurement that could also change what it measures would make its own",
      "output unreadable: nobody could tell a value that was already there",
      "from one this run produced. If you are deliberately adding a write,",
      "it belongs in another script, not in this one."
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


# The write primitives, plus the one deliberate second write path. Read by both
# guards below rather than written out twice, because what must not drift is
# the list of what counts as a write: a fourth primitive added to one copy and
# not to the other would leave one of the two rules quietly scanning less than
# it claims to.
#
# run_conformance_check is itself a write path -- it calls both module_apply()
# and module_revoke() with dry_run = FALSE -- so it belongs here and not only
# among the exemptions: a new function whose body calls run_conformance_check()
# writes on an instance too, and without its name here nothing would stop a
# caller from routing around the two primitives through this one, with no
# allowlist edit and nothing for a reviewer to catch in a diff.
percorsi_di_scrittura <- function() {
  c("module_apply", "module_revoke", "run_conformance_check")
}


# Every function of the namespace that can write on an instance and does not
# name `cancello`. Coarse on purpose -- a plain text search over the deparsed
# body instead of a parse of the call graph -- because a false red costs a
# minute and a false green costs a grant applied while nobody was looking.
#
# The three write paths are never scanned against themselves.
# run_conformance_check predates both gates and is the deliberate exception: a
# calibration tool an operator runs by hand against a dedicated conformance
# project and a dedicated test account, to certify a module version before its
# ceiling can advance -- never against register-derived data, never unattended.
# It carries no requester and no register row, so neither rule has anything to
# ask of it.
chiama_senza_nominare <- function(chiamate, cancello) {
  namespace <- asNamespace("ubep.azure")
  functions <- Filter(
    function(name) is.function(get(name, envir = namespace)),
    ls(namespace, all.names = TRUE)
  )

  Filter(function(name) {
    body <- paste(deparse(body(get(name, envir = namespace))), collapse = " ")
    reaches <- any(vapply(
      chiamate, function(symbol) grepl(symbol, body, fixed = TRUE), logical(1)
    ))
    reaches && !grepl(cancello, body, fixed = TRUE)
  }, setdiff(functions, chiamate))
}


scrive_senza_nominare <- function(cancello) {
  chiama_senza_nominare(percorsi_di_scrittura(), cancello)
}


test_that("nothing in the package writes on an instance without naming the gate", { # nolint: line_length_linter.
  # eval
  # This one bites under `R CMD check` too, unlike the two guards above: it
  # reads the installed function bodies instead of the source tree, so `dev/`
  # not shipping cannot make it skip.
  offending <- scrive_senza_nominare("scope_errors")

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
  # The exemption list and the write list are the same list by construction, so
  # the base primitives are the only fixed point to measure it against. If this
  # ever reports more than run_conformance_check, either a second gate-free
  # tool was exempted deliberately (name it above, in the same commit) or the
  # exemption drifted.
  expect_equal(
    setdiff(percorsi_di_scrittura(), c("module_apply", "module_revoke")),
    "run_conformance_check"
  )
})


test_that("nothing writes on an instance without naming the gate on the identity", { # nolint: line_length_linter.
  # eval
  # Guard A of the design, twin of the one above and in the same family. The
  # rule the scope gate enforces is "could the requester have granted this by
  # hand"; this one is "is this the person they meant", and until this
  # sub-project nothing asked it at all -- the channel decided by looking at
  # whether somebody had typed a name into the form.
  offending <- scrive_senza_nominare("identity_actionable")

  # test
  expect_equal(
    offending, character(),
    info = paste(
      "A function that can write on an instance must name the gate on the",
      "identity. Rights are granted to a username, and a username nobody",
      "confirmed is a username that may belong to somebody else -- or to",
      "nobody, in which case the grant sits in REDCap waiting for whoever one",
      "day logs in under that name. The failure is silent in the direction",
      "that matters: the row reports `applied` and the mail goes out saying",
      "so. Coarse on purpose, like its twin: a false red costs a minute, a",
      "false green costs a grant on an identity nobody checked. If you are",
      "deliberately adding a second write path, change this test in the same",
      "commit — not afterwards."
    )
  )
})


test_that("the guards on the package are coarse enough to catch a rename", {
  # eval
  # Same shape as the two guards above, run against hand-written bodies so the
  # test that guards the guards cannot pass by finding nothing.
  named <- function() module_apply(server, secret, requests)
  gated <- function() {
    errors <- scope_errors(register, rights)
    module_apply(server, secret, requests)
  }
  # Passes the scope guard and fails the identity one, which is the state this
  # sub-project found the channel in: a write bounded by what the requester
  # could do by hand, on a username nobody had checked.
  mezzo <- function() {
    errors <- scope_errors(register, rights)
    admitted <- identity_confirmed(verdicts)
    module_apply(server, secret, requests)
  }
  scan <- function(f, cancello) {
    body <- paste(deparse(body(f)), collapse = " ")
    grepl("module_apply", body, fixed = TRUE) &&
      !grepl(cancello, body, fixed = TRUE)
  }

  # test
  expect_true(scan(named, "scope_errors"))
  expect_false(scan(gated, "scope_errors"))
  expect_true(scan(named, "identity_actionable"))
  # The rename is what the coarseness is for: a gate called something else is
  # a gate this search cannot see, and the body reads as if it had none.
  expect_true(scan(mezzo, "identity_actionable"))
  expect_false(scan(mezzo, "scope_errors"))
})


test_that("the gate on the identity cannot exist without the writer", {
  # eval
  # Guard B of the design. The two have to ship together: a package that gates
  # on `identity` without being able to write it is the state in which the
  # channel refuses every row and says nothing about why -- `identity` is empty
  # on every row of the live register, so every row would be refused, quietly
  # and for ever.
  namespace <- asNamespace("ubep.azure")
  present <- function(name) {
    exists(name, envir = namespace, inherits = FALSE)
  }

  # test
  expect_equal(
    present("identity_actionable"), present("register_identity_import"),
    info = paste(
      "The gate and the writer of `identity` must exist together. If you are",
      "removing one, remove the other in the same commit; if you are renaming",
      "one, this test is where the pair is declared."
    )
  )
  expect_true(present("identity_actionable"))
})


test_that("nothing creates an account without naming the gate on scope", {
  # eval
  # Guard D. Making an identity exist is a bigger act than granting a right on
  # one, so it cannot be bounded by less: whoever could not have granted that
  # project by hand must not be able to make the person to grant it to. The
  # gate answers about the requester and not about the person being created,
  # which is why an `absent` row has to reach it at all -- and reaching it is
  # what the round had to be rearranged for.
  offending <- chiama_senza_nominare("directory_create_user", "scope_errors")

  # test
  expect_equal(
    offending, character(),
    info = paste(
      "A function that can create an account on Entra must name the scope",
      "gate. `User.Create` cannot touch an account that already exists, so",
      "the blast radius of a wrong creation is small and reversible -- but it",
      "is an identity in the tenant, made by somebody filling in a form, and",
      "the only thing standing between the two is this rule. If you are",
      "deliberately adding a second creation path, change this test in the",
      "same commit — not afterwards."
    )
  )
})


test_that("the creation path does not take over the carriers it replaces", {
  # eval
  # Guard C. The failure to fear is not "we forgot to delete compose_jobtitle",
  # which is harmless, but "the new path has started writing jobTitle again",
  # which puts two transports back on the same thing. And it is not a
  # hypothetical: the serialized form sits on 2.828 accounts, 254 of them
  # created in 2026, because it is still the only channel of the three machines
  # on major 11. What is being prevented is a live mechanism entering the new
  # path, not a fossil being tidied away.
  namespace <- asNamespace("ubep.azure")
  body_of <- function(name) {
    paste(deparse(body(get(name, envir = namespace))), collapse = " ")
  }
  creators <- c("directory_create_user", Filter(function(name) {
    is.function(get(name, envir = namespace)) &&
      grepl("directory_create_user", body_of(name), fixed = TRUE)
  }, ls(namespace, all.names = TRUE)))

  forbidden <- c("compose_jobtitle", "jobTitle", "officeLocation")
  offending <- Filter(function(name) {
    any(vapply(
      forbidden, function(field) grepl(field, body_of(name), fixed = TRUE),
      logical(1)
    ))
  }, unique(creators))

  # test
  # An assertion that read nothing is not a passing assertion: the way this
  # guard goes quiet is a rename of the creator, not a codebase that got
  # cleaner.
  expect_true("directory_create_user" %in% creators)
  expect_gt(length(creators), 1L)
  expect_equal(
    offending, character(),
    info = paste(
      "The creation path may write neither `jobTitle` nor `officeLocation`.",
      "The authorization has one channel and it is the channel; the contact",
      "address goes in the field that means contact address. The old carrier",
      "is read for as long as accounts carry it -- the sweep counts them, and",
      "the day the count is zero the fallback is dead -- and written never",
      "again. `build_ps1_from_xlsx()` and `compose_jobtitle()` stay alive and",
      "deprecated for edc01, mst01 and edc-redcap, where that field is still",
      "the only channel there is."
    )
  )
})
