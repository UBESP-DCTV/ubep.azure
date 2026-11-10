# The pair a row's last execution carried out, from the log

The value each of `fields` had in the version the round last carried
out: the newest write of the field below the round's newest execution,
[`log_executions()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executions.md),
in the row's current life, by anybody, the channel included. The
creation carries the fields a referent filled in, `server = 'edc10'`,
and the identity door the username the round resolved, which it writes
before the seal in the same pass. A write below the seal that the
execution did not cover,
[`log_uncovered_writes()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_uncovered_writes.md),
is passed over: made while the round ran, it holds a value the round had
not read, and the one below it is what was carried out.

## Usage

``` r
log_executed_values(
  events,
  record,
  creator,
  fields = c("server", "project_id", "username"),
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
  answers, for
  [`log_uncovered_writes()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_uncovered_writes.md).

- fields:

  The fields to read.

- approvers:

  The IT accounts whose approval counts on any row.

- channel_account:

  The REDCap usernames that hold the round's token, one or more, or
  `NULL` when they are not configured.

## Value

A character vector named by `fields`, `NA` where the log does not say:
the row was never carried out in its current life, the log holds no
write of the field below the seal, the stretch below the seal cannot be
read, or the channel is not known.

## Details

The value is read whole, up to the apostrophe that closes it, the one
followed by the next field or by the end of `details`: a UPN can hold an
apostrophe, and cut at the first one `luca.d'amico` would read `luca.d`.
Meant for `server`, `project_id` and `username`, whose values never hold
the text `', name = '` that would end them early.
