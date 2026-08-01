test_that("the cases cover every governed field", {
  # eval
  cases <- conformance_cases()
  asserted <- unique(unlist(lapply(cases, function(x) names(x[["assert"]]))))

  # test
  # A field the cases do not assert is a field the gate is blind to, so the
  # coverage is checked rather than trusted.
  expect_setequal(asserted, c("role_name", "dag_name", "expiration"))
  expect_true(length(cases) >= 4L)
  expect_true(all(vapply(cases, function(x) nzchar(x[["name"]]), logical(1))))
})


test_that("compare_readback reports the field that differs", {
  # eval
  expected <- list(role_name = "data entry", dag_name = "centro-01",
                   expiration = "2027-01-01")
  identical_read <- compare_readback(expected, expected)
  lost_dag <- compare_readback(
    expected,
    utils::modifyList(expected, list(dag_name = NULL))
  )

  # test
  expect_true(identical_read[["conforms"]])
  expect_equal(identical_read[["differences"]], character())
  expect_false(lost_dag[["conforms"]])
  expect_true("dag_name" %in% lost_dag[["differences"]])
})


test_that("compare_readback does not tolerate a missing row", {
  # eval
  expected <- list(role_name = "data entry", dag_name = NULL,
                   expiration = NULL)
  absent <- compare_readback(expected, NULL)

  # test
  # An assertion that produced no row at all is the loudest possible failure,
  # and it must not read as "nothing to compare, therefore fine".
  expect_false(absent[["conforms"]])
  expect_true("role_name" %in% absent[["differences"]])
})


test_that("a dry run that changed anything fails the check", {
  # eval
  before <- list(role_name = "read only", dag_name = NULL,
                 expiration = NULL)
  after_dry_run <- list(role_name = "data entry", dag_name = NULL,
                        expiration = NULL)
  verdict <- compare_readback(before, after_dry_run)

  # test
  # Step two of the run: the structural guarantee behind dry_run, measured
  # rather than asserted. If the simulation wrote, this is what sees it.
  expect_false(verdict[["conforms"]])
  expect_true("role_name" %in% verdict[["differences"]])
})
