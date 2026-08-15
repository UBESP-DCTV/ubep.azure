# The directory a test hands the resolution is built through the same function
# the real sweep builds it with. A frame assembled by hand here would be a
# second opinion about the shape of the first, and the day the two diverge the
# resolution would be tested against a directory that never arrives.
dir_user <- function(...) {
  utils::modifyList(
    list(
      id = "00000000-0000-0000-0000-000000000001",
      userPrincipalName = "mario.rossi@ubep.unipd.it",
      givenName = "Mario",
      surname = "Rossi",
      mail = NULL,
      otherMails = list(),
      officeLocation = "mario.rossi@example.org",
      jobTitle = NULL,
      createdDateTime = "2026-01-01T00:00:00Z",
      accountEnabled = TRUE,
      userType = "Member"
    ),
    list(...)
  )
}

dir_frame <- function(...) {
  directory_frame(list(...))
}

# One register row, with the six fields the resolution reads.
a_request <- function(...) {
  utils::modifyList(
    list(
      record_id = "1",
      first_name = "Mario",
      last_name = "Rossi",
      contact_email = "mario.rossi@example.org",
      username = "",
      identity = ""
    ),
    list(...)
  )
}


test_that("one match on a member is existing, and the UPN becomes canonical", {
  # eval
  answer <- resolve_identity(a_request(), dir_frame(dir_user()))

  # test
  expect_equal(answer[["identity"]], "existing")
  expect_equal(answer[["username"]], "mario.rossi@ubep.unipd.it")
  expect_equal(answer[["errors"]], character())
})


test_that("a match whose previous verdict was absent is created", {
  # eval
  # `created` carries no memory of its own: it is the row that was `absent`
  # last round and now has exactly one match, so the account came into being
  # because of this request. The memory lives in the register, which is where
  # this project keeps memory, and not in a local store — decision 4 of the
  # channel's design forbids the second.
  answer <- resolve_identity(
    a_request(identity = "absent"),
    dir_frame(dir_user())
  )

  # test
  expect_equal(answer[["identity"]], "created")
  expect_equal(answer[["username"]], "mario.rossi@ubep.unipd.it")
})


test_that("no match and a free UPN is absent, with no username proposed", {
  # eval
  answer <- resolve_identity(
    a_request(),
    dir_frame(dir_user(
      userPrincipalName = "anna.bianchi@ubep.unipd.it",
      givenName = "Anna", surname = "Bianchi",
      officeLocation = "anna.bianchi@example.org"
    ))
  )

  # test
  expect_equal(answer[["identity"]], "absent")
  expect_equal(answer[["username"]], "")
})


test_that("an empty directory is absent for everybody and not an error", {
  # eval
  answer <- resolve_identity(a_request(), dir_frame())

  # test
  # The sweep that read nothing never reaches here: `directory_users()` hands
  # back no frame at all on a failure, precisely so that "I could not ask"
  # cannot arrive dressed as an empty tenant.
  expect_equal(answer[["identity"]], "absent")
  expect_equal(answer[["errors"]], character())
})


test_that("no match but the composed UPN is taken is a collision", {
  # eval
  # Two people with the same name. Nobody carries this contact address, so as
  # far as we know this person is not in the tenant — but the UPN we would
  # compose already belongs to somebody else.
  answer <- resolve_identity(
    a_request(),
    dir_frame(dir_user(officeLocation = "someone.else@example.org"))
  )

  # test
  expect_equal(answer[["identity"]], "collision")
  # The proposal is what makes a collision workable: without it the row hands
  # a person two questions and no material. With it one question is left, and
  # it is the one only the referent can close.
  expect_equal(answer[["username"]], "mario.rossi.2@ubep.unipd.it")
})


