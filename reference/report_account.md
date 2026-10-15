# Find an account in the directory, and say whether it is usable

Compared without regard to case or to spaces at the edges: a REDCap
username and a UPN name the same account in two systems that do not
agree on capitals.

## Usage

``` r
report_account(directory, upn)
```

## Arguments

- directory:

  A directory frame, as
  [`directory_users()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_users.md)
  returns it.

- upn:

  The account's user principal name.

## Value

A list with `stato`, one of `attivo`, `disabilitato`, `non_trovato` and
`non_giudicabile`, and `riga`, the row of the account in `directory` or
`NA`.
