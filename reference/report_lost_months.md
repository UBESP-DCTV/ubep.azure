# The months whose reports did not all leave, from the first one covered

A month is lost when its ledger of sent reports lacks any of the reports
its list of the reports due holds, or when no list is on record: a month
the job never read whole. The report to IT
([`report_it_key()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_it_key.md))
is not counted, because what it carries is the state of today and the
report to IT of the month the run covers carries it. A ledger or a list
that does not read leaves its month out, as it would send blind, and
says why.

## Usage

``` r
report_lost_months(dir, month)
```

## Arguments

- dir:

  The job's state directory.

- month:

  The month the run covers: the months checked are those from
  [`report_first_month()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_first_month.md),
  or from the oldest month the directory holds a ledger or a list of,
  whichever is later, up to it, excluded. A directory with none recovers
  nothing.

## Value

A list with `ok`, false when a ledger or a list did not read; `errors`,
`RAPPORTO_INVII_ILLEGGIBILI` and `RAPPORTO_DOVUTI_ILLEGGIBILI`; and
`mesi`, the lost months oldest first, each a list of `mese`, `dovuti`
(as kept, `NULL` when none is) and `ledger` (as
[`report_ledger_read()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_ledger_read.md)
answered).
