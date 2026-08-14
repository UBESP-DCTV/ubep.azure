register_rows <- function(...) {
  rows <- list(...)
  do.call(rbind, lapply(seq_along(rows), function(i) {
    defaults <- list(
      record_id = as.character(i),
      server = "edc05",
      project_id = "9003",
      requested_by = "anna.bianchi@ubep.unipd.it"
    )
    defaults[names(rows[[i]])] <- rows[[i]]
    as.data.frame(defaults, stringsAsFactors = FALSE)
  }))
}


rights_rows <- function(...) {
  rows <- list(...)
  if (length(rows) == 0L) {
    return(data.frame(
      server = character(), project_id = character(),
      username = character(), user_rights = integer(),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, lapply(rows, function(row) {
    defaults <- list(
      server = "edc05",
      project_id = "9003",
      username = "anna.bianchi@ubep.unipd.it",
      user_rights = 1L
    )
    defaults[names(row)] <- row
    as.data.frame(defaults, stringsAsFactors = FALSE)
  }))
}


test_that("a requester who manages the project is in scope", {
  # eval
  errors <- scope_errors(register_rows(list()), rights_rows(list()))

  # test
  expect_length(errors, 0L)
})


test_that("a requester with no rights on the project is refused", {
  # eval
  errors <- scope_errors(
    register_rows(list()),
    rights_rows(list(project_id = "9004"))
  )

  # test
  # The rights table is not empty, and that is the point: the requester manages
  # a different project. A lookup keyed on the person alone would grant this.
  expect_equal(errors[["1"]], "DATO_AMBITO_NON_AUTORIZZATO")
})


test_that("a requester who is a user but manages nobody is refused", {
  # eval
  errors <- scope_errors(
    register_rows(list()),
    rights_rows(list(user_rights = 0L))
  )

  # test
  # Being on the project is not the question. The question is whether this
  # person could have granted the access by hand, and a data entry user could
  # not: the channel must not become the way they can.
  expect_equal(errors[["1"]], "DATO_AMBITO_NON_AUTORIZZATO")
})


test_that("a permission that could not be read refuses, never grants", {
  # eval
  unknown <- scope_errors(
    register_rows(list()),
    rights_rows(list(user_rights = NA_integer_))
  )
  old_module <- scope_errors(
    register_rows(list()),
    rights_rows(list())[, c("server", "project_id", "username")]
  )

  # test
  # These two are the same failure wearing different clothes: a role deleted
  # underneath a row, and an instance answered by a module too old to report
  # the permission at all. Neither is a permission, and the direction they fail
  # in is the whole reason this function exists.
  expect_equal(unknown[["1"]], "DATO_AMBITO_NON_AUTORIZZATO")
  expect_equal(old_module[["1"]], "DATO_AMBITO_NON_AUTORIZZATO")
})


test_that("a value REDCap might add does not grant by being close to one", {
  # eval
  errors <- scope_errors(
    register_rows(list()),
    rights_rows(list(user_rights = 2L))
  )

  # test
  # An upgrade that introduces a third value must be read before it is trusted.
  # Accepting anything above zero is how a permission gets widened by a release
  # nobody connected to this file.
  expect_equal(errors[["1"]], "DATO_AMBITO_NON_AUTORIZZATO")
})


test_that("a row nobody can be attributed with is refused", {
  # eval
  errors <- scope_errors(
    register_rows(list(requested_by = "")),
    rights_rows(list())
  )

  # test
  # `requested_by` is `@USERNAME @READONLY`, so an empty one is not a person
  # who forgot to fill it in: it is a row that arrived by a path the form does
  # not have, and the whole gate rests on attribution.
  expect_equal(errors[["1"]], "DATO_AMBITO_NON_AUTORIZZATO")
})


test_that("a row with nothing to ask about is left to the other codes", {
  # eval
  no_project <- scope_errors(
    register_rows(list(project_id = "")),
    rights_rows(list())
  )
  no_server <- scope_errors(
    register_rows(list(server = "")),
    rights_rows(list())
  )

  # test
  # No instance can answer for these, and `validate_request()` already reports
  # the missing project. A second code on the same row would send back two
  # diagnoses for one mistake.
  expect_length(no_project, 0L)
  expect_length(no_server, 0L)
})


test_that("the scope key does not collapse two different triples", {
  # eval
  register <- register_rows(list(project_id = "900", requested_by = "3a@x.it"))
  rights <- rights_rows(list(project_id = "9003", username = "a@x.it"))
  errors <- scope_errors(register, rights)

  # test
  # Joined without a separator the two triples read as the same string. A
  # lookup that collapsed them would grant this row on somebody else's
  # permission, which is the one failure this gate exists to prevent.
  expect_equal(errors[["1"]], "DATO_AMBITO_NON_AUTORIZZATO")
})


test_that("scope_pairs asks once per triple and only about askable rows", {
  # eval
  register <- register_rows(
    list(),
    list(),
    list(project_id = "9004"),
    list(server = ""),
    list(requested_by = "")
  )
  pairs <- scope_pairs(register)

  # test
  # The two identical rows become one question, and the three that no instance
  # can answer are not asked. The requester travels under `username` because
  # that is the name a pair carries in a `state` call.
  expect_equal(nrow(pairs), 2L)
  expect_setequal(names(pairs), c("server", "project_id", "username"))
  expect_setequal(pairs[["project_id"]], c("9003", "9004"))
  expect_equal(unique(pairs[["username"]]), "anna.bianchi@ubep.unipd.it")
})
