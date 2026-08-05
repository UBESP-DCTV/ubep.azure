# Convert a last day of access into the value REDCap stores

REDCap denies access when `expiration <= TODAY`, so the day it holds is
already out. A request that says "access until 31 December" therefore
has to be stored as 1 January. It is a one day error, which is to say
the kind nobody sees until it concerns the last day of a study.

## Usage

``` r
to_redcap_expiration(last_day)
```

## Arguments

- last_day:

  Last day of access, as `YYYY-MM-DD`.

## Value

The value to store, as `YYYY-MM-DD`; `NULL` when `last_day` is `NULL` or
`NA`, i.e. when the request carries no expiration at all.
