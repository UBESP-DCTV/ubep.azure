# Who changed a row since the round last applied it

The people whose writes to an intent field stand between the round's
last execution of the row and now, newest first. The last execution is
the newest event that wrote `applied_seal`, which the round writes only
when it has applied the row, and with the channel's account configured
only an event of the channel counts,
[`log_executions()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executions.md):
what came before it was carried out already, under somebody's
responsibility, and is not the change the round is now asked to carry
out. Where the row's log no longer holds that event the whole history
counts, which can only ask for an approval more often.

## Usage

``` r
log_change_authors(
  events,
  record,
  fields = register_intent_fields(),
  channel_account = NULL,
  current = NULL,
  creator = NULL,
  approvers = character()
)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id to look at.

- fields:

  The intent fields. Passed in by a caller that asks about many rows,
  since deriving them reads the packaged dictionary.

- channel_account:

  The REDCap usernames that hold the round's token, one or more, or
  `NULL` when they are not configured, for
  [`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md).

- current:

  The row as the round will leave it, a data frame of one row holding
  every field in `fields`, or `NULL` when there is no row in hand. Read
  only on a row the round has carried out.

- creator:

  Who created the row, as
  [`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
  answers, for
  [`log_uncovered_writes()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_uncovered_writes.md);
  or `NULL`, and then every newest write below the seal is read as the
  value carried out.
  [`log_pending_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_pending_authors.md),
  the one the round asks, passes it.

- approvers:

  The IT accounts whose approval counts on any row, for
  [`log_uncovered_writes()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_uncovered_writes.md).

## Value

A character vector of usernames, newest first (by the write that counts)
and each once; [`character()`](https://rdrr.io/r/base/character.html)
when no intent field changed, or nobody but the channel changed one;
`NA_character_` when the log cannot say who did.

## Details

Only the writes still in the row count, decided on 2026-10-17 (option
(a) of three). For each intent field whose current value differs from
the one carried out, the author is whoever wrote that field last; a
write somebody other than the channel then overwrote is not part of the
change, and a field brought back to the value carried out is no change
at all. The value carried out is the newest write of the field below the
seal, by anybody, the channel included; where the log holds none it is
unknown, and the field counts if it was written above the seal. It is
unknown as well where that newest write is one the execution did not
cover,
[`log_uncovered_writes()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_uncovered_writes.md)
(decided on 2026-10-17): a change made while the round ran sits below
its seal without having been carried out, and read as the value carried
out it would make a third person who brings the field back to it above
the seal no author at all, so the change would be carried out on the
rights of somebody who did not write it. That reading needs `creator`,
from which the owner of the stretch is read; without it the newest write
below the seal is the value carried out.

The current value comes from the register and not from the log, which
cuts a value at its first apostrophe and would call `D'Angelo` and
`D'Amico` equal. For the same reason a value carried out that holds an
apostrophe is unknown too: read `D`, it would make a later `D` look like
no change.

On a row never carried out there is no value to compare with, and every
intent field written in its life counts, with its last author, empty or
not: an empty field decides what is granted too, an empty `dag_name` a
user in no group, an empty `expiration` an access with no end. The same
holds without the row in hand, `current = NULL`: every field written
since the last execution counts, with its last author.

This is also the way out of a write by somebody who could not have made
it by hand: the owner writes that field again, and the other is no
longer its author. Without it a row touched by mistake would stay held
for ever, since nothing is ever deleted. REDCap logs no write that
leaves the value as it was, so writing again means changing the value
and then putting it back.

"Carried out already" holds for what the round read, and the seal is
written at the end of the round: a change made while the round ran sits
below it and was not.
[`log_uncovered_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_uncovered_authors.md)
looks for those, and
[`log_pending_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_pending_authors.md)
is the two together, which is what the round judges.

The round's own writes are not a change. It writes `username` back when
it resolves it, and `username` is an intent field: counted, the channel
would be an author of every row whose username it settles. Its account
is the one
[`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md)
names, and its events are dropped by account: a field only the channel
wrote since the last execution carries no author. Another account's
write of a field of the channel is no change either, and with the
account configured it is ignored; its write of an intent field,
`username` included, is a change of its author like any other.

Two cases make the answer unknown rather than short, and the caller
holds the row on both. Without the configured account, a second account
writing what only the channel is meant to write,
[`log_channel_unknown()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_unknown.md):
the channel is guessed from those writes, and taking the wrong account
for it would drop its author from the change. And a write that counts
whose author is blank names nobody, which is not the same as naming the
creator.
