# Write outcomes back into the register

The register holds two kinds of field and they must never mix: what a
person asked for is intent, what happened is observation, and this
writes only the second.
[`outcome_payload()`](https://ubesp-dctv.github.io/ubep.azure/reference/outcome_payload.md)
fixes the columns; this refuses anything else at the door, so the
separation is a structural property rather than a promise kept by
whoever assembles the body.

## Usage

``` r
register_import(url, token, payload)
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

  A data frame as
  [`outcome_payload()`](https://ubesp-dctv.github.io/ubep.azure/reference/outcome_payload.md)
  returns, one row per record to update. Zero rows is the ordinary quiet
  round and calls nobody.

## Value

The
[`register_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_call.md)
list plus `scritte`, the number of records REDCap reports having taken.

## Details

`overwriteBehavior` is `overwrite` and that is deliberate. The body
carries exactly the five outcome fields, so overwriting can only clear
those; with `normal` an empty `applied_as` would leave the previous one
in place, and a transport error would inherit the read-back of an
earlier success — an outcome that says "it failed" next to a field that
says "here is what it wrote".
