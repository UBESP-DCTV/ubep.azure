# Since when the person a row names has had its access

The first execution by the channel of the newest run of executions
carried out for that person's name, in the row's current life. The row's
first execution dates the request; this dates the person. They differ
when a modification changed `username`: the row was activated for
somebody, and the person it names now got the access when the round
executed it again. Dated by the row, that person would count months of
somebody else's.

## Usage

``` r
report_person_since(events, record, channel_account = NULL, username = NULL)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id.

- channel_account:

  The REDCap usernames that hold the register's token, one or more, or
  `NULL` when they are not configured, for
  [`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md).

- username:

  The name to date: the name executed of a stopped row, read by
  [`report_executed_register()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_executed_register.md),
  which can differ from the newest one written; `NULL` for the newest
  one written, the register's.

## Value

One stamp, `"%Y-%m-%d %H:%M"` in Rome;
[`character()`](https://rdrr.io/r/base/character.html) when the newest
execution did not carry out that name, so it was written and not
executed since; `NA_character_` when the log cannot say.

## Details

The name each execution carried out is the newest write of `username` at
or below it, the event itself included, since the round writes back the
name it resolved in the same pass and before the seal. A seal below any
write of the name carried out a name the log does not say, and goes with
any name. Read from the order of the answer, newest first, like every
other reading of the log here.

A run, and not the newest write of the name: a name written and then
written back without an execution in between, the identity door's after
an account renamed on Entra and restored, or a referent's who changed
the name and changed it back, leaves the person with the access they
had, and the row applied again with no new seal (L4). Dated from the
newest write, that person would have no date and would no longer be
judged.
