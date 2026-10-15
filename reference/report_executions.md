# When the channel executed a row, from the row's own log

The date of activation is the channel's **first** write of
`applied_seal`, and not `outcome_at`: the outcome is rewritten at every
outcome, so a row that went from `applied` to `transport_error` and back
would look activated twice. Only the round writes the seal, and only
when it has applied the row; a row executed again after an approved
change writes a new one, which is how the report tells a modified
request from a new one.

## Usage

``` r
report_executions(events, record)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id.

## Value

The stamps of the channel's seal writes, `"%Y-%m-%d %H:%M"` in Rome,
oldest first; [`character()`](https://rdrr.io/r/base/character.html)
when there is none; `NA_character_` when the log cannot say.

## Details

The events are filtered here by `record`, whatever REDCap did with the
parameter. Measured on 2026-10-16 that `exportLogging` honors it; the
filter stays, at no cost, because an instance that ignored it would hand
back the whole log, where another row's execution would date this one.

The author has to be the channel, which
[`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md)
names without configuration. When two accounts write the channel's
fields the log cannot say which of them executed the row, and the answer
is unknown rather than a guess.

Only the row that stands now is read. The register reuses record ids:
one made for a field test, deleted on 2026-09-01 with the rest and made
again as a real request, has both lives in its log, and the old one's
seal would date the new request months before it existed, and make its
first execution read as a change.
[`log_of_record()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_of_record.md)
keeps the row's current life only, from its newest creation on, as for
the round, and the channel's account is recognized on that.

The stamps stay in the instance's civil time, which is Rome: measured on
2026-09-01, a round at 21:03 UTC is logged at 23:03, and again on
2026-10-16, a first seal logged at 22:04 beside an `outcome_at` of 20:03
UTC. A month is then the first seven characters of the stamp, and no
conversion can shift a row activated on the last evening of the month
into the next one.
