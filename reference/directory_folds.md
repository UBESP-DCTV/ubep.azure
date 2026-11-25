# The directory folded once, for every row of a round

What the resolution and the check of the Entra account compute from the
swept directory alone, whatever the row: the candidates, surnames and
given names folded with `clean_string()`, the contact addresses of every
account, the UPNs and the identifiers normalized. A round asked them
once per register row, and on a directory of thousands of accounts that
was most of the round (measured for the 0.28.0: a quarter of a second
for each row, linear in the rows). Computed here they are the same
values, from the same functions, once.

## Usage

``` r
directory_folds(directory)
```

## Arguments

- directory:

  A directory frame as
  [`directory_users()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_users.md)
  returns.

## Value

An environment with `directory`, the directory itself, and `rows`,
`candidate`, `surnames`, `givens`, `contacts`, `contact_values`,
`contact_rows`, `upns` and `ids`.

## Details

Each value is computed the first time it is read, and kept: a promise
per field,
[`delayedAssign()`](https://rdrr.io/r/base/delayedAssign.html). So
nothing is computed that the old order did not compute, and in the same
order: a row that stops before the directory is looked at reads none of
it, and a directory one of these functions refuses
([`directory_contacts()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_contacts.md)
on columns it cannot line up) stops the round where it stopped it
before.

Read only by
[`directory_named()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_named.md),
[`resolve_against_directory()`](https://ubesp-dctv.github.io/ubep.azure/reference/resolve_against_directory.md),
[`entra_account_change()`](https://ubesp-dctv.github.io/ubep.azure/reference/entra_account_change.md)
and
[`entra_fill()`](https://ubesp-dctv.github.io/ubep.azure/reference/entra_fill.md),
each of which takes it as an argument that defaults to folding the
directory it is given: a caller that does not pass it gets what it
always got. Valid only for the directory it was made from, which is why
only
[`provisioning_reconcile()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_reconcile.md)
passes one, made from the sweep it hands to the same calls. The
directory is kept in the folds, and
[`resolve_against_directory()`](https://ubesp-dctv.github.io/ubep.azure/reference/resolve_against_directory.md),
[`entra_account_change()`](https://ubesp-dctv.github.io/ubep.azure/reference/entra_account_change.md)
and
[`entra_fill()`](https://ubesp-dctv.github.io/ubep.azure/reference/entra_fill.md)
stop when the one they are handed is not
[`identical()`](https://rdrr.io/r/base/identical.html) to it: on the
same object the comparison ends at the pointers.
