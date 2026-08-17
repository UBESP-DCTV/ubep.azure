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
resolve_against_directory(request, directory, domain = "ubep.unipd.it")
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

A list with `identity`, `username` and `errors`. The username is what
the **directory** says, so it is empty on every verdict that did not
resolve; giving the row back what its filer typed is
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
