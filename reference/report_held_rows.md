# The rows stopped with an access executed, for IT

`ferma` of
[`report_scope()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_scope.md):
the rows the channel executed and that then stopped, active or revoked:
a revocation stopped is one not carried out. The access executed stays
on the instance until the row is applied again or its revocation is.
Read on the register with the names executed,
[`report_executed_register()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_executed_register.md),
so that each row names the account that has the access.

## Usage

``` r
report_held_rows(register, owners = NULL)
```

## Arguments

- register:

  The register, with the names executed when known.

- owners:

  Whom each row belongs to, in the register's order, as
  [`report_owners()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_owners.md)
  answers; `NULL` for nobody known.

## Value

The rows, with `creator`, the owner, added.