test_that("a collision proposal takes the first free suffix, not always .2", {
  # eval
  answer <- resolve_identity(
    a_request(),
    dir_frame(
      dir_user(officeLocation = "someone.else@example.org"),
      dir_user(
        id = "00000000-0000-0000-0000-000000000002",
        userPrincipalName = "mario.rossi.2@ubep.unipd.it",
        officeLocation = "another.one@example.org"
      ),
      dir_user(
        id = "00000000-0000-0000-0000-000000000003",
        userPrincipalName = "mario.rossi.3@ubep.unipd.it",
        officeLocation = "a.third.one@example.org"
      )
    )
  )

  # test
  expect_equal(answer[["identity"]], "collision")
  expect_equal(answer[["username"]], "mario.rossi.4@ubep.unipd.it")
})


test_that("more than one match is ambiguous, and proposes nothing", {
  # eval
  # Measured on the tenant: 99 contact addresses appear on more than one
  # account, 221 accounts involved, about 3% of the population. This branch is
  # not written for completeness — it will fire.
  answer <- resolve_identity(
    a_request(),
    dir_frame(
      dir_user(),
      dir_user(
        id = "00000000-0000-0000-0000-000000000002",
        userPrincipalName = "mario.rossi.old@ubep.unipd.it"
      )
    )
  )

  # test
  expect_equal(answer[["identity"]], "ambiguous")
  # Nothing to propose: the answer picks between accounts that already exist,
  # and no UPN changes. The question belongs to the referent.
  expect_equal(answer[["username"]], "")
})


test_that("the contact is matched in otherMails as well as officeLocation", {
  # eval
  # `officeLocation` is where the historical flow put it, on 6.494 accounts;
  # `otherMails` is where this package writes it from now on. Both are read,
  # and the fallback retires when the sweep counts zero of the first — a
  # number, not an intention.
  answer <- resolve_identity(
    a_request(),
    dir_frame(dir_user(
      otherMails = I("mario.rossi@example.org"),
      officeLocation = NULL
    ))
  )

  # test
  expect_equal(answer[["identity"]], "existing")
})


test_that("the comparison normalizes, because 74 accounts carry spaces", {
  # eval
  # An `eq` on the service side would have missed these in silence and
  # reported `absent` for people who exist — which is the verdict that opens
  # the creation branch. Reading the directory whole is what makes the
  # comparison ours, and therefore able to normalize at all.
  answer <- resolve_identity(
    a_request(contact_email = "  Mario.Rossi@Example.ORG "),
    dir_frame(dir_user(officeLocation = " mario.rossi@example.org  "))
  )

  # test
  expect_equal(answer[["identity"]], "existing")
})


test_that("a guest carrying the same address is not a candidate", {
  # eval
  # The tenant has 760 guests and they carry their external address in
  # `otherMails`, which is one of the two fields searched. A guest matching
  # alongside a member would produce an `ambiguous` that is not an ambiguity.
  answer <- resolve_identity(
    a_request(),
    dir_frame(
      dir_user(),
      dir_user(
        id = "00000000-0000-0000-0000-000000000002",
        userPrincipalName = "mario.rossi_example.org#EXT#@ubep.onmicrosoft.com",
        otherMails = I("mario.rossi@example.org"),
        officeLocation = NULL,
        userType = "Guest"
      )
    )
  )

  # test
  expect_equal(answer[["identity"]], "existing")
  expect_equal(answer[["username"]], "mario.rossi@ubep.unipd.it")
})


test_that("a match whose name diverges stops the row instead of granting", {
  # eval
  answer <- resolve_identity(
    a_request(),
    dir_frame(dir_user(givenName = "Anna", surname = "Bianchi"))
  )

  # test
  # Decision 7 of the contract seen from the other side: granting to a person
  # other than the one meant. The row does not fall through to `absent`
  # either, which would create an account whose contact address belongs to
  # somebody else -- and mail that person the credential.
  expect_equal(answer[["identity"]], "")
  expect_equal(answer[["username"]], "")
  expect_equal(answer[["errors"]], "DATO_NOME_DIVERGENTE")
})


test_that("the name comparison folds case and accents, as the UPN does", {
  # eval
  answer <- resolve_identity(
    a_request(first_name = "  nicolò ", last_name = "DE ROSSI"),
    dir_frame(dir_user(givenName = "Nicolo", surname = "De Rossi"))
  )

  # test
  # Same normalizer the UPN is composed with, so what counts as the same name
  # here and what the composed UPN looks like cannot drift apart.
  expect_equal(answer[["identity"]], "existing")
})


