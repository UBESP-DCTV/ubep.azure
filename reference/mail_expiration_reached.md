# Whether the expiration a read-back carries is reached on the day of a round

The stored expiration is the day after the last day of access, so it is
reached when it is not later than the day of the round: REDCap denies
access when `expiration <= TODAY`, and its TODAY is the date in Rome,
[`redcap_today()`](https://ubesp-dctv.github.io/ubep.azure/reference/redcap_today.md).
The day is the one in Rome of the instant `at`, not the clock of whoever
composes the message, so the same row says the same thing whenever it is
read and the tests do not depend on the machine. The round takes the
date it hands to
[`validate_request()`](https://ubesp-dctv.github.io/ubep.azure/reference/validate_request.md),
the choice of `lapsed` and the gate from the same instant, `at`, so
between 22:00 and 24:00 UTC, when the date in Rome is already the next
day, the message and the gate agree with REDCap. A round whose day in
Rome turns before it writes to an instance acts on nothing there. One
whose day turns after the write, while its messages leave, still tells
them on the day of `at`, the day the access was granted.

## Usage

``` r
mail_expiration_reached(applied_as, at)
```

## Arguments

- applied_as:

  The row's read-back, `role_name=...; dag_name=...; expiration=...`.

- at:

  The time of the round, `"%Y-%m-%d %H:%M"` in UTC. A bare date is read
  as the day itself.

## Value

`TRUE` when both carry a date and the expiration is not later than the
day of `at`; `FALSE` otherwise, which is the answer for every row that
says nothing readable.
