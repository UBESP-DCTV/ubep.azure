# Write the row owner back, and nothing else

The door exists so that no other field can travel with the owner: a
defect in the round must not be able to rewrite the intent a person
asked for, nor move the seal that says what was applied, while saying
whose a row is.

## Usage

``` r
register_owner_import(url, token, payload)
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

  A frame of exactly `record_id`, `owned_by`, as
  [`owner_payload()`](https://ubesp-dctv.github.io/ubep.azure/reference/owner_payload.md)
  returns. Zero rows calls nobody.

## Value

The
[`register_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_call.md)
list plus `scritte`.
