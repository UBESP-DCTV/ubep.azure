# The writes below a row's newest execution that no approval covered

The stretch
[`log_uncovered_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_uncovered_authors.md)
reads, between the round's newest execution and the one before it (or
the start of the row's current life), and in it the writes of an intent
field by anybody other than whoever owned the row in that stretch, or,
above the newest approval that covers, by the owner of then who is not
the owner of today; a revocation alone is never one of them. Each write
is answered whole, whether or not somebody wrote its fields again since:
[`log_uncovered_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_uncovered_authors.md)
keeps the ones still in the row, and
[`log_change_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_change_authors.md)
reads as unknown a value carried out that one of them wrote.

## Usage

``` r
log_uncovered_writes(
  events,
  record,
  creator,
  fields,
  approvers,
  channel_account
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
  `NULL` when they are not configured.

## Value

The positions of those writes in the row's current life, as
[`log_of_record()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_of_record.md)
returns it, newest first;
[`integer()`](https://rdrr.io/r/base/integer.html) when there are none
or the log holds no execution; `NA_integer_` when the log cannot say,
because the channel or the owner of the stretch is not known.
