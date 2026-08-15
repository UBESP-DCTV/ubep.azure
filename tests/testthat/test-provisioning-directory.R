# One directory record, with every selected field present and overridable. The
# defaults are what a member of the tenant looks like; a test that cares about
# one field names that field and inherits the rest, so the thing under test is
# visible in the call instead of buried in nine lines of scaffolding.
graph_user <- function(...) {
  utils::modifyList(
    list(
      id = "00000000-0000-0000-0000-000000000001",
      userPrincipalName = "mario.rossi@ubep.unipd.it",
      givenName = "Mario",
      surname = "Rossi",
      mail = NULL,
      otherMails = I(character()),
      officeLocation = "mario.rossi@example.org",
      jobTitle = NULL,
      createdDateTime = "2026-01-01T00:00:00Z",
      accountEnabled = TRUE,
      userType = "Member"
    ),
    list(...)
  )
}


# `auto_unbox = TRUE` is what makes a length-one value a scalar rather than a
# one-element array, which is how Graph writes it; `I()` in the helper above is
# what keeps `otherMails` an array even when it holds exactly one address.
graph_page <- function(users, next_link = NULL) {
  body <- list(value = users)
  if (!is.null(next_link)) body[["@odata.nextLink"]] <- next_link
  charToRaw(as.character(jsonlite::toJSON(body, auto_unbox = TRUE)))
}


test_that("directory_users reads one page and returns the sweep as a frame", {
  # eval
  captured <- NULL
  answer <- httr2::with_mocked_responses(
    function(req) {
      captured <<- req
      httr2::response(
        status_code = 200L,
        headers = list(`Content-Type` = "application/json"),
        body = graph_page(list(
          graph_user(),
          graph_user(
            id = "00000000-0000-0000-0000-000000000002",
            userPrincipalName = "anna.bianchi@ubep.unipd.it",
            otherMails = I("anna.bianchi@example.org"),
            officeLocation = NULL
          )
        ))
      )
    },
    directory_users("t0ken", "https://graph.example.org/v1.0")
  )

  # test
  expect_true(answer[["ok"]])
  expect_equal(answer[["errors"]], character())
  expect_equal(nrow(answer[["users"]]), 2L)

  # The eleven fields are the sweep's contract with the resolution that
  # consumes it: `User.ReadBasic.All` would have been the smaller permission
  # and does not carry four of them, so the select list is also the reason the
  # wider one is asked for. A column dropped here reads downstream as a person
  # who has no contact address, which is `absent` — a verdict, not an error.
  #
  # `givenName` and `surname` are here because the resolution refuses a match
  # whose name diverges from the declared one, and it cannot refuse on a field
  # the sweep never asked for. The historical flow populates both, through
  # `-GivenName` and `-Surname` in `ps1_creators.R`.
  expect_equal(
    names(answer[["users"]]),
    c(
      "id", "userPrincipalName", "givenName", "surname", "mail", "otherMails",
      "officeLocation", "jobTitle", "createdDateTime", "accountEnabled",
      "userType"
    )
  )
  expect_equal(
    answer[["users"]][["userPrincipalName"]],
    c("mario.rossi@ubep.unipd.it", "anna.bianchi@ubep.unipd.it")
  )
  # A field the record does not carry is an empty string and not the word "NA":
  # the second user has no `officeLocation`, and 1.170 accounts on the tenant
  # are in that position.
  expect_equal(
    answer[["users"]][["officeLocation"]],
    c("mario.rossi@example.org", "")
  )
  # `otherMails` is a list column because it is the one selected field that is
  # an array on the wire. Collapsing it into a string would put the resolution
  # in the position of splitting it back apart on a separator that no rule says
  # an address cannot contain.
  expect_equal(answer[["users"]][["otherMails"]][[1]], character())
  expect_equal(
    answer[["users"]][["otherMails"]][[2]], "anna.bianchi@example.org"
  )
  # Each column keeps the type the wire gives it, which is not the same as
  # guessing one: `accountEnabled` is a JSON boolean, so reading it as logical
  # preserves a type rather than inventing it. Carried as the string "FALSE" it
  # would be a value every `if ()` in the package reads as false and every
  # `nzchar()` reads as present.
  expect_type(answer[["users"]][["accountEnabled"]], "logical")
  expect_equal(answer[["users"]][["accountEnabled"]], c(TRUE, TRUE))

  expect_equal(captured[["method"]], "GET")
  # The header has to be revealed to be read, which is the point: httr2 holds
  # a redacted header as a weak reference, so printing the request or dumping
  # it while diagnosing a round cannot spill the credential.
  expect_equal(
    httr2::req_get_headers(captured, "reveal")[["Authorization"]],
    "Bearer t0ken"
  )
  expect_match(
    captured[["url"]],
    paste0(
      "https://graph.example.org/v1.0/users?$select=id,userPrincipalName,",
      "givenName,surname,mail,otherMails,officeLocation,jobTitle,",
      "createdDateTime,accountEnabled,userType&$top=999"
    ),
    fixed = TRUE
  )
})


