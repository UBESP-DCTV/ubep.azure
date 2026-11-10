# Every seal the channel wrote on a row

The values of `applied_seal` at the channel's executions in the row's
current life,
[`log_executions()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executions.md),
newest first: the first is
[`log_channel_seal()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_seal.md).
What
[`seal_holds_but_revocation()`](https://ubesp-dctv.github.io/ubep.azure/reference/seal_holds_but_revocation.md)
asks to know whether the channel ever carried the row out while it was
active.

## Usage

``` r
log_channel_seals(events, record, channel_account)
```

## Arguments

- events:

  The owners' log, `logtype = "record"`.

- record:

  The record id.

- channel_account:

  The REDCap usernames that hold the round's token, one or more. Not
  `NULL`: without them any account's seal would count.

## Value

A character vector, empty when the channel never sealed the row.
