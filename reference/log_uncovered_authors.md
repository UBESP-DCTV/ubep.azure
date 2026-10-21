# Who changed a row before its last execution without the owner's leave

[`log_change_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_change_authors.md)
drops what stands below the round's newest seal as already carried out.
That holds for what the round **read**, and the seal is written last: an
edit somebody makes while the round sweeps the tenant and talks to the
instances lands below the seal in the log and was never applied. Dropped
with the rest, it would pass for the owner's as soon as the owner edits
the row again.

## Usage

``` r
log_uncovered_authors(
  events,
  record,
  creator,
  fields = register_intent_fields(),
  approvers = character(),
  channel_account = NULL
)
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
  answers; the owners are read from the log with it.

- fields:

  The intent fields.

- approvers:

  The IT accounts whose approval counts on any row.

- channel_account:

  The REDCap usernames that hold the round's token, one or more, or
  `NULL` when they are not configured, for
  [`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md)
  and
  [`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md).

## Value

A character vector of usernames, newest first and each once;
[`character()`](https://rdrr.io/r/base/character.html) when the stretch
holds no uncovered change or the log holds no seal at all;
`NA_character_` when the log cannot say.

## Details

So the stretch between the newest seal and the one before it, both the
round's executions as
[`log_executions()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executions.md)
reads them (or the start of the row's log, its creation when the log
holds it), is read again, for changes by anybody other than whoever
owned the row in that stretch. The round applies such a change only once
the owner has approved it, so one that the round did carry out has the
owner's approval above it in that stretch, carrying the very seal the
execution wrote. A change with no such approval above it is one the
execution did not cover, and it is still part of the change the round is
being asked to carry out.

**The stretch is read with the owner of then**, decided on 2026-10-17:
the newest write of `owned_by` by the channel below the seal that opens
the stretch,
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md),
or the creator when there is none or only one seal. The round that
writes a seal writes `owned_by` below it, so the passage it decided
belongs to the stretch after it. Read with today's owner instead, the
approval of the one before would be a stranger's after a passage, and
the row would be held again with no new change in it.

One write is judged with today's owner as well: one that stands above
the newest approval that covers, written while the round that passes the
row ran, after the approval and before the seal. The outgoing owner who
writes there is not the new owner, and nobody else would name the
change, since
[`log_change_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_change_authors.md)
reads only what stands above the seal. So a write above that approval
counts when its author is not the owner of then or not the owner of
today,
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md)
on the whole log.

**Only the writes still in the row count**, as above the last execution
(decided on 2026-10-17): a write counts for each field it wrote that no
account but the channel's has written since, in the row's current life.
Read whole, an uncovered write by somebody without the rights held the
row for good: the owner who writes the field again brings the row back
to the seal, no round seals it anew, the stretch never moves, and the
gate would ask that somebody's rights at every later change of the
owner's, a revocation included. The value such a write left below the
seal is not the value carried out,
[`log_change_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_change_authors.md),
so whoever writes it again above the seal is the author of that change.

One stretch is enough. An uncovered change makes the next round hold the
row, and a held row writes no seal: the stretch does not move until the
owner approves, and that approval covers the version holding the change.
Writing the field again does not move it: it takes the change out of the
row, and a row back at the seal is not sealed anew.

Two kinds of leave besides the owner's, both from 2026-10-15. An
approval by one of the IT accounts covers as the owner's does, since it
is what carried the change out. And a revocation alone,
`request_status = 'revoked'` and no other intent field, is never
uncovered: it grants nothing, so whether or not the execution above it
carried it out, nothing in it can reach anybody through the owner's next
edit. Counted, it would make the owner approve the reactivation of their
own request after a manager's free revocation.

Unknown, `NA_character_`, when the owner of the stretch is not known,
when the channel is not known,
[`log_channel_unknown()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_unknown.md),
or when an uncovered change still in the row has a blank author: the
caller holds the row on all three. With the channel's account
configured, another account's write of a field of the channel is
ignored, and its write of an intent field is a change like any other.
