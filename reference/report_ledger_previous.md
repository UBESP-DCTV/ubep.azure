# Read the ledgers of the months before this one

They serve one sentence, the earlier reports that named a person, and a
broken one must not stop every month after it. An unreadable month is
named in `illeggibili`, under `RAPPORTO_STORICO_ILLEGGIBILE`, and the
readable ones are read all the same.

## Usage

``` r
report_ledger_previous(dir, month)
```

## Arguments

- dir:

  The job's state directory.

- month:

  The month covered, `"AAAA-MM"`.

## Value

A list with `ok`, false when a month did not read; `errors`; `invii`,
the entries of every readable earlier month together, oldest month
first; and `illeggibili`, the months that did not read.
