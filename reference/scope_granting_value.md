# The value of REDCap's user_rights permission that grants management

REDCap stores this permission as an integer, and only one value means
"may manage the users of this project". Anything else refuses, including
a value a future REDCap adds: a third value would have to be read before
it is trusted, and reading it as "close enough to one" is how a
permission gets widened by an upgrade nobody connected to this file.

## Usage

``` r
scope_granting_value()
```

## Value

The integer that grants.

## Details

Measured on 2026-08-14, not assumed: on a REDCap 17.3.3 instance the
channel serves, 33 pairs reported this permission and it took exactly
two values — 25 ones and 8 zeros. So on the version in exercise there is
no third value to decide about, and this constant is a fact rather than
a guess. The paragraph above is what happens when that stops being true.
