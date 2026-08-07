test_that("dictionary_choices splits a REDCap choice string on the first comma", {
  # eval
  parsed <- dictionary_choices("a, alpha | b, beta, gamma")

  # test
  expect_equal(parsed[["code"]], c("a", "b"))
  expect_equal(parsed[["label"]], c("alpha", "beta, gamma"))
})


test_that("every coded field uses its label as its own code", {
  # eval
  dictionary <- register_dictionary()
  coded <- dictionary[
    dictionary[["Field Type"]] %in% c("radio", "dropdown", "checkbox"),
  ]

  # test
  # A code that differs from its label forces the client to hold a map from one
  # to the other, and a reordering of the choices would then shift that map in
  # silence. Making them equal removes the map, and this test is what keeps a
  # convention from decaying into a habit.
  expect_gt(nrow(coded), 0L)
  for (row in seq_len(nrow(coded))) {
    parsed <- dictionary_choices(
      coded[["Choices, Calculations, OR Slider Labels"]][[row]]
    )
    expect_equal(
      parsed[["code"]],
      parsed[["label"]],
      info = coded[["Variable / Field Name"]][[row]]
    )
  }
})


test_that("the fields only the job writes are the ones marked read-only", {
  # eval
  dictionary <- register_dictionary()
  annotation <- dictionary[["Field Annotation"]]
  annotation[is.na(annotation)] <- ""
  marked <- dictionary[["Variable / Field Name"]][grepl("@READONLY", annotation)]

  # test
  # Without the tag a requester could type "applied" into the outcome and the
  # register would carry a success nobody produced. The tag governs the form
  # only, not the API, so the job keeps writing them.
  expect_setequal(marked, register_readonly_fields())
})


test_that("the register carries the field names the pure layer already speaks", {
  # eval
  fields <- register_dictionary()[["Variable / Field Name"]]

  # test
  # These names are not a choice of style: they are the ones validate_request()
  # and provisioning_diff() use, so that no map exists between the form and the
  # request, and no key can fall into a default without raising.
  expect_true(
    all(
      c(
        "server", "project_id", "username", "first_name", "last_name",
        "contact_email", "role_name", "dag_name", "expiration",
        "requested_by", "request_status"
      ) %in% fields
    )
  )
})


test_that("what the job writes is declared in the dictionary too", {
  # eval
  written <- setdiff(
    names(outcome_payload(record_id = "1", outcome = "pending")),
    "record_id"
  )

  # test
  # This is the seam between the two artefacts: adding an outcome field to the
  # dictionary without teaching the payload about it, or the other way round,
  # turns this red instead of producing a field nobody fills.
  expect_true(all(written %in% register_readonly_fields()))
  expect_true(all(written %in% register_dictionary()[["Variable / Field Name"]]))
})
