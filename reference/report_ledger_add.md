# Add one sent report to a month's ledger

Written after the send and never before, as the channel writes into the
register only after the message left: the price accepted is a report
sent twice when the write fails, never one that is lost. The file is
replaced whole,
[`report_write_json()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_write_json.md).

## Usage

``` r
report_ledger_add(dir, month, ledger, entry)
```

## Arguments

- dir:

  The job's state directory.

- month:

  The month covered, `"AAAA-MM"`.

- ledger:

  The ledger as read, from
  [`report_ledger_read()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_ledger_read.md),
  which also says whether it is a redirected run's.

- entry:

  A list of `destinatario`, `at`, and `senza_primo_accesso` and
  `senza_accessi`, each a data frame of `upn` and `server`, or absent.

## Value

A list with `ok`, `errors` and `ledger`, the ledger with the entry when
it was written and as it was otherwise.
