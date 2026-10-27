# Decide whether the single match really is the person the row means

A match on the contact address is where the confirmation starts, not
where it ends. Three things can stop it, and the prefix on each is a
delivery address rather than a label: `DATO_` closes the row against
whoever filed it and mails them, `TRASPORTO_` keeps it queued and mails
us.

## Usage

``` r
confirm_identity(account, declared, previous, answer = "")
```

## Arguments

- account:

  The single matching row of the directory frame.

- declared:

  The declared UPN, normalized and possibly filled in from an internal
  contact address. Empty once a verdict exists on the row, because then
  the register's `username` is this round's own earlier answer and not a
  declaration to confirm.

- previous:

  The previous verdict, normalized.

- answer:

  The row's `distinct_username`, normalized: the referent's answer to a
  collision, `""` when there is none.

## Value

A list with `identity`, `username` and `errors`.

## Details

A confirmed match on an account whose `accountEnabled` is false is
`disabled` and not `existing`: the person is there and cannot sign in,
so granting a right would mail them an access they cannot use. The UPN
goes with the verdict, as a collision's proposal does, because it names
the account IT has to enable. Only a false value counts: the sweep
always asks for the field, and a missing one is an account this package
cannot judge, not one somebody turned off, so it is judged as it was
before the field was read. A row that was `absent` and finds its account
disabled loses the memory of `created`; enabled again, it resolves
`existing`.

The two `TRASPORTO_` ones are fields the account does not carry, and
neither is the filer's to fix. Telling the one person who cannot reach a
directory attribute that they are not authorized sends them to go and
argue — which is the same reasoning
[`scope_errors()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_errors.md)
gives for its fourth case.

`created` has a second road, decided on 2026-10-27: a row that was
`collision` and finds the account its referent's answer asked for, the
answer equal to the UPN found. That account too came into being because
of this request. Nothing the round does tells `created` from `existing`,
so the difference is only in the minutes.
