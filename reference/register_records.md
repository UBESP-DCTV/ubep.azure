# Read every record of the register

Asks for the raw codes rather than the labels. Measured on 2026-08-14
the two coincide on all four coded fields, 24 choices out of 24, so the
choice is indifferent — and it is asked for anyway, because a convention
that holds today is not a convention the caller should depend on
silently.

## Usage

``` r
register_records(url, token)
```

## Arguments

- url:

  Hostname of the instance hosting the register, optionally followed by
  the path REDCap is mounted under. A scheme is dropped rather than
  honored, so a base handed over as http is corrected instead of
  silently downgrading the channel.

- token:

  The API token of the service account, sent in the body.

## Value

The
[`register_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_call.md)
list plus `records`, a data frame.
