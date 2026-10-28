# Put each row in the report it belongs to

A row belongs to **its owner**, as the log says, and not to
`requested_by`, which an import writes as it likes: the creator, or the
referent the round has since passed the row to by writing `owned_by`
([`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md)).
The column is still called `creator`, from before rows could pass. The
owner is the one standing at the end of the month covered, which
[`provisioning_report()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_report.md)
settles before it gets here. The report goes to the same person the
round asks to approve a change. A person asked for by two referents is
in both reports, each with their own rows.

## Usage

``` r
report_assemble(
  rows,
  directory,
  period,
  previous = list(),
  unread = character(),
  servers = list(),
  stopped = NULL
)
```

## Arguments

- rows:

  What
  [`report_rows()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_rows.md)
  answered.

- directory:

  A directory frame, as
  [`directory_users()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_users.md)
  returns it.

- period:

  What
  [`report_month()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_month.md)
  answered.

- previous:

  The entries of the earlier months' ledgers, as
  [`report_ledger_previous()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_ledger_previous.md)
  reads them.

- unread:

  The earlier months whose ledger did not read. A person who could have
  been in one of their reports gets `storia_nota` false, and the mail
  says nothing about earlier reports rather than something false.

- servers:

  What the readings of the servers answered, as
  [`report_server_reads()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_server_reads.md)
  returns it: a named list, server to
  `list(letto = TRUE, conti = <frame>)` or
  `list(letto = FALSE, motivo)`. A server that is not there, or that
  says it was read without a frame of accounts, is a server that was not
  read.

- stopped:

  The rows stopped on a disabled account, as
  [`report_stopped_rows()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_stopped_rows.md)
  answers, or `NULL` for none. They are not in the referents' reports:
  IT gets them.

## Value

A list with `referenti`, one report per referent named after them, each
a list of `referente`, `attivati` (rows), `scadenze` (the rows of the
referent that expire after the day of the reading and by the last day of
its month, by date, for information), `senza_primo_accesso` (pairs of
person and server, with `nome`, `upn`, `server`, `progetti`,
`attivata_il`, `giorni`, `mesi`, `segnalata`, `storia_nota`, `fonte` and
`limite`), `senza_accessi` (pairs, with `nome`, `upn`, `server`,
`progetti`, `ultimo`, the day of the last access in Italian time, and
`attivata_il`), `senza_accessi_gia` (how many pairs an earlier report
named and are still without access), `senza_accessi_gia_coppie` (those
pairs, `upn` and `server`, for the ledger) and `non_controllati` (a
frame of `server` and `coppie`), and `non_giudicati` (a count); `it`,
`NULL` when there is nothing for IT, otherwise a list of
`senza_referente` (rows, with `motivo`), `non_giudicabili` (people, with
`referente` and `motivo`), `senza_data` (rows) and `server_non_letti` (a
frame of `server`, `motivo`, `entra`, how many pairs of that server went
into a referent's report on the strength of Entra, and
`non_controllate`, how many were candidates for the year without access
and could not be checked; one row for each server that was asked and not
read, whether the rows on it are applied or stopped, also with none) and
`disattivati` (the rows of `stopped`, with `entrata`: `"si"` or `"no"`,
whether the person has entered the server, when it was read, `""` when
it was not); and `senza_creatore`, how many rows have no referent to go
to. Since rows can pass, that means without an established owner and not
only without a creator; the name stays, because it is a column of
`UbepRapporto_CL`, and a renamed column would keep the table's history
under one name and the new records under another.

## Details

Three items, of which the report fills two:

- **activated in the month**, one line per request, new or modified. It
  is information, and does not count among the things to look at. A new
  one says whether its account was new: `account` is `nuovo` when Entra
  made the account no earlier than the minute the row was made
  (`creata_il`), `esistente` when earlier, `""` when either date is
  missing;

- **no first sign-in**, one item per person and server, with the
  projects of the person on that server: the requests of that person on
  that server activated at least
  [`report_grace_days()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_grace_days.md)
  before the reading and not expired, when the person has never entered
  the server. The thirty days run from the later of two dates, in
  Italian time: the channel's first execution for the username the row
  names now
  ([`report_person_since()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_person_since.md)),
  and the birth of that account on Entra. A username corrected by a
  modification, or an account made again, is not dated by an activation
  that was somebody else's. The item carries the earliest of those dates
  among the requests on that server, how many days and months of thirty
  days ago it was, and the dates of the earlier reports of the same
  referent that named the person on that server (an earlier entry with
  an empty server, written before the server was recorded, names the
  person on every server). Who decides "never entered" depends on the
  server. One that was read decides
  ([`report_server_access()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_server_access.md):
  no row, or no first visit), and Entra does not count, because the
  server says exactly which server and is not misled by a key IT has
  reset; `fonte` is `server`. One that was not read, for any reason,
  falls back on the rule of Entra
  ([`report_first_access()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_first_access.md)),
  and `fonte` is `entra`: the mail says so. The account's state is the
  first filter either way, and an account that is not active goes to IT
  once for the person. `limite` is the last day the first sign-in is
  promised
  ([`mail_first_signin_deadline()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_first_signin_deadline.md)),
  but only when the two dates on Entra agree within
  [`report_tolerance()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_tolerance.md),
  that is when the key is still the one of the creation: otherwise the
  dates diverge for the person who entered, for a key reset and for the
  key the D-31 rule replaced, and a date computed from them would be a
  guess, so it is `""`;

- **no access for more than a year**, one item per person and server. A
  pair is a candidate when its request is active, applied, not expired
  and the person has had the access on that server for more than 365
  days (the oldest request there, as for the first sign-in). On a server
  that was read, it enters when the person has entered at least once and
  the last access
  ([`report_server_access()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_server_access.md))
  is more than 365 days before the reading, both as dates in Italian
  time. It is listed in full the month it crosses the threshold, and
  counted in `senza_accessi_gia` after: when an earlier report of the
  same referent named it (an entry with an empty server names it on
  every server). On a server that was not read the pair is only counted,
  per server, in `non_controllati`: Entra says nothing about it, and an
  empty item would say "none" about something nobody measured.

What has no referent to go to goes to IT, and to nobody else: a row
whose owner the log does not establish (no creation names it, or the log
cannot say whom it belongs to,
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md)),
or whose owner Entra holds disabled, or does not hold, or cannot say; a
person whose account is disabled, missing, without a creation date or
that cannot otherwise be judged; a row the log does not date. A disabled
owner receives nothing.

A referent whose people went to IT without being judged is told how
many, in the report itself: the principle of the all-clear, which must
not cover an item nobody measured. `non_giudicati` counts them, a person
once: the people of that referent the report could not judge, and those
of the rows the log does not date.
