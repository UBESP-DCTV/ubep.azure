# Build the body that writes the Entra account of a row into the register

A fifth door beside the outcome, the identity, the owner and the seal
(item 11 of the 0.27.0), and for the same reason: the columns are fixed
here so a bug cannot rewrite anything else. The value is the `id` of the
Entra account the row was first carried out for, as the sweep reads it.

## Usage

``` r
entra_id_payload(record_id, entra_id)
```

## Arguments

- record_id:

  The register record to write to.

- entra_id:

  The account's identifier, or `""`.

## Value

A one-row data frame with exactly `record_id` and `applied_entra_id`.

## Details

An empty value is accepted, unlike the owner's: the round writes one
only just before the value itself, when the field already shows the
value and the log holds no write of the channel's
([`log_channel_entra_id()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_entra_id.md)),
since REDCap logs no write that leaves a field as it was.
