# Whether the configured channel never appears in a log it must be in

The whole log, not one row's: `TRUE` when it holds a write of
`applied_seal`, so the channel has run on this register, and no account
in `channel_account` ever wrote a field of the channel,
[`register_channel_fields()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_channel_fields.md).
That is a name typed wrong on the machine, or the token's old account
dropped from the list before the new one wrote anything. Read with it,
every seal and every passage of the channel would be somebody else's:
rows back to their creators, every row with a hand other than the
owner's held. A register where nothing was ever sealed answers `FALSE`:
there is no channel yet to have seen.

## Usage

``` r
log_channel_absent(events, channel_account)
```

## Arguments

- events:

  The owners' log, `logtype = "record"`.

- channel_account:

  The REDCap usernames that hold the round's token, one or more. Not
  `NULL`.

## Value

`TRUE` or `FALSE`.
