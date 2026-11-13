# Whether the expiration a read-back carries is reached on the day of a round

The stored expiration is the day after the last day of access, so it is
reached when it is not later than the day of the round: REDCap, whose
server runs UTC, denies access when `expiration <= TODAY`. The day is
the UTC one of `at`, not the clock of whoever composes the message, so
the same row says the same thing whenever it is read and the tests do
not depend on the machine.
[`validate_request()`](https://ubesp-dctv.github.io/ubep.azure/reference/validate_request.md)
and the choice of `lapsed` read the date of the machine
([`Sys.Date()`](https://rdrr.io/r/base/Sys.time.html)), which is the
same day on a machine in UTC; on one in another zone the two differ
between the midnights, and the message then says "granted" for that
stretch, as the limit of the gate on the last day already does.

## Usage

``` r
mail_expiration_reached(applied_as, at)
```

## Arguments

- applied_as:

  The row's read-back, `role_name=...; dag_name=...; expiration=...`.

- at:

  The time of the round, `"%Y-%m-%d %H:%M"` in UTC.

## Value

`TRUE` when both carry a date and the expiration is not later than the
day of `at`; `FALSE` otherwise, which is the answer for every row that
says nothing readable.
