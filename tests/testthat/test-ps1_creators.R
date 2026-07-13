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


test_that("the initial password is parametrizable, no weak literal", {
  dir <- withr::local_tempdir()
  users <- data.frame(
    Nome = "Mario", Cognome = "Rossi", Email = "mario.rossi@example.org",
    Prj1_ID = NA, Prj1_role = NA, Prj1_DAG = NA,
    Prj2_ID = NA, Prj2_role = NA, Prj2_DAG = NA
  )
  readr::write_csv(users, file.path(dir, "batch.csv"), na = "")

  # an explicit value (3rd positional arg) is used as the initial password
  sentinel <- "ZZ-marker-value-9x!"
  ps1_create_bulk_users("batch", dir, sentinel)
  ps1 <- readr::read_lines(file.path(dir, "batch.ps1"))
  needle <- paste0("Password", " = '", sentinel, "'")
  expect_true(any(grepl(needle, ps1, fixed = TRUE)))

  # the default path never emits the old public literal
  ps1_create_bulk_users("batch", dir)
  ps1_default <- readr::read_lines(file.path(dir, "batch.ps1"))
  expect_false(any(grepl("P@ssw0rd", ps1_default, fixed = TRUE)))
})


test_that("the generated scripts use Microsoft Graph cmdlets and parameters", {
  dir <- withr::local_tempdir()
  users <- data.frame(
    Nome = "Mario", Cognome = "Rossi", Email = "mario.rossi@example.org",
    Prj1_ID = 1, Prj1_role = "user", Prj1_DAG = "dag1",
    Prj2_ID = 3, Prj2_role = "boss", Prj2_DAG = "dag3"
  )
  readr::write_csv(users, file.path(dir, "batch.csv"), na = "")

  ps1_create_bulk_users("batch", dir, "snapshot-fixed-value-1")
  create <- paste(
    readr::read_lines(file.path(dir, "batch.ps1")),
    collapse = "\n"
  )
  del <- paste(
    readr::read_lines(file.path(dir, "batch_deleteUsers.ps1")),
    collapse = "\n"
  )

  # migrated to Microsoft Graph, not the retired AzureAD module
  expect_match(create, "New-MgUser", fixed = TRUE)
  expect_no_match(create, "New-AzureADUser", fixed = TRUE)
  expect_match(create, "$PasswordProfile = @{", fixed = TRUE)
  expect_match(create, "ForceChangePasswordNextSignIn = $true", fixed = TRUE)
  expect_match(create, "-AccountEnabled:$true", fixed = TRUE)
  expect_match(create, "-OfficeLocation", fixed = TRUE)
  expect_match(
    create, "-UserPrincipalName \"mario.rossi@ubep.unipd.it\"",
    fixed = TRUE
  )
  # JobTitle encodes project/role/DAG, two projects joined by ';'
  expect_match(
    create,
    "-JobTitle \"Prj,1|role,user|DAG,dag1;Prj,3|role,boss|DAG,dag3\"",
    fixed = TRUE
  )

  expect_match(
    del, "Remove-MgUser -UserId \"mario.rossi@ubep.unipd.it\"",
    fixed = TRUE
  )
  expect_no_match(del, "Remove-AzureADUser", fixed = TRUE)
})
