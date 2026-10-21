# Whether each changed row waits for an approval

[`change_needs_approval()`](https://ubesp-dctv.github.io/ubep.azure/reference/change_needs_approval.md)
asked once per row, of the authors the row's log names,
[`log_pending_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_pending_authors.md),
and of whoever owns the row,
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md),
read from the log with the creator the creation log names. Whether the
row carries a seal is read from its `applied_seal`, and the authors are
read against the row as it stands, so a field brought back to the value
carried out names nobody.

## Usage

``` r
seal_needs_approval(
  register,
  events,
  creators,
  approvers = character(),
  channel_account = NULL
)
```

## Arguments

- register:

  The register as read, one row per request, carrying every intent
  field.

- events:

  The event log of the rows that changed, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- creators:

  Who created each row, as
  [`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
  answers, in the order of `register`.

- approvers:

  The IT accounts whose approval counts on any row: it decides what an
  earlier execution covered.

- channel_account:

  The REDCap usernames that hold the round's token, one or more, or
  `NULL` when they are not configured, for
  [`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md)
  and
  [`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md).

## Value

A logical vector, one answer per row. It answers about every row it is
handed, so the caller restricts it to the rows that changed.
