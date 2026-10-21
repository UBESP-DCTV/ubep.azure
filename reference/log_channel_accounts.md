# Which accounts in a row's log are the channel

The account that holds the round's token, as the machine that runs the
round configures it (more than one while the token changes hands), and
nobody else; or, where it is not configured, every account that wrote a
field only the channel is meant to write,
[`register_channel_fields()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_channel_fields.md),
in the row's current life. Callers drop the channel's events by account,
and read the answer one more way through
[`log_channel_unknown()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_unknown.md):
without the configuration, two accounts writing those fields leave the
log unable to say which writes are the round's.

## Usage

``` r
log_channel_accounts(events, record, channel_account = NULL)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id to look at.

- channel_account:

  The REDCap usernames that hold the round's token, one or more, or
  `NULL` when they are not configured.

## Value

A character vector of usernames. With `channel_account`, every spelling
of those accounts the row's log carries, and each configured name the
log does not carry; nobody else. Without, the authors of the channel
fields, empty when no event wrote one of them.

## Details

It has to be recognized by the account and not by the event. REDCap logs
only the fields an import changed, so when the round writes back a
username it resolved and the verdict has not moved, the event carries
`username` alone – an intent field, written by the channel, with nothing
in the event itself to say so.

The account is configured, decided on 2026-10-17. Recognized by what it
writes alone, the channel is whoever wrote a channel field, and the
import right is open to the referents: one who imports `owned_by` on a
colleague's new row, before the round has written on it, would be the
only "channel" of that row. Named by the configuration, the channel is
the round's account even on a row where it has not written yet, and **a
write of a channel field by any other account is ignored** (decided on
2026-10-17, replacing the ambiguity this function used to answer). Such
a write no longer makes the row ambiguous: the log never forgets it, so
an ambiguous row was held for ever, even one whose referent imported by
mistake a CSV carrying the channel's columns; and with the account named
there is nothing to guess, since the owner comes only from that
account's writes of `owned_by`,
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md).
A write of an intent field by another account stays a change of its
author,
[`log_change_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_change_authors.md),
the channel's columns beside it or not.

More than one account can be configured, for the day the account that
holds the token changes (decided on 2026-10-17): every one of them is
the channel, so the old account's writes, its passages of `owned_by`
among them, stay believed while it is listed.

The configured names are typed by hand on the machine, so they are
compared without regard to case, and answered with the spelling the log
carries when the log carries it. Without them, `NULL`, the answer is the
authors of the channel fields, as before the account was configured:
what the round judges does not change for a caller that does not pass
it, and
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md)
believes no write of `owned_by`.
