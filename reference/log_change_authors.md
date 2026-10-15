# Who changed a row since the round last applied it

The people whose writes to an intent field stand between the round's
last execution of the row and now, newest first. The last execution is
the newest event that wrote `applied_seal`, which only the round writes
and only when it has applied the row: what came before it was carried
out already, under somebody's responsibility, and is not the change the
round is now asked to carry out. Where the row's log no longer holds
that event the whole history counts, which can only ask for an approval
more often.

## Usage

``` r
log_change_authors(events, record, fields = register_intent_fields())
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

## Value

A character vector of usernames, newest first and each once;
[`character()`](https://rdrr.io/r/base/character.html) when nobody
changed an intent field; `NA_character_` when the log cannot say who
did.

## Details

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
names, and its events are dropped by account.

Two cases make the answer unknown rather than short, and the caller
holds the row on both. A second account writing what only the channel
writes is nothing anybody planned – a value that happens to read as a
field assignment, an import right granted after all – and taking it for
the channel would drop its author from the change. And an intent write
whose author is blank names nobody, which is not the same as naming the
creator.
