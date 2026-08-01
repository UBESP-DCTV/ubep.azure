test_that("an identical pair is a noop", {
  # eval
  desired <- list(list(
    username = "mario.rossi@ubep.unipd.it", project_id = 27L,
    role_name = "data entry", dag_name = "centro-01",
    expiration = "2026-12-31"
  ))
  actual <- list(list(
    username = "mario.rossi@ubep.unipd.it", project_id = 27L,
    role_name = "data entry", dag_name = "centro-01",
    expiration = "2026-12-31"
  ))
  result <- provisioning_diff(desired, actual)

  # test
  expect_equal(nrow(result), 1L)
  expect_equal(result[["action"]], "noop")
})


test_that("a missing pair must be created", {
  # eval
  desired <- list(list(
    username = "mario.rossi@ubep.unipd.it", project_id = 27L,
    role_name = "data entry", dag_name = NULL, expiration = NULL
  ))
  result <- provisioning_diff(desired, list())

  # test
  expect_equal(result[["action"]], "creato")
  expect_null(result[["before"]][[1]][["role_name"]])
  expect_equal(result[["after"]][[1]][["role_name"]], "data entry")
})


test_that("any differing field makes it an update", {
  # eval
  base_desired <- list(
    username = "mario.rossi@ubep.unipd.it", project_id = 27L,
    role_name = "data entry", dag_name = "centro-01",
    expiration = "2026-12-31"
  )
  changed_role <- provisioning_diff(
    list(base_desired),
    list(utils::modifyList(base_desired, list(role_name = "read only")))
  )
  changed_dag <- provisioning_diff(
    list(base_desired),
    list(utils::modifyList(base_desired, list(dag_name = "centro-02")))
  )
  changed_expiry <- provisioning_diff(
    list(base_desired),
    list(utils::modifyList(base_desired, list(expiration = "2027-01-31")))
  )

  # test
  expect_equal(changed_role[["action"]], "aggiornato")
  expect_equal(changed_dag[["action"]], "aggiornato")
  expect_equal(changed_expiry[["action"]], "aggiornato")
})


test_that("a DAG present in reality but not wanted is an update", {
  # eval
  desired <- list(list(
    username = "mario.rossi@ubep.unipd.it", project_id = 27L,
    role_name = "data entry", dag_name = NULL, expiration = NULL
  ))
  actual <- list(list(
    username = "mario.rossi@ubep.unipd.it", project_id = 27L,
    role_name = "data entry", dag_name = "centro-01", expiration = NULL
  ))
  result <- provisioning_diff(desired, actual)

  # test
  # Never a noop: `apply` always asserts the full state, so a DAG nobody asked
  # for has to be visible as a difference rather than tolerated.
  expect_equal(result[["action"]], "aggiornato")
})


test_that("reality with no request behind it is flagged for revocation", {
  # eval
  actual <- list(list(
    username = "ignoto@ubep.unipd.it", project_id = 27L,
    role_name = "data entry", dag_name = NULL, expiration = NULL
  ))
  result <- provisioning_diff(list(), actual)

  # test
  # This is one of the three drifts nobody sees today: an access in REDCap
  # that no request ever asked for.
  expect_equal(result[["action"]], "revocato")
})


test_that("the diff is idempotent", {
  # eval
  desired <- list(list(
    username = "mario.rossi@ubep.unipd.it", project_id = 27L,
    role_name = "data entry", dag_name = "centro-01",
    expiration = "2026-12-31"
  ))
  first <- provisioning_diff(desired, list())
  # after applying, reality equals the desired state
  second <- provisioning_diff(desired, desired)

  # test
  expect_equal(first[["action"]], "creato")
  expect_equal(second[["action"]], "noop")
})


test_that("pairs are matched on username and project together", {
  # eval
  desired <- list(list(
    username = "mario.rossi@ubep.unipd.it", project_id = 27L,
    role_name = "data entry", dag_name = NULL, expiration = NULL
  ))
  actual <- list(list(
    username = "mario.rossi@ubep.unipd.it", project_id = 99L,
    role_name = "data entry", dag_name = NULL, expiration = NULL
  ))
  result <- provisioning_diff(desired, actual)

  # test
  # Same person, different project: one creation and one revocation, never a
  # noop. The pair is the unit, not the user.
  expect_equal(nrow(result), 2L)
  expect_setequal(result[["action"]], c("creato", "revocato"))
})


test_that("an empty diff is still a usable data frame", {
  # eval
  result <- provisioning_diff(list(), list())

  # test
  # The audit binds one of these per server, so the empty case has to carry the
  # same columns as a populated one or the bind changes shape when a server
  # happens to have nothing to report.
  expect_equal(nrow(result), 0L)
  expect_named(
    result, c("username", "project_id", "action", "before", "after")
  )
})


test_that("a real state row parses into the diff unchanged", {
  # eval
  payload <- jsonlite::fromJSON(
    testthat::test_path("fixtures", "state-response.json"),
    simplifyVector = FALSE
  )
  result <- provisioning_diff(list(), payload[["results"]])

  # test
  # Guards the seam between the module's JSON and the pure layer: `results`
  # rows arrive with JSON nulls, which must read as absent fields and not as
  # the string "NULL".
  expect_equal(nrow(result), 3L)
  expect_true(all(result[["action"]] == "revocato"))
  expect_null(result[["before"]][[3]][["role_name"]])
  expect_equal(result[["before"]][[2]][["dag_name"]], "centro-01")
})
