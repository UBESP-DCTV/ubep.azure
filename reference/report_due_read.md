# Read which reports the last whole reading of a month found due

A day that cannot read the register, the directory or a row's log does
not know who is due, and judging the month on that would make a month
already sent look late, or a late one look done. So every run that reads
whole keeps the list of the reports due beside the ledger, and a run
that cannot judges on it. Who is due, and nothing about them: the list
holds the names the ledger holds.

## Usage

``` r
report_due_read(dir, month)
```

## Arguments

- dir:

  The job's state directory.

- month:

  The month covered, `"AAAA-MM"`.

## Value

A list with `ok`, `errors` and `dovuti`, `NULL` when no whole reading of
the month is on record.
