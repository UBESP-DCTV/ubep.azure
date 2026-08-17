# Resolve who a register row is talking about

The door, and the one rule that is about the round rather than about the
directory: **on a verdict that did not resolve, the round erases the
username it wrote itself and keeps the one it did not.**

## Usage

``` r
resolve_identity(request, directory, domain = "ubep.unipd.it")
```

## Arguments

- request:

  One register row as a named list, carrying `first_name`, `last_name`,
  `contact_email`, `username` and `identity`. The last is the
  **previous** verdict, and it is the only memory `created` needs: a row
  that was `absent` and now matches is one whose account came into being
  because of this request. The memory lives in the register, which is
  where this project keeps memory. It also says what `username` is: a
  claim by whoever filed the row while the verdict is empty, and this
  round's own earlier answer once one sits beside it, because the two
  are never written apart.

- directory:

  A directory frame as
  [`directory_users()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_users.md)
  returns.

- domain:

  The tenant's verified domain, defaulting as
  [`compose_upn()`](https://ubesp-dctv.github.io/ubep.azure/reference/compose_upn.md)
  does, so that what counts as an internal address and what a composed
  UPN looks like cannot drift apart.

## Value

A list with `identity`, `username`, `errors` and `composed`.

## Details

It is the writing half of the rule `51602c1` installed for reading, and
it hangs on the same discriminator, the previous verdict. Read in both
directions it is a single sentence: an empty `identity` means the
`username` beside it belongs to whoever filed the row, and a filled one
means it belongs to the round.

**Why the round must not empty a declaration.** Measured on rows 2 to 4
of the live register on 2026-08-16. Emptying it, the next round reads
the blank as a field the referent left empty – a row an error stops
carries an empty `identity` by construction, so the rule of `51602c1`
never speaks – and decision 12 takes its other branch, fills the
username from the internal contact and finds the account's surname is
another person's. Two different diagnoses reach the referent for a row
they never touched, and the field they are being asked to correct has
been blanked, so the mistake is no longer in front of them.

**Why it must still empty its own.** A row that was `existing` carries
the canonical UPN, which is in the tenant's domain, beside a contact
address which ordinarily is not. Kept past the verdict that backed it,
that value would be read as a declaration on the next pass and closed as
`DATO_RECAPITO_INTERNO_DIVERGENTE` – the referent blamed for a word the
round wrote, which is the oscillation of `51602c1` again with the sides
swapped. Both branches settle in one step.
