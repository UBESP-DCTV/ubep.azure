# Whether what somebody other than the owner wrote is a revocation alone

The half of the revocation exception that the log answers, for
[`change_needs_approval()`](https://ubesp-dctv.github.io/ubep.azure/reference/change_needs_approval.md).
Since the round's last execution, every write to an intent field by an
account that is neither the owner nor the channel wrote
`request_status = 'revoked'` and no other intent field; and there is at
least one such write, or there is no withdrawal by somebody else to
free. The owner is the one the row has now,
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md):
after a passage the creator's withdrawal is somebody else's.

## Usage

``` r
log_revocation_only(
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
  answers; the owner is read from the log with it.

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

`TRUE` when the others wrote a revocation and nothing else; `FALSE` too
when the owner is not known, or the channel,
[`log_channel_unknown()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_unknown.md).

## Details

A change below the newest execution that the execution did not cover,
[`log_uncovered_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_uncovered_authors.md),
makes the answer `FALSE`. That stretch is the rare case of an edit made
while a round ran, and reading it for its fields as well would buy
nothing but code: the row waits for the owner, as it would have before
the exception existed.
