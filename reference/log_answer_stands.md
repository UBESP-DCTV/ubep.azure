# Whether a referent's answer to a collision came after the question

The log half of the answer, beside
[`collision_answered()`](https://ubesp-dctv.github.io/ubep.azure/reference/collision_answered.md),
which compares its value with the proposal: the newest write of
`distinct_username` in the row's current life stands above the newest
write of `username` carrying that proposal by the channel, the account
[`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md)
names. The round writes the proposal through the identity door, together
with the verdict `collision`, the first time it finds it, so that write
is the question; an answer below it was written before anybody was
asked.

## Usage

``` r
log_answer_stands(events, record, proposal, channel_account = NULL)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id to look at.

- proposal:

  The proposal the resolution has just made for the row.

- channel_account:

  The REDCap usernames that hold the round's token, one or more, or
  `NULL` when they are not configured, for
  [`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md).

## Value

`TRUE` when the answer stands.

## Details

Decided on 2026-10-27, and the case is the referent who knows the
convention of the suffixes and fills the field in when the row is filed,
or imports it already filled, without having looked at who holds the
composed name. The answer has to be written again after the proposal;
REDCap logs no write that leaves a value as it was, so writing again
means emptying the field and pasting the proposal anew.

Who wrote the answer is not asked here: it is an intent field, so its
author is an author of the row,
[`log_change_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_change_authors.md),
and the row waits for its owner when it is somebody else.

The proposal and the value in the log are folded as addresses are, on
both sides. The order is REDCap's, newest first, as everywhere else in
the log. A log that cannot say which account is the channel,
[`log_channel_unknown()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_unknown.md),
holds no answer.
