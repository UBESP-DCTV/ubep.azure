# Whether a closed row revoked differs from its closure by the channel's name

RF1 and RF4 of the review of the correction of F1 of the 0.29.0, way (b)
restricted, decided on 2026-11-25, beside the way (a) of the identity
door. A closed row is sealed by its closure under the empty name. A
round that writes the name on it and does not seal the row (on the row
set back to active, a round stopped or held; under the 0.28.0, a round
that did not act), followed by the owner putting the row back to
revoked, leaves the row differing from the closure by that name alone,
written by the channel: the round would hold it with no author, and ask
its owner to approve the channel's own write while the revocation waits.

## Usage

``` r
log_closure_named_by_channel(events, record, row, seal, channel_account = NULL)
```

## Arguments

- events:

  The row's log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id to look at.

- row:

  The row as read, a data frame of one row.

- seal:

  The seal the round believes for the row.

- channel_account:

  The REDCap usernames that hold the round's token, one or more, or
  `NULL` when they are not configured.

## Value

`TRUE` or `FALSE`.

## Details

`TRUE` only when all of these hold, and the caller asks it only of a
closed row whose change has no author,
[`log_pending_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_pending_authors.md):

- the channel's account is configured and the row asks for `revoked`;

- the row as read, with its name emptied, gives the seal the round
  believes, the closure's: every other intent field is the closure's;

- in the row's log, above the newest execution, every write of
  `username` is the channel's, and the newest one wrote the name the row
  holds.

It only lets a revocation go on: a row that asks for an access, or with
any other difference from the closure, or a name written by anybody
else, is judged as before.
