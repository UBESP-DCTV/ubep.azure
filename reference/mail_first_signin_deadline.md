# The last day a new account's first sign-in is promised

A key handed over for a new account is valid for at least 60 days from
the creation of the account, or from the last reset by IT; after that it
may no longer work. The welcome and the message with the key tell a
date, and this is the one place it is computed.

## Usage

``` r
mail_first_signin_deadline(created_at)
```

## Arguments

- created_at:

  The moment the account was born, as Graph writes `createdDateTime`:
  ISO 8601 in UTC, `2026-10-23T10:00:00Z`, with or without fractions of
  a second. Nothing may follow the final `Z`: an offset read as UTC
  would move the birth by hours, and the date with it.

## Value

The date as `YYYY-MM-DD`, or `NA_character_` if `created_at` is not in
that form: a wrong deadline is worse than a missing one.

## Details

The day the account was born in the calendar of Rome, plus 59. Rome
because that is the day the person lives in: an account born at 23:30
UTC is born the next day for them. 59 and not 60 because "by" a date is
read as "up to that day included", while the key can stop working at any
hour of the sixtieth day. Written `YYYY-MM-DD`, like every other date
the messages carry, which reads the same in both languages.

It counts from the birth of the account and not from the round: the
round reads its clock before it sweeps, and the account is born minutes
later.
