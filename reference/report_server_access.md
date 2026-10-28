# Say whether a person has ever entered a server, and when last

A person is `mai_entrata` when the server has no row for her, when the
row says the account does not exist, or when she has no first visit.
Otherwise she is `entrata`, and the last access is the more recent of
`lastlogin` and `lastactivity`, or `firstvisit` when both are absent.
The name is found without regard to case or to spaces at the edges.

## Usage

``` r
report_server_access(conti, upn)
```

## Arguments

- conti:

  A frame as
  [`report_accounts_frame()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_accounts_frame.md)
  returns it.

- upn:

  The person's user principal name.

## Value

A list with `stato`, `mai_entrata` or `entrata`, and `ultimo`, a
`POSIXct` in UTC, `NA` for `mai_entrata`.
