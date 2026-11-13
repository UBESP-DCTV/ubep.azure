# The usernames the channel carried out on a row while it was active

For each of the channel's executions in the row's current life,
[`log_executions()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executions.md),
the version that execution sealed, rebuilt from the log below it and
verified by its seal,
[`log_executed_row()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executed_row.md);
of those, the usernames of the versions whose `request_status` is not
`revoked`. They are the names the channel gave an access to on this row:
an execution of such a version brought its pair onto the instance. Not
`revoked` rather than `active`, as
[`register_to_desired()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_to_desired.md)
reads the field: a row imported without the state, which the form
requires and the API does not, is served as active and sealed with the
state empty (U8e of the review, 2026-11-12).

## Usage

``` r
log_granted_names(events, record, channel_account)
```

## Arguments

- events:

  The owners' log, `logtype = "record"`.

- record:

  The record id.

- channel_account:

  The REDCap usernames that hold the round's token, one or more. Not
  `NULL`: without them any account's seal would count.

## Value

A character vector of usernames as carried out, each once (folded as
addresses are); empty when the channel never carried the row out active,
or the log does not say.

## Details

What
[`revocation_exits()`](https://ubesp-dctv.github.io/ubep.azure/reference/revocation_exits.md)
asks, decided on 2026-11-12 after the review of unit G (RC1): the
channel also seals a request withdrawn before its person was created,
without asking any instance, and under the name the round would have
created, a collision's proposal among them. That seal covers a name
nobody was ever given, which may later be another person's; the row
never granted it, and must not take it away. The guard of item 7,
[`seal_holds_but_revocation()`](https://ubesp-dctv.github.io/ubep.azure/reference/seal_holds_but_revocation.md),
asks the same question of the seal alone; here the name is asked too, so
a revocation carried out together with another change (the role, say),
whose revoked version was never sealed active, still finds the name it
was given at an earlier execution.

A version the log does not verify names nobody: the answer can only be
shorter, the direction that revokes less.
