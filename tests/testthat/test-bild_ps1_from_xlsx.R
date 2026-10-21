test_that("build_ps1_from_xlsx() is defunct and says why", {
  expect_error(build_ps1_from_xlsx(), "defunct", class = "defunctError")
  expect_error(build_ps1_from_xlsx(), "authorization channel")
  expect_error(build_ps1_from_xlsx(), "jobTitle")
})


test_that("build_ps1_from_xlsx() never runs, whatever it is given", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "20260101_importUtenti_edc07_CL.xlsx")
  writexl::write_xlsx(data.frame(Nome = "Mario"), path)

  expect_error(build_ps1_from_xlsx(path), "defunct")
  expect_error(build_ps1_from_xlsx(path, pwd = "x"), "defunct")
  expect_length(list.files(dir), 1L)
})
