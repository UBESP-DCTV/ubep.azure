test_that("get_usr_principalname write correct files", {
  # setup
  tmp <- fs::file_temp(ext = "ps")
  readr::write_lines(example_ps, tmp)

  tmp_out <- fs::file_temp(ext = "csv")

  # evaluation
  actual <- get_usrs_principalname(tmp, out_file = tmp_out)
  expected <- c(
    "version:v1.0",
    "Member object ID or user principal name [memberObjectIdOrUpn] Required",
    "GIOVANNI.AGOSTINI@ubep.unipd.it",
    "JACOPOMARIA.AGOSTINI@ubep.unipd.it"
  )

  # tests
  readr::read_lines(tmp_out) |> expect_equal(expected)

})


test_that("get_usr_principalname works", {
  # setup
  tmp <- fs::file_temp(ext = "ps")
  readr::write_lines(example_ps, tmp)

  # evaluation
  actual <- get_usrs_principalname(tmp)
  expected <- c(
    "GIOVANNI.AGOSTINI@ubep.unipd.it",
    "JACOPOMARIA.AGOSTINI@ubep.unipd.it"
  )

  # tests
  actual |> expect_equal(expected)

})
