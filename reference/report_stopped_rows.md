# The rows stopped on a disabled account

A row that is active and was stopped by the round because the account of
its person is disabled: `transport_error` with
`TRASPORTO_ACCOUNT_DISATTIVATO` among its codes. `outcome_detail` can
carry more than one code, so the code is looked for inside the field and
not compared with it. These rows are not in the report, but their people
are among the names the report asks the servers for, so that IT can see
them.

## Usage

``` r
report_stopped_rows(register)
```

## Arguments

- register:

  The register, as
  [`register_records()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_records.md)
  answers.

## Value

The rows of `register` that are active and stopped on a disabled
account.