test_that("directory_users follows @odata.nextLink until the pages run out", {
  # eval
  seen <- list()
  answer <- httr2::with_mocked_responses(
    function(req) {
      seen[[length(seen) + 1L]] <<- req
      if (length(seen) == 1L) {
        httr2::response(
          status_code = 200L,
          headers = list(`Content-Type` = "application/json"),
          body = graph_page(
            list(graph_user()),
            next_link = "https://graph.example.org/v1.0/users?$skiptoken=AAA"
          )
        )
      } else {
        httr2::response(
          status_code = 200L,
          headers = list(`Content-Type` = "application/json"),
          body = graph_page(list(graph_user(
            id = "00000000-0000-0000-0000-000000000002",
            userPrincipalName = "anna.bianchi@ubep.unipd.it"
          )))
        )
      }
    },
    directory_users("t0ken", "https://graph.example.org/v1.0")
  )

  # test
  expect_true(answer[["ok"]])
  expect_equal(nrow(answer[["users"]]), 2L)
  expect_equal(
    answer[["users"]][["userPrincipalName"]],
    c("mario.rossi@ubep.unipd.it", "anna.bianchi@ubep.unipd.it")
  )

  # A page without `@odata.nextLink` is the last one. Two calls and not three
  # is the assertion that says so: a loop that asked once more would be reading
  # the first page again on a server that ignores an unknown skiptoken.
  expect_length(seen, 2L)

  # The continuation is followed as given and not rebuilt. The skiptoken
  # carries the select and the page size with it, and a URL reassembled here
  # would silently start a second sweep from the top of a differently-shaped
  # query.
  expect_equal(
    seen[[2]][["url"]],
    "https://graph.example.org/v1.0/users?$skiptoken=AAA"
  )
  expect_equal(
    httr2::req_get_headers(seen[[2]], "reveal")[["Authorization"]],
    "Bearer t0ken"
  )
})


test_that("a page that fails mid-sweep returns no rows at all", {
  # eval
  seen <- 0L
  answer <- httr2::with_mocked_responses(
    function(req) {
      seen <<- seen + 1L
      if (seen == 1L) {
        httr2::response(
          status_code = 200L,
          headers = list(`Content-Type` = "application/json"),
          body = graph_page(
            list(graph_user()),
            next_link = "https://graph.example.org/v1.0/users?$skiptoken=AAA"
          )
        )
      } else {
        httr2::response(
          status_code = 503L,
          headers = list(`Content-Type` = "application/json"),
          body = charToRaw(
            '{"error":{"code":"serviceNotAvailable","message":"try later"}}'
          )
        )
      }
    },
    directory_users("t0ken", "https://graph.example.org/v1.0")
  )

  # test
  # This is the property the whole sweep rests on. A half-read directory is
  # not a small directory: every account on the pages that did not arrive is
  # missing, and a missing account resolves to `absent` — a verdict that opens
  # the creation branch. Handing back page one would turn a transport failure
  # into duplicate people, which is exactly the failure the design refuses to
  # let a "it will pass by itself next round" reading cover.
  expect_false(answer[["ok"]])
  expect_equal(answer[["errors"]], "TRASPORTO_DIRECTORY_RIFIUTATO")
  expect_null(answer[["users"]])
})


