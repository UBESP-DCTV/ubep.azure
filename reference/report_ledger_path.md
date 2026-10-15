# Where a month's ledger of sent reports lives

A redirected run keeps a ledger of its own, beside the real one: a field
test is then as idempotent as the real thing, and does not send
everything again every day, without making the real month read as sent.

## Usage

``` r
report_ledger_path(dir, month, collaudo = FALSE)
```

## Arguments

- dir:

  The job's state directory.

- month:

  The month covered, `"AAAA-MM"`.

- collaudo:

  Whether the ledger is a redirected run's.

## Value

A path.