test_that("a match with no name at all is not confirmable, and stops", {
  # eval
  answer <- resolve_identity(
    a_request(),
    dir_frame(dir_user(givenName = NULL, surname = NULL))
  )

  # test
  # A name that is absent does not diverge -- but it does not confirm either,
  # and the name is the only thing that confirms here. Addressed to IT and not
  # to the referent: whoever filed the request cannot fill in an attribute on
  # a directory account, and telling them "you are not authorized" sends the
  # one person who cannot fix it to go and argue.
  expect_equal(answer[["identity"]], "")
  expect_equal(answer[["errors"]], "TRASPORTO_NOME_NON_LEGGIBILE")
})


test_that("a match we cannot classify as member or guest stops the row", {
  # eval
  answer <- resolve_identity(
    a_request(),
    dir_frame(dir_user(userType = NULL))
  )

  # test
  # It stayed a candidate so that it could not silently become "nobody
  # matched", which would have created a second account for a person who
  # already has one. Having matched, it still does not grant: it could be a
  # guest, and the invariant admits no guests.
  expect_equal(answer[["identity"]], "")
  expect_equal(answer[["errors"]], "TRASPORTO_TIPO_UTENTE_NON_LEGGIBILE")
})


test_that("an alias the account carries confirms it, and the UPN replaces it", {
  # eval
  answer <- resolve_identity(
    a_request(username = "M.Rossi@unipd.it"),
    dir_frame(dir_user(mail = "m.rossi@unipd.it"))
  )

  # test
  # The comparison is between identities and not between strings. An alias, an
  # `@unipd.it` address that is the same institution but not the tenant's
  # domain, a shared mailbox: divergence between the UPN and an address the
  # same person writes from is ordinary, and refusing it would refuse the
  # ordinary case.
  expect_equal(answer[["identity"]], "existing")
  expect_equal(answer[["username"]], "mario.rossi@ubep.unipd.it")
})


test_that("a declared UPN the account does not carry is the filer's error", {
  # eval
  answer <- resolve_identity(
    a_request(username = "anna.bianchi@unipd.it"),
    dir_frame(dir_user())
  )

  # test
  # The row now carries two incompatible claims of identity, and this one is
  # the filer's: only they know which human they meant.
  expect_equal(answer[["identity"]], "")
  expect_equal(answer[["errors"]], "DATO_UTENTE_DICHIARATO_DIVERSO")
})


test_that("an internal contact and a different internal username diverge", {
  # eval
  answer <- resolve_identity(
    a_request(
      contact_email = "mario.rossi@ubep.unipd.it",
      username = "m.rossi@ubep.unipd.it"
    ),
    dir_frame(dir_user())
  )

  # test
  # Whoever holds an address in the domain uses it, and that is where we write
  # to them. An internal contact different from the UPN would describe a person
  # who receives mail at one address and authenticates with another, which does
  # not exist in the tenant.
  expect_equal(answer[["errors"]], "DATO_RECAPITO_INTERNO_DIVERGENTE")
})


test_that("the internal rule holds in the other direction too", {
  # eval
  answer <- resolve_identity(
    a_request(username = "mario.rossi@ubep.unipd.it"),
    dir_frame(dir_user())
  )

  # test
  # Declared internal, contact external: the rule is stated in both directions,
  # so this is the same badly filled row seen from the other end.
  expect_equal(answer[["errors"]], "DATO_RECAPITO_INTERNO_DIVERGENTE")
})


test_that("an internal contact with no username fills it in and confirms it", {
  # eval
  answer <- resolve_identity(
    a_request(contact_email = "mario.rossi@ubep.unipd.it"),
    dir_frame(dir_user())
  )

  # test
  # Nothing to compose: the address is the UPN. It resolves by being found as
  # one, which is why the criterion reads the UPN alongside the two contact
  # carriers.
  expect_equal(answer[["identity"]], "existing")
  expect_equal(answer[["username"]], "mario.rossi@ubep.unipd.it")
})