test_that("a continuation that never ends stops instead of looping forever", {
  # eval
  seen <- 0L
  answer <- httr2::with_mocked_responses(
    function(req) {
      seen <<- seen + 1L
      httr2::response(
        status_code = 200L,
        headers = list(`Content-Type` = "application/json"),
        body = graph_page(
          list(graph_user()),
          next_link = "https://graph.example.org/v1.0/users?$skiptoken=AAA"
        )
      )
    },
    directory_users("t0ken", "https://graph.example.org/v1.0")
  )

  # test
  # The measured sweep is 8 pages over 7.664 accounts, so the ceiling is more
  # than ten times the real shape. It exists because the alternative failure is
  # the worst kind this project knows: a round that never returns leaves no
  # record, and `ubep-canale-assenza` reports "the channel is not running"
  # while the channel is running very hard.
  expect_false(answer[["ok"]])
  expect_equal(answer[["errors"]], "TRASPORTO_DIRECTORY_PAGINE_SENZA_FINE")
  expect_null(answer[["users"]])
  expect_equal(seen, 100L)
})


test_that("a continuation pointing elsewhere does not carry the token there", {
  # eval
  seen <- list()
  answer <- httr2::with_mocked_responses(
    function(req) {
      seen[[length(seen) + 1L]] <<- req
      httr2::response(
        status_code = 200L,
        headers = list(`Content-Type` = "application/json"),
        body = graph_page(
          list(graph_user()),
          next_link = "https://elsewhere.example.net/v1.0/users?$skiptoken=AAA"
        )
      )
    },
    directory_users("t0ken", "https://graph.example.org/v1.0")
  )

  # test
  # The continuation is a URL the other end chooses, and following it blindly
  # means handing an application credential to whatever host it names. The
  # sweep refuses instead, and the assertion that matters is the count: the
  # second request is never made, so the token never leaves the endpoint the
  # caller named.
  expect_false(answer[["ok"]])
  expect_equal(answer[["errors"]], "TRASPORTO_DIRECTORY_PAGINA_ALTROVE")
  expect_null(answer[["users"]])
  expect_length(seen, 1L)
})


test_that("an empty directory is an answer and not a failure", {
  # eval
  answer <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(
        status_code = 200L,
        headers = list(`Content-Type` = "application/json"),
        body = graph_page(list())
      )
    },
    directory_users("t0ken", "https://graph.example.org/v1.0")
  )

  # test
  # The case that gets forgotten, and the one a `stopifnot()` would make
  # indistinguishable from a fault. "Nobody matched" is an observation the
  # resolution knows what to do with — every row comes out `absent` — while
  # "I could not ask" must stop it. Collapsing the two would let a broken
  # sweep read as an empty tenant and open the creation branch on everybody.
  expect_true(answer[["ok"]])
  expect_equal(answer[["errors"]], character())
  expect_equal(nrow(answer[["users"]]), 0L)
  expect_equal(
    names(answer[["users"]]),
    c(
      "id", "userPrincipalName", "givenName", "surname", "mail", "otherMails",
      "officeLocation", "jobTitle", "createdDateTime", "accountEnabled",
      "userType"
    )
  )
})


test_that("a 200 that carries no value array is an unexpected answer", {
  # eval
  answer <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(
        status_code = 200L,
        headers = list(`Content-Type` = "application/json"),
        body = charToRaw('{"@odata.context":"$metadata#users"}')
      )
    },
    directory_users("t0ken", "https://graph.example.org/v1.0")
  )

  # test
  # The other half of the pair above. Read as an empty page this would be a
  # directory with nobody in it, reported as a clean read.
  expect_false(answer[["ok"]])
  expect_equal(answer[["errors"]], "TRASPORTO_DIRECTORY_RISPOSTA_INATTESA")
  expect_null(answer[["users"]])
})


test_that("a value that is not an array is an unexpected answer too", {
  # eval
  answer <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(
        status_code = 200L,
        headers = list(`Content-Type` = "application/json"),
        body = charToRaw('{"value":"no users found"}')
      )
    },
    directory_users("t0ken", "https://graph.example.org/v1.0")
  )

  # test
  # This is the case that makes the check on the shape worth more than a check
  # on the name: an absent `value` and an empty one are already told apart by
  # `is.null()`, since an empty JSON array parses to `list()`. A `value` that
  # is present and is not an array is not, and walking it field by field
  # produces a frame of nobody — a clean read of an empty tenant, which is the
  # answer that opens the creation branch on every row of the register.
  expect_false(answer[["ok"]])
  expect_equal(answer[["errors"]], "TRASPORTO_DIRECTORY_RISPOSTA_INATTESA")
  expect_null(answer[["users"]])
})


