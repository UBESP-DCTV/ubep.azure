# Whom each row belonged to as a month ended

The owner is read on the row's log cut at midnight in Rome between the
last day of the month and the first of the next: `before` cuts the
writes of `owned_by` only, and without the channel's account a second
account writing a channel field after it would still make the row
ambiguous. A stamp that does not read stays, and the owner is unknown,
as on the whole log. A row whose log was not read keeps its creator.

## Usage

``` r
report_owners(logs, ids, creators, month, channel_account = NULL)
```

## Arguments

- logs:

  One element per row, in the register's order: the row's log, or `NULL`
  where it was not read.

- ids:

  The rows' record ids.

- creators:

  Whom each row was made by, as
  [`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
  names them.

- month:

  The month covered, `"AAAA-MM"`.

- channel_account:

  As in
  [`provisioning_report()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_report.md).

## Value

A character vector, one owner for each row, `""` where none is
established.
