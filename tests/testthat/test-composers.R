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