test_that("a 200 that is not JSON is an unexpected answer and not a sweep", {
  # eval
  answer <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(
        status_code = 200L,
        headers = list(`Content-Type` = "text/html"),
        body = charToRaw("<html><body>Sign in</body></html>")
      )
    },
    directory_users("t0ken", "https://graph.example.org/v1.0")
  )

  # test
  # An endpoint that is not the one meant answers 200 with a page, exactly as
  # an instance with its API switched off does. Recognizing the answer by its
  # shape rather than by its status is what keeps the failure named here
  # instead of surfacing from inside the parser.
  expect_false(answer[["ok"]])
  expect_equal(answer[["errors"]], "TRASPORTO_DIRECTORY_RISPOSTA_INATTESA")
  expect_null(answer[["users"]])
})


test_that("a refusal keeps the Graph code, which is what a diagnosis needs", {
  # eval
  answer <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(
        status_code = 403L,
        headers = list(`Content-Type` = "application/json"),
        body = charToRaw(paste0(
          '{"error":{"code":"Authorization_RequestDenied",',
          '"message":"Insufficient privileges to complete the operation."}}'
        ))
      )
    },
    directory_users("t0ken", "https://graph.example.org/v1.0")
  )

  # test
  # A 403 on every row is the shape the missing consent takes, and it is the
  # one failure the release order was written to avoid. Carrying the code back
  # is what sends whoever reads it to the consent rather than to the network.
  expect_false(answer[["ok"]])
  expect_equal(answer[["errors"]], "TRASPORTO_DIRECTORY_RIFIUTATO")
  expect_null(answer[["users"]])
  expect_equal(
    answer[["payload"]][["code"]], "Authorization_RequestDenied"
  )
})


test_that("an endpoint that cannot be reached is named as such", {
  # eval
  answer <- httr2::with_mocked_responses(
    function(req) stop("connection refused"),
    directory_users("t0ken", "https://graph.example.org/v1.0")
  )

  # test
  expect_false(answer[["ok"]])
  expect_equal(answer[["errors"]], "TRASPORTO_DIRECTORY_NON_RAGGIUNGIBILE")
  expect_null(answer[["users"]])
})


test_that("the token never appears in a URL nor in what comes back", {
  # eval
  seen <- character()
  answer <- httr2::with_mocked_responses(
    function(req) {
      seen <<- c(seen, req[["url"]])
      if (length(seen) == 1L) {
        httr2::response(
          status_code = 200L,
          headers = list(`Content-Type` = "application/json"),
          body = graph_page(
            list(graph_user()),
            next_link = "https://graph.example.org/v1.0/users?$skiptoken=AAA"
          )
        )
      } else {
        # Graph does not echo the credential today. The scrub does not depend
        # on that: relying on it would be trusting the other end to keep our
        # secret, and this body is what it would look like if it stopped.
        httr2::response(
          status_code = 403L,
          headers = list(`Content-Type` = "application/json"),
          body = charToRaw(paste0(
            '{"error":{"code":"InvalidAuthenticationToken",',
            '"message":"CompactToken s3cr3t-t0ken is malformed."}}'
          ))
        )
      }
    },
    directory_users("s3cr3t-t0ken", "https://graph.example.org/v1.0")
  )

  # test
  # The twin of the assertion `test-provisioning-client.R` makes for the
  # module's shared secret, and it has to cover both pages: the first URL this
  # package builds and every continuation it follows. A credential in a query
  # string lands in the access log of the endpoint and of every proxy between,
  # on every round, six times a day.
  expect_length(seen, 2L)
  expect_false(any(grepl("s3cr3t-t0ken", seen, fixed = TRUE)))

  expect_false(any(grepl(
    "s3cr3t-t0ken",
    unlist(answer[["payload"]]),
    fixed = TRUE
  )))
  expect_equal(
    answer[["payload"]][["message"]], "CompactToken  is malformed."
  )
})
