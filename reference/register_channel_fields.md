# The fields only the channel writes

Every read-only field but `requested_by`, which `@USERNAME` fills in
with the account that creates the row: it is the one read-only field a
person writes. The rest are `@READONLY` on the form, and only the round
is meant to write them.

## Usage

``` r
register_channel_fields()
```

## Value

A character vector of field names.

## Details

Meant, and not guaranteed. `@READONLY` governs the form REDCap draws,
and an import draws none: the import right is open to the referents, and
an import writes these fields as it writes any other. So a write of one
of them does not say by itself that the round made it. The account that
holds the round's token is therefore configured, `channel_account`, and
with it a write of one of these fields by any other account is ignored
([`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md)).
Without it the channel is guessed from who wrote these fields, and two
accounts writing them make the row's log ambiguous.
