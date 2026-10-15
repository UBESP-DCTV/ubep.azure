# Who changed a row before its last execution without the creator's leave

[`log_change_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_change_authors.md)
drops what stands below the round's newest seal as already carried out.
That holds for what the round **read**, and the seal is written last: an
edit somebody makes while the round sweeps the tenant and talks to the
instances lands below the seal in the log and was never applied. Dropped
with the rest, it would pass for the creator's as soon as the creator
edits the row again.

## Usage

``` r
log_uncovered_authors(
  events,
  record,
  creator,
  fields = register_intent_fields(),
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

- creator:

  Who created the row, as
  [`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
  answers.

- fields:

  The intent fields.

- approvers:

  The IT accounts whose approval counts on any row.

## Value

A character vector of usernames, newest first and each once;
[`character()`](https://rdrr.io/r/base/character.html) when the stretch
holds no uncovered change or the log holds no seal at all;
`NA_character_` when the log cannot say.

## Details

So the stretch between the newest seal and the one before it (or the
start of the row's log, its creation when the log holds it) is read
again, for changes by anybody other than the creator. The round applies
such a change only once the creator has approved it, so one that the
round did carry out has the creator's approval above it in that stretch,
carrying the very seal the execution wrote. A change with no such
approval above it is one the execution did not cover, and it is still
part of the change the round is being asked to carry out.

One stretch is enough. An uncovered change makes the next round hold the
row, and a held row writes no seal: the stretch does not move until the
creator approves, and that approval covers the version holding the
change.

Two kinds of leave besides the creator's, both from 2026-10-15. An
approval by one of the IT accounts covers as the creator's does, since
it is what carried the change out. And a revocation alone,
`request_status = 'revoked'` and no other intent field, is never
uncovered: it grants nothing, so whether or not the execution above it
carried it out, nothing in it can reach anybody through the creator's
next edit. Counted, it would make the creator approve the reactivation
of their own request after a manager's free revocation.

Unknown, `NA_character_`, when the creator is not known, when two
accounts write the channel's fields, or when an uncovered change has a
blank author: the caller holds the row on all three.
