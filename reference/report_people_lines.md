# The lines of the people with no first sign-in, in both languages

One entry for each person and server. After the line with the person and
the date and the line with the server's projects, an entry says what the
referent should know of the account: with a `limite`, that the person
has never signed in with the UBEP account and must by that day, the last
one, or the account is deactivated (D-31); when that day is already
past, that the key handed over may no longer be valid and that a new one
is asked for by replying to the mail of the key, which is what the D-31
rule has for an expired key; without a `limite`, only that the person
never entered the server, since the dates on Entra no longer tell
whether they use the account. An entry read from Entra, because the
server did not answer, says so. Without people, the item says "none".

## Usage

``` r
report_people_lines(people, period, to_it = 0L)
```

## Arguments

- people:

  The `senza_primo_accesso` of a referent's report.

- period:

  What
  [`report_month()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_month.md)
  answered: `oggi` tells whether a `limite` is past.

- to_it:

  How many of the referent's people went to IT without being judged.

## Value

A list of two character vectors, `it` and `en`.
