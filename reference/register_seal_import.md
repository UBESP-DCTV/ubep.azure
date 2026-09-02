# Write the seals back, and nothing else

Write the seals back, and nothing else

## Usage

``` r
register_seal_import(url, token, payload)
```

## Arguments

- url:

  Hostname of the instance hosting the register, optionally followed by
  the path REDCap is mounted under. A scheme is dropped rather than
  honored, so a base handed over as http is corrected instead of
  silently downgrading the channel.

- token:

  The API token of the service account, sent in the body.

- payload:

  A frame of exactly `record_id`, `applied_seal`, `seal_state`.

## Value

The
[`register_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_call.md)
list plus `scritte`.
