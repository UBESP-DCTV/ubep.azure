# How far apart an account's two dates may be and still mean "never in"

Sixty seconds, decided on 2026-10-15 after one measurement: an account
the round created on 2026-10-08 carried `createdDateTime` and
`lastPasswordChangeDateTime` equal to the second six days later, and its
person said they had not signed in yet. The key is born in the call that
makes the account, so the two dates differ only by what Entra takes to
write them; the round creates every account with the change of key
forced at first sign-in, so a person who has signed in has moved the
second date.

## Usage

``` r
report_tolerance()
```

## Value

Seconds.

## Details

Confirmed on 2026-10-16 over the enabled accounts of the tenant: the
accounts known never to have been used sit at 0 seconds, none falls
between 1 and 30, a handful between 31 and 120; an account made by hand
on the portal and used once sits at 172.

One value, in one place: a later measurement changes it in one line.
