# Send the late reports of one month lost

Each report that left is written in the ledger of its month, as if it
had left on time, with the date of the run and the two tables empty:
what it named is not what the month after reads back. A ledger that
cannot be written stops the month, as in the month the run covers, and
what it did not try counts as failed.

## Usage

``` r
report_recover(batch, mailer, complete, copy_to, dir, at)
```

## Arguments

- batch:

  What
  [`provisioning_report()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_report.md)
  composed for one lost month: `mese`, `ledger`, `pendenti` (who has not
  received it) and `rapporti` (their messages, by name).

- mailer, copy_to:

  As in
  [`provisioning_report()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_report.md);
  IT is in copy.

- complete:

  Whether the run read whole and the ledger of the month it covers read
  too. Without it nothing leaves, the reports count as failed, and the
  late ones are tried again on the next run.

- dir:

  The job's state directory.

- at:

  When the run read, `"%Y-%m-%d %H:%M"` in Rome.

## Value

A list with `rapporti`, a data frame of `mese`, `destinatario` and
`esito` (`mandato`, `fallito` or `non_mandato`), and `errors`.
