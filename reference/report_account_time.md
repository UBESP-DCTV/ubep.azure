# Read the date of one `accounts` entry

Read the date of one `accounts` entry

## Usage

``` r
report_account_time(value)
```

## Arguments

- value:

  A string as the module writes it, `NULL` or `""`.

## Value

A `POSIXct` in UTC, `NA` for an absent date, and `NULL` when the value
is there but does not read.