test_that("an internal contact that matches nobody is a typo, not an absence", {
  # eval
  answer <- resolve_identity(
    a_request(contact_email = "mario.rossii@ubep.unipd.it"),
    dir_frame(dir_user(
      userPrincipalName = "anna.bianchi@ubep.unipd.it",
      givenName = "Anna", surname = "Bianchi",
      officeLocation = "anna.bianchi@example.org"
    ))
  )

  # test
  # The one place `absent` is suppressed, and it is counter-intuitive: the
  # general rule says "not there, so create", and here it says "not there, so
  # somebody mistyped". An address in the domain that does not exist is a typo,
  # and creating it would fabricate the account the typo describes.
  expect_equal(answer[["identity"]], "")
  expect_equal(answer[["errors"]], "DATO_RECAPITO_INTERNO_INESISTENTE")
})


test_that("an external contact that matches nobody stays absent", {
  # eval
  answer <- resolve_identity(
    a_request(contact_email = "mario.rossi@phd.units.it"),
    dir_frame(dir_user(
      userPrincipalName = "anna.bianchi@ubep.unipd.it",
      givenName = "Anna", surname = "Bianchi",
      officeLocation = "anna.bianchi@example.org"
    ))
  )

  # test
  # The ordinary case, and the branch above would eat it if it were written
  # one comparison too wide. Somebody from outside is not a row to refuse: the
  # invariant says "or we create them one and they use that", so it is a row
  # to create.
  expect_equal(answer[["identity"]], "absent")
  expect_equal(answer[["errors"]], character())
})


test_that("a row with no contact address has no criterion, and says so", {
  # eval
  answer <- resolve_identity(a_request(contact_email = ""), dir_frame())

  # test
  # `absent` here would create an account for a row that carries no address to
  # send the credential to. The field is required on the form; the API is not
  # the form.
  expect_equal(answer[["identity"]], "")
  expect_equal(answer[["errors"]], "DATO_RECAPITO_ASSENTE")
})


test_that("the internal typo is named even when a homonym holds the UPN", {
  # eval
  answer <- resolve_identity(
    a_request(contact_email = "mario.rossii@ubep.unipd.it"),
    dir_frame(dir_user(officeLocation = "someone.else@example.org"))
  )

  # test
  # The order between the two suppressed branches, which the design leaves
  # open because it names only `absent`. Both stop the row, so nothing is
  # granted either way -- what differs is the sentence a person reads. "There
  # is already a mario.rossi, is it the same person?" sends them to look at a
  # homonym who has nothing to do with the problem; the problem is that the
  # address they typed is not in the domain they think it is.
  expect_equal(answer[["identity"]], "")
  expect_equal(answer[["errors"]], "DATO_RECAPITO_INTERNO_INESISTENTE")
})


test_that("the gate admits only a confirmed identity", {
  # test
  expect_true(identity_actionable("existing"))
  expect_true(identity_actionable("created"))
  expect_false(identity_actionable("absent"))
  expect_false(identity_actionable("collision"))
  expect_false(identity_actionable("ambiguous"))
})


test_that("the gate refuses the empty verdict, which is the case of today", {
  # test
  # `identity` is empty on every row of the live register, because nothing has
  # ever written it. A gate that admitted the empty one would be a gate that
  # admits everything the day it is switched on, and it is the case that gets
  # forgotten precisely because it is the current one.
  expect_false(identity_actionable(""))
  expect_false(identity_actionable(NA_character_))
  # No rows, no answers: the gate is a per-row question, so an empty column
  # gets an empty verdict rather than a scalar `FALSE` that would then be
  # recycled against something.
  expect_equal(identity_actionable(character()), logical(0))
})


test_that("the gate folds case and spaces, and answers per row", {
  # eval
  verdicts <- c(" Existing ", "AMBIGUOUS", "created", "")

  # test
  # Read straight out of a register column, so it meets whatever REDCap hands
  # back rather than a value this package normalized on the way in.
  expect_equal(
    identity_actionable(verdicts), c(TRUE, FALSE, TRUE, FALSE)
  )
})
