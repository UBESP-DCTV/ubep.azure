# Compose the report of a month that did not leave on time

The report of a month lost, sent by the first run that can send. It says
it is late and which month it covers, in the subject and on the first
line, and carries the accesses activated in that month, read from the
log as always. The people to look at depend on the state of today, and
would be the same in every late report: they are only in the report of
the month covered by the run, which this one points to.

## Usage

``` r
report_late_message(attivati, period, month)
```

## Arguments

- attivati:

  The `attivati` of a referent's report for the month lost, rows, or an
  empty data frame for none.

- period:

  What
  [`report_month()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_month.md)
  answered for the run, the month it covers being the one this report
  points to.

- month:

  The month lost, `"AAAA-MM"`.

## Value

A list with `subject`, `body`, `forma` (`in_ritardo`) and `n` (zero:
nobody is listed to look at).
