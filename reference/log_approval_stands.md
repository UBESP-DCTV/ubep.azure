# Whether the newest approval in a row's log still stands

The log half of
[`seal_approved()`](https://ubesp-dctv.github.io/ubep.azure/reference/seal_approved.md):
the newest write of `approved_seal` is the creator's, or one of the IT
accounts', and nothing it could not have seen stands above it.

## Usage

``` r
log_approval_stands(
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

`TRUE` when the approval stands.

## Details

- **No execution above it.** The newest write of `applied_seal` is the
  round's last execution, and an approval below it was the one that
  execution carried out, or one older still. Either way it is spent.

- **No change by anybody else above it.** An intent field written by an
  account that is neither the creator nor the channel, or by a blank
  account, after the approval, is a change the approval cannot have
  seen: written before the change, the approval is a seal computed in
  advance.

The creator's own edits above it do not withdraw it here. They move the
seal, and the value check in
[`seal_approved()`](https://ubesp-dctv.github.io/ubep.azure/reference/seal_approved.md)
is what refuses an approval of a version the creator changed afterwards.

The order is REDCap's, newest first, as everywhere else in the log.
