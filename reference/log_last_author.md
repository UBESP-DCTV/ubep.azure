# Who last wrote one of these fields on this row

Reads `details`, which REDCap fills with the fields an edit touched and
the values it gave them — `role_name = 'read only'` — so the question
"who changed what was asked" is answerable without holding a copy of the
row.

## Usage

``` r
log_last_author(events, record, fields)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id to look at.

- fields:

  Field names to look for in `details`.

## Value

The username, or `""` when no event touched any of those fields.

## Details

The most recent matching event wins, and which one that is comes from
the **order of the answer** rather than from the timestamp: REDCap
stamps the log to the minute, and an edit and the approval that follows
it can easily share one. The order is REDCap's own, newest first.
