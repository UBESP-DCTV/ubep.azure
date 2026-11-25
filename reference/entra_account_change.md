# Whether the Entra account a row was carried out for moved

Item 11 of the 0.27.0 (decided on 2026-11-12). The username a row was
carried out for is compared with the account whose identifier the
channel wrote at the first execution, `applied_entra_id`, against the
sweep whole, guests included: a username is unique in the tenant, not
among its members.

## Usage

``` r
entra_account_change(
  executed_username,
  believed_id,
  directory,
  revoked = FALSE,
  folds = directory_folds(directory)
)
```

## Arguments

- executed_username:

  The username the row was carried out for.

- believed_id:

  The identifier believed, never empty.

- directory:

  The sweep, as
  [`directory_users()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_users.md)
  returns it.

- revoked:

  Whether the row asks for `revoked`.

- folds:

  The sweep folded,
  [`directory_folds()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_folds.md),
  made from `directory`; by default folded here.

## Value

A list with `code`, one of the two codes or `""`, and `upn`, the
username the account of the identifier carries now when it was renamed,
`""` otherwise.

## Details

- The username carried out is another account's, one with another
  identifier: `TRASPORTO_NOME_RIASSEGNATO`, unless the row is revoked. A
  revoked row governs its pair, and taking away is the direction that
  does not grant.

- Nobody carries the username carried out, and the account of the
  identifier is in the sweep under another username:
  `TRASPORTO_ACCOUNT_RINOMINATO`, with that username.

- Nobody carries it and the identifier is not in the sweep, the account
  deleted and its name not given again: nothing,
  [`pair_change()`](https://ubesp-dctv.github.io/ubep.azure/reference/pair_change.md)
  decides as before.

- The username carried out is the account of the identifier: nothing.

- Two accounts with the same username, or with the same identifier, a
  sweep this package does not understand: nothing.

Pure: the caller asks only on a row whose version carried out is
certain, with an identifier believed, and that does not leave by
[`revocation_exits()`](https://ubesp-dctv.github.io/ubep.azure/reference/revocation_exits.md).
