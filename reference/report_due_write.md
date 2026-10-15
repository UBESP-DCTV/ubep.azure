# Keep which reports a whole reading of a month found due

Keep which reports a whole reading of a month found due

## Usage

``` r
report_due_write(dir, month, due, at)
```

## Arguments

- dir:

  The job's state directory.

- month:

  The month covered, `"AAAA-MM"`.

- due:

  The names of the reports due, as the ledger records them.

- at:

  When the reading was made, `"%Y-%m-%d %H:%M"` in Rome.

## Value

A list with `ok` and `errors`.
