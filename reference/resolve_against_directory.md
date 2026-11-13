# Ask the swept directory who a register row is talking about

Pure: a function of the row and of the swept directory, in the same
shape as
[`provisioning_diff()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_diff.md)
and
[`scope_errors()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_errors.md).
It reads no network, writes nothing, and knows the register only as a
row.

## Usage

``` r
resolve_against_directory(
  request,
  directory,
  domain = "ubep.unipd.it",
  redcap = NULL
)
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
`known_to_redcap`. The username is what the **directory** says, so it is
empty on every verdict that did not resolve; giving the row back what
its filer typed is
[`resolve_identity()`](https://ubesp-dctv.github.io/ubep.azure/reference/resolve_identity.md),
which is the only caller and the only place that knows whose the value
is.

## Details

**Two queries, not one**, and the whole vocabulary rests on it:
`ambiguous` is read off the number of matches on the identity criterion,
`collision` off the composed UPN being held by somebody else. A resolver
asking one question could not tell `collision` from `absent`, and would
either create a duplicate or take a uniqueness refusal from Entra and
report it as a transport error — that is, as something that will pass by
itself next round. It will not.
