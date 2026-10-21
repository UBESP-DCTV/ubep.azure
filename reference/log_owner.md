# Who a row belongs to, from the log

The value of the newest write of `owned_by` signed by an account that
holds the round's token, in the row's current life; the creator, as
[`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
names it, when none of them ever wrote one.

## Usage

``` r
log_owner(events, record, creator, channel_account = NULL, before = NULL)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id to look at.

- creator:

  Who created the row, as
  [`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
  answers.

- channel_account:

  The REDCap usernames that hold the round's token, one or more, or
  `NULL` when they are not configured.

- before:

  A moment, `"%Y-%m-%d %H:%M"` in Rome and exactly that long, or `NULL`
  to read the whole log. A longer stamp, with seconds, would make a
  write of that same minute count as before it.

## Value

One username; `""` when no write of `owned_by` is believed and the
creator is not known; `NA_character_` when the log cannot say.

## Details

The field itself is not believed. `owned_by` is `@READONLY` on the form,
but an import draws no form: the import right is open to the referents,
and an import writes the field as it writes any other. The log names who
was authenticated for each write, so it says which value the round
wrote, the same principle that names the creator from the log and not
from `requested_by`.

The round's account is configured, decided on 2026-10-17, and without
it, `NULL`, no write of `owned_by` is believed and the row belongs to
its creator; a row whose log names two accounts writing the channel's
fields is unknown then,
[`log_channel_unknown()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_unknown.md).
Recognizing the round by what it writes would hand the row to a referent
who imports `owned_by` alone on a colleague's new row before the round
has written on it. With the account configured, a write of `owned_by` by
any other account is ignored (decided on 2026-10-17): it names nobody,
and the row stays with the owner the channel last wrote, or with its
creator.

One write of another author is not ignored: a write of `owned_by` whose
author is blank or missing, above the channel's write the owner is read
from, or anywhere when there is none. It names nobody either, but it is
not known to be somebody else's: it could be the channel's, so the
answer is unknown, the direction that holds the row.

`before` asks who the row belonged to at a moment, and only what stands
strictly before it counts. It is in the instance's civil time, which is
Rome, the time the log's stamps are in, as for
[`report_executions()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_executions.md):
no conversion can move a write across it. A stamp of the row's log that
does not read as one,
[`log_stamp_reads()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_stamp_reads.md),
makes the answer unknown, since the write it dates could stand on either
side.

The newest write is read from the order of the answer, REDCap's own,
newest first, as everywhere else in the log. A write by the channel that
leaves the field blank names nobody, and the one below it is read.

The value is read whole, and not with
[`log_value()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_value.md),
which stops at the first apostrophe: a UPN can hold one, so
`luca.d'amico` would read `luca.d`, and the round would write that back
as the owner and find it stable. The door writes `owned_by` alone,
[`register_owner_import()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_owner_import.md),
and REDCap logs only the fields an import changed, so the channel's
event is `owned_by = '<value>'` and the value is everything between the
first apostrophe and the last. The form is the one the rest of the log
readers assume, `field = 'value'` with nothing escaped; how REDCap logs
an apostrophe inside a value has not been measured. An event of the
channel that wrote `owned_by` in any other form, beside other fields,
makes the answer unknown: where one value ends and the next begins
cannot be told from an apostrophe inside a name, and an unknown owner is
the direction that holds the row.
