# Run the monthly report once

**It reads and sends mail, and nothing else.** It does not write in the
register and does not touch Entra: the register is read with the
channel's token, the creations and each active row's log with the same
calls the round makes, the tenant with the round's sweep. That is what
lets it run outside the channel's path, as a job of its own.

## Usage

``` r
provisioning_report(
  register_url,
  register_token,
  graph_token,
  graph_url,
  ledger_dir,
  now = Sys.time(),
  month = NULL,
  mailer = NULL,
  redirect_to = NULL,
  copy_to = NULL,
  channel_account = NULL,
  hosts = character(),
  secrets = character()
)
```

## Arguments

- register_url, register_token:

  The register's host and API token.

- graph_token, graph_url:

  The Microsoft Graph access token and endpoint. Neither has a default,
  as in the round: an empty one is a directory that could not be read,
  and the record says so.

- ledger_dir:

  The job's state directory, where the ledgers live.

- now:

  When the run reads. The month, the day and the hour the mail says it
  read at all come from here.

- month:

  A month `"AAAA-MM"` to cover instead of the one the clock gives, for a
  run by hand; `NULL` otherwise.

- mailer:

  `function(to, cc, subject, body)` returning `ok` and `errors`, or
  `NULL` for no post.

- redirect_to:

  One address replacing every recipient, or `NULL`.

- copy_to:

  The address of IT: in copy on the referents' reports, and the
  recipient of the report to IT.

- channel_account:

  The REDCap username that holds the register's token, the account the
  round writes with, or more than one while the token changes hands.
  With it, only their writes of `owned_by` pass a row to another
  referent and only their seals date a row, and what any other account
  wrote in the channel's fields is ignored; with `NULL`, the default,
  every row belongs to its creator, and the channel is whoever wrote its
  fields. The runner reads it from `UBEP_CANALE_UTENTE`, a list
  separated by commas, which it requires.

- hosts, secrets:

  Named character vectors, server name to host and to the secret of its
  module. A server missing from either, or with an `NA` secret, is not
  read.

## Value

A list that
[`report_record()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_record.md)
turns into the record, plus `rapporti`, one row per report due and per
late report, with the `mese` it covers, for whoever reads a single run;
`server`, what
[`report_server_reads()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_server_reads.md)
answered for each server asked; `recuperati`, the late reports tried (a
data frame of `mese`, `destinatario` and `esito`, `mandato` or
`fallito`); and `mesi_persi`, the months still missing a report after
the round.

## Details

It also asks the instances, `accounts` only, through
[`report_server_reads()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_server_reads.md):
once the register and the directory have read whole, each server the
register has rows on is asked for the people of those rows, the rows
stopped on a disabled account included. A server that is not read stops
nothing and is not an error: it is counted in `istanze_non_lette`, and
the report goes on without what that server would have said.

The job runs every day, because an alarm on logs looks back two days at
most and a monthly job cannot be watched by the absence of a record.
Every day it reads, computes and leaves a record; from the 1st on it
sends the previous month's report to whoever has not received it yet,
until the month is complete. The ledger of what left
([`report_ledger_read()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_ledger_read.md))
is what tells them apart.

A day on which anything it needs could not be read sends nothing: the
register, the creations, the directory, any active row's log, the
month's ledger. An earlier month's ledger that does not read stops
nothing: the people it could hold are told without their earlier
reports. A report composed on half a reading would be wrong for
somebody, and the next day tries again. Such a day also does not know
who is due, so it judges the month on the reports the last whole reading
found due, kept beside the ledger
([`report_due_read()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_due_read.md));
with none on record it says nothing is due, and the alarm on absence is
the one that speaks.

On the 1st the run moves on to the month just ended. A month whose
reports did not all leave is not given up: the first run that can send
(read whole, the post on) sends the late reports of those months first,
oldest first, each saying it is late and carrying the accesses activated
in its own month
([`report_late_message()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_late_message.md)),
and then the report of the month covered. The months checked are those
from
[`report_first_month()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_first_month.md)
up to the month covered, excluded
([`report_lost_months()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_lost_months.md));
a month with no list of the reports due kept takes the referents of
today for it, and keeps them. The report to IT is not recovered, since
it carries the state of today. Each late report that leaves is written
in the ledger of its month. While a month is still missing a report
after the round, the record carries
`RAPPORTO_MESE_PRECEDENTE_INCOMPLETO`, and `in_ritardo` is true.

**The real ledger is written only by a real run**: the post on, nobody
redirected, the month the clock gives. A run with the post off sends
nothing to record. A redirected run is a field test: recorded in the
real ledger, it would make the real month read as sent, and a test at
the end of October would leave nothing to leave on the 1st of November.
So it keeps a ledger of its own, and is idempotent as the real run is:
the timer of a field test does not send everything again every day. A
run with a forced month writes nothing at all. Neither of the two
recovers a month lost: a late report that went to the test address would
be written in the real ledger of its month, and its referent would never
receive it.

The report to IT goes to `copy_to`, the address IT is in copy at on
every outcome, under the name
[`report_it_key()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_it_key.md);
the referents' reports go to the owner's account, with `copy_to` in
copy.

A row goes to its owner as the month covered ended, at midnight in Rome
between its last day and the next month's first, and not to its owner on
the day of the run:
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md)
reads the row's log cut at that moment, so a write after it, of
`owned_by` or of any other field of the channel, changes nothing. The
month's reports leave over several days, until each referent has had
theirs, and who is due must not change from one attempt to the next
(decided on 2026-10-17): read on the day, a row passed on the 3rd would
move from one referent's report to the other referent's between two
attempts, after one of the two had left. Without `channel_account`,
`NULL`, no write of `owned_by` is believed and every row stays with its
creator.
