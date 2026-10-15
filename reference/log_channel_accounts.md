# Which accounts in a row's log are the channel

The authors of the events that wrote a field only the channel writes,
[`register_channel_fields()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_channel_fields.md).
No configuration names the account that holds the round's token, and
none is needed: on any row the round has applied the log carries at
least the write of its seal, and that write is signed by that account.

## Usage

``` r
log_channel_accounts(events, record)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id to look at.

## Value

A character vector of usernames, empty when no event wrote one of those
fields.

## Details

It has to be recognized by the account and not by the event. REDCap logs
only the fields an import changed, so when the round writes back a
username it resolved and the verdict has not moved, the event carries
`username` alone – an intent field, written by the channel, with nothing
in the event itself to say so.
