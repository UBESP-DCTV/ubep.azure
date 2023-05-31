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

test_that("read_data doesn't produce readr output for column spec", {
  # setup
  db_wit_empties <- paste0(
    "Nome,Cognome,Email,",
    "Prj1_ID,Prj1_role,Prj1_DAG,",
    "Prj2_ID,Prj2_role,Prj2_DAG\n",
    "Ex,Ample,ex.ample@example.it,160,utente_base,,,,\n,,,,,,,,"
  )

  expect_silent(read_data(db_wit_empties, csv = TRUE))
})
