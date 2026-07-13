test_that("logImportUsers.csv keeps one correct row per user", {
  # setup: a temp server folder with a 3-user import CSV
  dir <- withr::local_tempdir()
  users <- data.frame(
    Nome = c("Mario", "Anna", "Luca"),
    Cognome = c("Rossi", "Bianchi", "Verdi"),
    Email = c(
      "mario.rossi@example.org",
      "anna.bianchi@example.org",
      "luca.verdi@example.org"
    ),
    Prj1_ID = c(1, 2, NA),
    Prj1_role = c("user", "power", NA),
    Prj1_DAG = c("dag1", "dag2", NA),
    Prj2_ID = NA,
    Prj2_role = NA,
    Prj2_DAG = NA
  )
  readr::write_csv(users, file.path(dir, "batch.csv"), na = "")

  # evaluation
  ps1_create_bulk_users("batch", dir)
  log <- readr::read_csv(
    file.path(dir, "logImportUsers.csv"),
    show_col_types = FALSE
  )

  # tests: exactly one row per user, and each row's data is that user's own
  expect_equal(nrow(log), 3L)
  expect_equal(ncol(log), 5L)
  expect_equal(
    log[[1]],
    c(
      "mario.rossi@ubep.unipd.it",
      "anna.bianchi@ubep.unipd.it",
      "luca.verdi@ubep.unipd.it"
    )
  )
  expect_equal(log[[2]], c("Mario", "Anna", "Luca"))
  expect_equal(log[[3]], c("Rossi", "Bianchi", "Verdi"))
  expect_equal(log[[4]], users$Email)
})


test_that("an error during generation does not leave a dangling sink", {
  dir <- withr::local_tempdir()
  bad <- data.frame(wrong = 1, columns = 2) # no Nome/Cognome: fails in-loop
  readr::write_csv(bad, file.path(dir, "batch.csv"))

  before <- sink.number()
  expect_error(ps1_create_bulk_users("batch", dir))
  leaked <- sink.number() > before
  while (sink.number() > before) sink() # cleanup so the runner is not corrupted

  expect_false(leaked)
})
