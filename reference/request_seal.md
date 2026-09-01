# What the round applied, in twelve characters

The seal the round writes beside a row once it has acted on it, and what
the next round compares the row against: a different seal means the row
was modified after it was applied.

## Usage

``` r
request_seal(register)
```

## Arguments

- register:

  The register as read, one row per request.

## Value

A character vector, one seal per row.

## Details

It covers the intent fields and nothing else, and that is the whole
point. A seal that moved when the round wrote the outcome would make
every applied row look modified one round later — the mechanism would
accuse itself, on every row, for ever.

A field the register does not carry is sealed as empty rather than
skipped, so a row exported with a column missing and the same row with
that column blank seal alike. The absence itself is not lost:
[`compare_dictionary()`](https://ubesp-dctv.github.io/ubep.azure/reference/compare_dictionary.md)
reports it as `DIZIONARIO_CAMPO_ASSENTE`, which is where it belongs.

Twelve hex characters, like the surface fingerprint, and for the same
reason: it goes in a text field a person may read aloud.
