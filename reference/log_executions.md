# Which events of a row's log are the round's executions

The writes of `applied_seal`, which the round makes only when it has
applied the row, newest first as the log holds them. With the channel's
account configured only the channel's writes count (decided on
2026-10-17): the import right is open to the referents, and a seal one
of them imported, alone or in the same event as a change, would
otherwise stand as the last execution, and the change below it would
read as carried out. Without the account every write counts, as before:
a second account writing the seal makes the channel unknown,
[`log_channel_unknown()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_unknown.md),
and the callers stop there.

## Usage

``` r
log_executions(events, channel, channel_account)
```

## Arguments

- events:

  The row's events, newest first.

- channel:

  What
  [`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md)
  answered for the row.

- channel_account:

  What it was asked with.

## Value

The positions in `events` of the executions, newest first.

## Details

The channel's event has to have the form of the seals door, too:
`details` holding `applied_seal` and at most `seal_state` beside it,
nothing else. The door has written only those two fields since the seal
exists, and REDCap logs only the fields an import changed. Read by the
field name alone, an outcome of the channel whose `applied_as` quotes a
seal, from a group name somebody chose on the instance, would pass for
an execution and move the boundary above a change.
