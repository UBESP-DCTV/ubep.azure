# The names to ask each server

For every server the register has rows on, the usernames of the rows the
referents' reports count, of the rows stopped with an access executed
and of the rows stopped on a disabled account
([`report_scope()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_scope.md)).
Read on the register with the names executed,
[`report_executed_register()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_executed_register.md):
a stopped row is asked about the account that has the access, and one
whose name executed is not known about nobody. Blank servers and blank
names are left out.

## Usage

``` r
report_server_asks(register)
```

## Arguments

- register:

  The register, as
  [`register_records()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_records.md)
  answers, or with the names executed.

## Value

A named list: server to the usernames to ask it, without repetitions.
