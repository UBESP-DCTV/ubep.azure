# Whether the newest approval in a row's log still stands

The log half of
[`seal_approved()`](https://ubesp-dctv.github.io/ubep.azure/reference/seal_approved.md):
the newest write of `approved_seal` is the owner's,
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md),
or one of the IT accounts', and nothing it could not have seen stands
above it. An owner the log cannot establish, or a blank one, approves
nothing, and no approval stands where the log cannot say which account
is the channel,
[`log_channel_unknown()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_unknown.md).

## Usage

``` r
log_approval_stands(
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

`TRUE` when the approval stands.

## Details

- **No execution above it.** The newest write of `applied_seal`, by the
  channel when its account is configured
  ([`log_executions()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executions.md)),
  is the round's last execution, and an approval below it was the one
  that execution carried out, or one older still. Either way it is
  spent. A seal another account imported executed nothing, and spends
  nothing.

- **No change by anybody else above it.** An intent field written by an
  account that is neither the owner nor the channel, or by a blank
  account, after the approval, is a change the approval cannot have
  seen: written before the change, the approval is a seal computed in
  advance.

The owner's own edits above it do not withdraw it here. They move the
seal, and the value check in
[`seal_approved()`](https://ubesp-dctv.github.io/ubep.azure/reference/seal_approved.md)
is what refuses an approval of a version the owner changed afterwards.

The order is REDCap's, newest first, as everywhere else in the log.
