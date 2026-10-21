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
referent to go to. Since rows can pass, that means without an
established owner and not only without a creator; the name stays,
because it is a column of `UbepRapporto_CL`, and a renamed column would
keep the table's history under one name and the new records under
another.

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
