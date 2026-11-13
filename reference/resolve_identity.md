# Resolve who a register row is talking about

The door, and the one rule that is about the round rather than about the
directory: **on a verdict that did not resolve, the round erases the
username it wrote itself and keeps the one it did not.**

## Usage

``` r
resolve_identity(request, directory, domain = "ubep.unipd.it", redcap = NULL)
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
  are never written apart. `distinct_username`, when the row carries it,
  is read only to tell `created` from `existing` after a collision
  ([`confirm_identity()`](https://ubesp-dctv.github.io/ubep.azure/reference/confirm_identity.md)).

- directory:

  A directory frame as
  [`directory_users()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_users.md)
  returns.

- domain:

  The tenant's verified domain, defaulting as
  [`compose_upn()`](https://ubesp-dctv.github.io/ubep.azure/reference/compose_upn.md)
  does, so that what counts as an internal address and what a composed
  UPN looks like cannot drift apart.

- redcap:

  What the production instances said about the names this row could be
  created under (decided on 2026-11-10, item 4 (b') of the 0.26.0): a
  list with `asked`, the names the round asked, and `known`, those
  REDCap knows, as an account or as rights on a project. `NULL`, the
  default, judges the directory alone, as before. Read only where the
  verdict could create, `absent` and `collision`: a name REDCap knows is
  taken as a UPN held on Entra is, so a composed name free on Entra and
  known to REDCap is a `collision` (`known_to_redcap`), and the proposal
  skips the names REDCap knows. The proposal is taken from
  [`upn_window()`](https://ubesp-dctv.github.io/ubep.azure/reference/upn_window.md);
  a window not asked whole, or known whole, is no verdict at all,
  `TRASPORTO_NOME_NON_VERIFICATO`: the round creates no name it has not
  found unknown in this pass.

## Value

A list with `identity`, `username`, `errors`, `composed` and
`known_to_redcap`.

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
