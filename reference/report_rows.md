# The rows a month's report speaks about, with their creator and their date

A row counts while it is an access: `request_status` is `active` and
`outcome` is `applied`. The filter is on the request and not on the
outcome alone, because a revocation the round carried out closes with
`applied` too; and any other outcome is not an access, and has had its
own mail already.

## Usage

``` r
report_rows(register, creators, executions, period, since = NULL, born = NULL)
```

## Arguments

- register:

  The register as read.

- creators:

  Who created each row, as
  [`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
  answers, in the register's order.

- executions:

  One element per row, in the register's order: what
  [`report_executions()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_executions.md)
  answered, or `NULL` where the log was not read.

- period:

  What
  [`report_month()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_month.md)
  answered.

- since:

  One element per row, what
  [`report_person_since()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_person_since.md)
  answered, or `NULL` to date the person by the row's first execution.

- born:

  When each row was made, as
  [`report_born()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_born.md)
  answers, in the register's order; `NULL` when unknown.

## Value

The kept rows of `register`, with `creator`, `attivata_il`, `nel_mese`,
`senza_data`, `data_motivo`, `persona_dal` and `creata_il` added.

## Details

Of those, a row activated after the month covered waits for the next
report, and every other one is kept. `nel_mese` says what the month did
to it: `attivata` when its first execution falls in the month,
`modificata` when it was executed again in the month after a change,
`""` otherwise.

A row whose log was read and does not date it is kept with `senza_data`:
it is applied and the log does not say since when, which is a question
for IT. `data_motivo` says which of the two ways: `senza_sigillo`, no
seal written by the channel; `log_ambiguo`, the channel's fields written
by more than one account, so that which one executed the row is unknown.
The two send IT to look for different things. A row whose log could not
be read is left out, since it cannot be judged on a reading that did not
happen; the caller sends nothing on such a day.
