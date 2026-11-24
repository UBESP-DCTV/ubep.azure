# The date on which REDCap judges an expiration

REDCap denies access when `expiration <= TODAY`, and its TODAY is the
date of the PHP of the instance, which runs in `Europe/Rome` (measured
on 2026-10-22; edc03 does not set it and runs UTC). The machine of the
round runs UTC, so between 22:00 and 24:00 UTC (23:00 and 24:00 in
winter) its date is the day before Rome's. The gate on the referent's
permission and the last day of a request are compared with this date,
not with [`Sys.Date()`](https://rdrr.io/r/base/Sys.time.html). On edc03
the date in Rome is the later of the two, and in that stretch the gate
refuses a few hours before REDCap would: the direction that does not
grant.

## Usage

``` r
redcap_today(now = Sys.time())
```

## Arguments

- now:

  The instant, [`Sys.time()`](https://rdrr.io/r/base/Sys.time.html) by
  default.

## Value

A `Date`, the day of `now` in Rome.
