# The names to ask each server

For every server the register has rows on, the usernames of its active
and applied rows and of the rows stopped on a disabled account
([`report_stopped_rows()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_stopped_rows.md)).
Blank servers and blank names are left out.

## Usage

``` r
report_server_asks(register)
```

## Arguments

- register:

  The register, as
  [`register_records()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_records.md)
  answers.

## Value

A named list: server to the usernames to ask it, without repetitions.
