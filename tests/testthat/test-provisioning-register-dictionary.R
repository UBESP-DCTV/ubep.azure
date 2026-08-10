test_that("dictionary_choices splits a choice string on the first comma", {
  # eval
  parsed <- dictionary_choices("a, alpha | b, beta, gamma")

  # test
  expect_equal(parsed[["code"]], c("a", "b"))
  expect_equal(parsed[["label"]], c("alpha", "beta, gamma"))
})


test_that("every coded field uses its label as its own code", {
  # eval
  dictionary <- register_dictionary(instances = c("srvA", "srvB"))
  coded <- dictionary[
    dictionary[["Field Type"]] %in% c("radio", "dropdown", "checkbox"),
  ]

  # test
  # A code that differs from its label forces the client to hold a map from one
  # to the other, and a reordering of the choices would then shift that map in
  # silence. Making them equal removes the map, and this test is what keeps a
  # convention from decaying into a habit.
  #
  # Read with a list rather than as the template: on the template `server` has
  # no choices, so this assertion would compare two empty vectors and pass
  # without having looked at the field it exists to check. It would have stayed
  # green while covering one field fewer, which no failure announces.
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


test_that("the job-written fields are the ones marked read-only", {
  # eval
  dictionary <- register_dictionary()
  annotation <- dictionary[["Field Annotation"]]
  annotation[is.na(annotation)] <- ""
  names <- dictionary[["Variable / Field Name"]]
  marked <- names[grepl("@READONLY", annotation)]

  # test
  # Without the tag a requester could type "applied" into the outcome and the
  # register would carry a success nobody produced. The tag governs the form
  # only, not the API, so the job keeps writing them.
  expect_setequal(marked, register_readonly_fields())
})


test_that("the register carries the names the pure layer speaks", {
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


test_that("a project answering with the packaged dictionary conforms", {
  # eval
  verdict <- compare_dictionary(register_dictionary())

  # test
  # The baseline the other cases are read against: without it, a comparison
  # that reported drift for everything would look just as green as one that
  # works.
  expect_true(verdict[["conforms"]])
  expect_equal(verdict[["differences"]], character(0))
})


test_that("a field the project does not carry is reported by name", {
  # eval
  dictionary <- register_dictionary()
  without <- dictionary[
    dictionary[["Variable / Field Name"]] != "expiration",
  ]
  verdict <- compare_dictionary(without)

  # test
  # An absent field is not cosmetic: request_from_row() reads a missing column
  # as "not set", so the import silently losing one would turn every request
  # into a request that never asked for it.
  expect_false(verdict[["conforms"]])
  expect_true(
    "DIZIONARIO_CAMPO_ASSENTE:expiration" %in% verdict[["differences"]]
  )
})


test_that("a field that lost its read-only tag is reported by name", {
  # eval
  dictionary <- register_dictionary()
  loosened <- dictionary
  row <- loosened[["Variable / Field Name"]] == "outcome"
  loosened[["Field Annotation"]][row] <- ""
  verdict <- compare_dictionary(loosened)

  # test
  # The tag governs the form, not the API. Losing it does not break anything
  # that raises: it lets a requester type "applied" into the outcome, and the
  # register then carries a success nobody produced. Nothing else in the
  # channel would notice.
  expect_false(verdict[["conforms"]])
  expect_true(
    "DIZIONARIO_READONLY_CADUTO:outcome" %in% verdict[["differences"]]
  )
})


test_that("a field whose type changed is reported by name", {
  # eval
  dictionary <- register_dictionary()
  retyped <- dictionary
  row <- retyped[["Variable / Field Name"]] == "request_status"
  retyped[["Field Type"]][row] <- "text"
  verdict <- compare_dictionary(retyped)

  # test
  # register_to_desired() reads revocation as identical(status, "revoked").
  # With a free-text status a typo does not raise: it falls to the other
  # branch and the row becomes a request to *grant* what someone asked to
  # revoke. The radio is what makes that unrepresentable.
  expect_false(verdict[["conforms"]])
  expect_true(
    "DIZIONARIO_TIPO_DIVERSO:request_status" %in% verdict[["differences"]]
  )
})


test_that("a field whose choices changed is reported by name", {
  # eval
  dictionary <- register_dictionary()
  narrowed <- dictionary
  row <- narrowed[["Variable / Field Name"]] == "request_status"
  narrowed[["Choices, Calculations, OR Slider Labels"]][row] <- "active, active"
  verdict <- compare_dictionary(narrowed)

  # test
  # Same field, drift the type check cannot see: it is still a radio, and it
  # still has choices. What it lost is the only value that revokes anything.
  expect_false(verdict[["conforms"]])
  expect_true(
    "DIZIONARIO_SCELTE_DIVERSE:request_status" %in% verdict[["differences"]]
  )
})


test_that("choices that differ only in spacing are not drift", {
  # eval
  dictionary <- register_dictionary()
  respaced <- dictionary
  column <- "Choices, Calculations, OR Slider Labels"
  row <- respaced[["Variable / Field Name"]] == "request_status"
  respaced[[column]][row] <- "active, active|revoked, revoked"
  verdict <- compare_dictionary(respaced)

  # test
  # A collaudo that cries drift on a round trip is a collaudo nobody reads by
  # the third run. What the channel contracts on is the set of codes, which
  # this string carries unchanged.
  expect_true(verdict[["conforms"]])
  expect_equal(verdict[["differences"]], character(0))
})


test_that("a field the project carries and the package does not is reported", {
  # eval
  dictionary <- register_dictionary()
  extra <- dictionary[1, ]
  extra[["Variable / Field Name"]] <- "note_del_referente"
  verdict <- compare_dictionary(rbind(dictionary, extra))

  # test
  # Harmless to the channel, which reads only the fields it knows — and that is
  # the reason to report it. It is the one drift that breaks nothing and so
  # would never surface on its own, while being direct evidence that somebody
  # edited the form by hand.
  expect_false(verdict[["conforms"]])
  expect_true(
    "DIZIONARIO_CAMPO_IN_PIU:note_del_referente" %in% verdict[["differences"]]
  )
})


test_that("a dictionary without the annotation column reports, not raises", {
  # eval
  dictionary <- register_dictionary()
  dictionary[["Field Annotation"]] <- NULL

  # test
  # The realistic shape of a hand-made export, and the one case where the
  # collaudo failing loudly would be worse than useless: an error reads as
  # "the check is broken" and gets skipped, while the truth is that every
  # read-only tag is missing.
  expect_no_error(verdict <- compare_dictionary(dictionary))
  expect_false(verdict[["conforms"]])
  expect_true(
    all(
      paste0("DIZIONARIO_READONLY_CADUTO:", register_readonly_fields()) %in%
        verdict[["differences"]]
    )
  )
})


test_that("a dictionary missing a compared column is not conforming", {
  # eval
  dictionary <- register_dictionary()
  dictionary[["Field Type"]] <- NULL
  verdict <- compare_dictionary(dictionary)

  # test
  # Without this the comparison of a length-17 vector against a length-0 one
  # yields logical(0), so nothing is reported and a malformed dictionary reads
  # as conforming — the silent pass this whole function exists to prevent, in
  # the function itself.
  expect_false(verdict[["conforms"]])
  expect_true(
    "DIZIONARIO_COLONNA_ASSENTE:Field Type" %in% verdict[["differences"]]
  )
})


test_that("the packaged dictionary is a template with no fleet in it", {
  # eval
  dictionary <- register_dictionary()
  row <- dictionary[["Variable / Field Name"]] == "server"
  choices <- dictionary[["Choices, Calculations, OR Slider Labels"]][row]

  # test
  # The choices of `server` are the fleet, which changes when the machines
  # change rather than when the contract does. Keeping them here coupled a
  # release of this package to every movement of the fleet, and published the
  # list in a public repository. The other coded fields are the contract's own
  # vocabulary and stay.
  expect_equal(nrow(dictionary), 17L)
  expect_true(is.na(choices) || !nzchar(choices))
  for (name in c("identity", "request_status", "outcome")) {
    kept <- dictionary[["Choices, Calculations, OR Slider Labels"]][
      dictionary[["Variable / Field Name"]] == name
    ]
    expect_true(nzchar(kept), info = name)
  }
})


test_that("an instance list fills the template's choices", {
  # eval
  dictionary <- register_dictionary(instances = c("srvA", "srvB"))
  row <- dictionary[["Variable / Field Name"]] == "server"
  parsed <- dictionary_choices(
    dictionary[["Choices, Calculations, OR Slider Labels"]][row]
  )

  # test
  # Code equal to label, like every other coded field: a code that differs from
  # its label forces the client to hold a map, and a reordering would then
  # shift that map in silence.
  expect_equal(parsed[["code"]], c("srvA", "srvB"))
  expect_equal(parsed[["label"]], c("srvA", "srvB"))
  expect_equal(nrow(dictionary), 17L)
})


test_that("an empty instance list is refused, and is not the same as none", {
  # test
  # NULL means "I am not passing it, judge as best you can". A zero-length
  # vector means "the fleet is this, and it is empty" — a false statement that
  # would produce a dictionary indistinguishable from the template, reached for
  # the opposite reason. An empty or missing name would silently become the
  # choice ", " inside a dictionary that otherwise looks sound.
  #
  # The message is asserted, not merely the failure: before the argument
  # existed a bare expect_error() was satisfied by "unused argument", so it
  # passed for a reason that was about to disappear — green on a check that had
  # never once been red for its own reason.
  expect_error(
    register_dictionary(instances = character(0)),
    regexp = "non-empty character"
  )
  expect_error(
    register_dictionary(instances = c("srvA", "")),
    regexp = "non-empty character"
  )
  expect_error(
    register_dictionary(instances = c("srvA", NA)),
    regexp = "non-empty character"
  )
})


test_that("what the job writes is declared in the dictionary too", {
  # eval
  written <- setdiff(
    names(outcome_payload(record_id = "1", outcome = "pending")),
    "record_id"
  )

  # test
  # This is the seam between the two artifacts: adding an outcome field to the
  # dictionary without teaching the payload about it, or the other way round,
  # turns this red instead of producing a field nobody fills.
  expect_true(all(written %in% register_readonly_fields()))
  declared <- register_dictionary()[["Variable / Field Name"]]
  expect_true(all(written %in% declared))
})
