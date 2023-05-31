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




test_that("clean_string work properly", {
  # setup
  space_and_points <- " berto  j.  "
  hypen_and_points <- " berto's  j. H "

  # eval
  res_dot <- clean_string(space_and_points)
  res_hypen <- clean_string(hypen_and_points)

  # test
  expect_equal(res_dot, "berto.j.")
  expect_equal(res_hypen, "bertos.j.h")
})




test_that("empty rows are cleaned up", {
  # setup
  db_wit_empties <- paste0(
    "Nome,Cognome,Email,",
    "Prj1_ID,Prj1_role,Prj1_DAG,",
    "Prj2_ID,Prj2_role,Prj2_DAG\n",
    "Ex,Ample,ex.ample@example.it,160,utente_base,,,,\n,,,,,,,,"
  )

  # eval
  res <- read_data(db_wit_empties, csv = TRUE)

  # test
  expect_equal(nrow(res), 1L)
})




test_that("compose_jobtitle works for no, one, two projects", {
  # eval
  jt_1 <- compose_jobtitle(example_tbl, 1)
  jt_2 <- compose_jobtitle(example_tbl, 2)
  jt_3 <- compose_jobtitle(example_tbl, 3)
  jt_4 <- compose_jobtitle(example_tbl, 4)
  jt_5 <- compose_jobtitle(example_tbl, 5)

  # test
  expect_equal(
    jt_1,
    " -JobTitle \"Prj,1|role,user|DAG,a;Prj,3|role,user|DAG,c\" "
  )
  expect_equal(jt_2, " -JobTitle \"Prj,2|role,power|DAG,b\" ")
  expect_equal(jt_3, " -JobTitle \"Prj,4|role,boss|DAG,d\" ")
  expect_equal(jt_4, "")
  expect_equal(jt_5, "")

  expect_silent(compose_jobtitle(example_tbl, 1))
})
