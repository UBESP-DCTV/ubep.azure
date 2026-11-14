test_that("empty rows are cleaned up", {
  # setup
  db_wit_empties <- paste0(
    "Nome,Cognome,Email,",
    "Prj1_ID,Prj1_role,Prj1_DAG,",
    "Prj2_ID,Prj2_role,Prj2_DAG\n",
    "Ex,Ample,ex.ample@example.it,160,utente_base,,,,\n,,,,,,,,"
  )

  # eval
  # I() says "this string is the data, not a path to it". Since readr 2.2.0
  # the bare form is deprecated, and the deprecation speaks only when the
  # caller is the package under test -- so it is silent under a hand-rolled
  # test_file() and audible under devtools::test(), which is the shape of
  # warning that survives a long time by looking like somebody else's.
  res <- read_data(I(db_wit_empties), csv = TRUE)

  # test
  expect_equal(nrow(res), 1L)
})


test_that("generate_password is strong and covers all character classes", {
  pw <- generate_password()

  expect_type(pw, "character")
  expect_length(pw, 1L)
  expect_gte(nchar(pw), 16L)
  expect_match(pw, "[a-z]")
  expect_match(pw, "[A-Z]")
  expect_match(pw, "[0-9]")
  expect_match(pw, "[^a-zA-Z0-9]")
})


test_that("generate_password returns a different value on each call", {
  expect_false(generate_password() == generate_password())
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

  expect_silent(read_data(I(db_wit_empties), csv = TRUE))
})


# Names that have given trouble to a fold, or that a directory can plausibly
# hold. The fixtures are invented: nothing here is a person of the tenant.
hard_names <- c(
  "Rossi", "ROSSI", "  rossi  ", "de   Luca", "Mc Donald", "O'Brien",
  "D\u2019Angelo", "O\u2018Hara", "Bianchi-Verdi", "Bianchi - Verdi",
  "Nu\u00f1ez", "Nu\u006e\u0303ez", "M\u00fcller", "Mu\u0308ller",
  "Cafe\u0301", "Caf\u00e9", "\u0160koda", "Garc\u00eda L\u00f3pez",
  "\u00c9lodie", "Fran\u00e7ois", "\u00d8stergaard", "\u0141ukasz",
  "Stra\u00dfe",
  "\u0645\u062d\u0645\u062f", "\u0418\u0432\u0430\u043d\u043e\u0432",
  "\u5f20\u4f1f", "a.b.c", "a..b", "a b\tc", "123", "x_y", "",
  " ", "...", "'", NA_character_
)

test_that("clean_string on a vector is the element-by-element fold", {
  # The directory is folded whole in the round (`directory_named()`), and what
  # the round used to do was one call per element: the two have to agree on
  # every value, `NA` and the empty string included.
  per_element <- vapply(hard_names, clean_string, character(1))

  expect_identical(unname(per_element), clean_string(hard_names))
  expect_identical(clean_string(character()), character())
  expect_identical(clean_string(NA_character_), NA_character_)
  expect_identical(clean_string(c(NA, NA)), c(NA_character_, NA_character_))
  expect_identical(
    clean_string(c("A", NA, "b")),
    c("a", NA_character_, "b")
  )
})
