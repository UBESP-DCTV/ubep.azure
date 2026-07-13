make_server_tree <- function(users, name = "20260101_importUtenti_edc07_CL") {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  server_dir <- file.path(root, "edc07")
  to_import <- file.path(server_dir, "toImport")
  dir.create(to_import, recursive = TRUE)
  path <- file.path(to_import, paste0(name, ".xlsx"))
  writexl::write_xlsx(users, path)
  path
}

valid_users <- function() {
  data.frame(
    Nome = "Mario",
    Cognome = "Rossi",
    Email = "mario.rossi@example.org",
    Prj1_ID = 1,
    Prj1_role = "user",
    Prj1_DAG = "dag1",
    Prj2_ID = NA,
    Prj2_role = NA,
    Prj2_DAG = NA
  )
}


test_that("a .csv input is rejected: the package accepts xlsx only", {
  dir <- withr::local_tempdir()
  server_dir <- file.path(dir, "edc07")
  dir.create(server_dir)
  csv <- file.path(server_dir, "20260101_importUtenti_edc07_CL.csv")
  readr::write_csv(valid_users(), csv)

  expect_error(build_ps1_from_xlsx(csv), "xlsx")
})


test_that("a row missing Cognome stops instead of creating an NA user", {
  users <- valid_users()
  users[2, ] <- NA
  users[2, "Nome"] <- "Giulia" # Cognome deliberately left NA
  path <- make_server_tree(users)

  expect_error(build_ps1_from_xlsx(path), "Cognome|incomplet|row")
})


test_that("a fully empty trailing row does not become a phantom user", {
  users <- valid_users()
  users[2, ] <- NA
  path <- make_server_tree(users)

  build_ps1_from_xlsx(path)
  ps1 <- readr::read_lines(
    file.path(dirname(dirname(path)), "20260101_importUtenti_edc07_CL.ps1")
  )

  expect_length(grep("New-MgUser", ps1), 1L)
  expect_false(any(grepl("NA\\.NA", ps1)))
})
