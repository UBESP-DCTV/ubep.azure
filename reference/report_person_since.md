# Since when the person a row names now has had its access

The first execution by the channel after the newest write of `username`
in the row's current life. The row's first execution dates the request;
this dates the person. They differ when a modification changed
`username`: the row was activated for somebody, and the person it names
now got the access when the round executed it again. Dated by the row,
that person would count months of somebody else's.

## Usage

``` r
report_person_since(events, record, channel_account = NULL)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id.

- channel_account:

  The REDCap usernames that hold the register's token, one or more, or
  `NULL` when they are not configured, for
  [`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md).

## Value

One stamp, `"%Y-%m-%d %H:%M"` in Rome;
[`character()`](https://rdrr.io/r/base/character.html) when the username
has been written and not executed since; `NA_character_` when the log
cannot say.

## Details

The newest write of `username` is read from the order of the answer,
newest first, like every other reading of the log here; the event that
writes it counts as after it, in case one event wrote both. Every
`username` write counts, the round's own included: the round writes back
the name it resolved, in the same pass and before the seal, so on a row
never modified the answer is its first execution.
