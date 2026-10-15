# Put each row in the report it belongs to

A row belongs to **whoever created it**, as the creation log says, and
not to `requested_by`, which an import writes as it likes. The report
goes to the same person the round asks to approve a change. A person
asked for by two referents is in both reports, each with their own rows.

## Usage

``` r
report_assemble(
  rows,
  directory,
  period,
  previous = list(),
  unread = character()
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

## Value

A list with `referenti`, one report per referent named after them, each
a list of `referente`, `attivati` (rows), `senza_primo_accesso` (people)
and `non_giudicati` (a count); `it`, `NULL` when there is nothing for
IT, otherwise a list of `senza_referente` (rows, with `motivo`),
`non_giudicabili` (people, with `referente` and `motivo`) and
`senza_data` (rows); and `senza_creatore`, how many rows have no
referent to go to.

## Details

Three items, of which phase 1 fills two:

- **activated in the month**, one line per request, new or modified. It
  is information, and does not count among the things to look at. A new
  one says whether its account was new: `account` is `nuovo` when Entra
  made the account no earlier than the minute the row was made
  (`creata_il`), `esistente` when earlier, `""` when either date is
  missing;

- **no first sign-in**, one item per person, with every project of
  theirs: the requests of that person activated at least
  [`report_grace_days()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_grace_days.md)
  before the reading and not expired, when Entra says nobody has entered
  the account
  ([`report_first_access()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_first_access.md)).
  The thirty days run from the later of two dates, in Italian time: the
  channel's first execution for the username the row names now
  ([`report_person_since()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_person_since.md)),
  and the birth of that account on Entra. A username corrected by a
  modification, or an account made again, is not dated by an activation
  that was somebody else's. The item carries the earliest of those dates
  among the person's requests, how many days and months of thirty days
  ago it was, and the dates of the earlier reports of the same referent
  that named the person;

- **no access for more than a year** is phase 2, and the mail says it
  was not checked.

What has no referent to go to goes to IT, and to nobody else: a row
whose creator the log does not name, or whose creator Entra holds
disabled, or does not hold, or cannot say; a person whose account is
disabled, missing, without a creation date or that cannot otherwise be
judged; a row the log does not date. A disabled creator receives
nothing.

A referent whose people went to IT without being judged is told how
many, in the report itself: the principle of the all-clear, which must
not cover an item nobody measured. `non_giudicati` counts them, a person
once: the people of that referent the report could not judge, and those
of the rows the log does not date.
