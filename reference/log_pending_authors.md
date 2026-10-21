# Who has a hand in the version the round is asked to carry out

The changes since the round's last execution,
[`log_change_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_change_authors.md),
and the changes below it that the execution did not cover,
[`log_uncovered_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_uncovered_authors.md).
What
[`change_needs_approval()`](https://ubesp-dctv.github.io/ubep.azure/reference/change_needs_approval.md)
judges, and what the held message names.

## Usage

``` r
log_pending_authors(
  events,
  record,
  creator,
  fields = register_intent_fields(),
  approvers = character(),
  channel_account = NULL,
  current = NULL
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

- channel_account:

  The REDCap usernames that hold the round's token, one or more, or
  `NULL` when they are not configured, for
  [`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md).

- current:

  The row as the round will leave it, a data frame of one row, or `NULL`
  when there is no row in hand, for
  [`log_change_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_change_authors.md).

## Value

A character vector of usernames, each once; `NA_character_` when either
half cannot say.
