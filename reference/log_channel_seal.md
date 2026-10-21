# The seal the channel last wrote on a row, from the log

The value of the round's last execution,
[`log_executions()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executions.md),
in the row's current life: the seal of the version the round last
carried out. What the round compares the row against to tell whether it
changed since, with the channel's account configured (decided on
2026-10-17), in place of the `applied_seal` field. The field is
`@READONLY` on the form and written by an import as any other: a
referent who changes a row and imports the seal of the changed row, a
public hash, would make it look untouched, and the change would be
carried out on the owner's rights. The log names who wrote each seal, as
it names who wrote each owner.

## Usage

``` r
log_channel_seal(events, record, channel_account)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id to look at.

- channel_account:

  The REDCap usernames that hold the round's token, one or more. Not
  `NULL`: without them the round reads the field.

## Value

One seal; `""` when the channel never sealed the row in its current
life, which makes it a row never carried out.
