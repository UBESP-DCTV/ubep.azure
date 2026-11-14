# Write the Entra account a row was carried out for, and nothing else

A fifth door, for `applied_entra_id` (item 11 of the 0.27.0), and for
the reason of the owner's: no other field can travel with the
identifier, so a defect in the round cannot rewrite the intent nor move
the seal while saying which account the row was carried out for. The
value is believed from the channel's writes in the log only
([`log_channel_entra_id()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_entra_id.md)),
and the door writes it alone so that its event in the log has the form
that reader takes, `applied_entra_id = '<value>'`.

## Usage

``` r
register_entra_id_import(url, token, payload)
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

  A frame of exactly `record_id`, `applied_entra_id`, as
  [`entra_id_payload()`](https://ubesp-dctv.github.io/ubep.azure/reference/entra_id_payload.md)
  returns. Zero rows calls nobody.

## Value

The
[`register_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_call.md)
list plus `scritte`.
