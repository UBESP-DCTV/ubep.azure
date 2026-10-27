# ubep.azure 0.22.0

* **The welcome and the message with the key give the date of the first
  sign-in.** A key handed over is valid for at least 60 days from the creation
  of the account, or from the last reset by IT, and an account nobody signs in
  to is eventually deactivated, never deleted. The welcome says by when to
  sign in for the first time, that after that date the key no longer works,
  and that an account without a first sign-in is deactivated and how to have
  it reactivated: through the referent first, then by replying to the
  welcome. The message with the key tells the referent to hand it over at
  once, by the same date, and to reply to it for a new key. The date is the
  day the account was born in the calendar of Rome plus 59 days, written
  `YYYY-MM-DD` like every other date in the messages
  (`mail_first_signin_deadline()`). It is counted from the account's own
  birth and not from the round: `directory_create_user()` now returns
  `created_at`, Graph's `createdDateTime` when the answer to the creation
  carries it, otherwise the moment read just before the request left, which
  brings the date earlier if anything: a day late only across midnight, with
  the machine's clock ahead of Graph's, an accepted case. Whether the answer
  carries it is to be seen on the first real creation.

* **A new identity verdict, `disabled`.** One match on an account whose
  `accountEnabled` is false was `existing`, and the round granted the right
  and mailed the person an access they could not use. Now it is `disabled`,
  with the account's UPN beside it: the row stops at the gate with
  `TRASPORTO_ACCOUNT_DISATTIVATO`, stays in the queue, and its outcome goes
  to the row's owner with IT in copy. When the round has no owner to give,
  as when no row is admitted, waiting for its account or changed and the
  log is not read, it goes to IT alone, like every outcome without an owner.
  When IT has enabled the account again the next round finds it `existing`
  and goes on. A revocation is the exception and still reaches the instance,
  since taking a right away needs nobody to sign in. The channel never
  enables an account and asks for no new permission: `accountEnabled` was
  already in the sweep.

* **The outcome of a row stopped on `TRASPORTO_ACCOUNT_DISATTIVATO` no longer
  says it returns to the queue by itself.** It does not: the account has to be
  enabled again. The message says the account is deactivated, usually because
  the person never signed in, and that a reply to it gets the account
  reactivated by IT and a new key. The line on `TRASPORTO_` in general is
  unchanged for every other code.

* **A new person asked for on several rows in the same round is created
  once.** The name the resolution finds free is taken as soon as the first
  POST has made the account, and until now a second row waiting for the same
  name sent a second POST, on a name already taken. Now the round sends each
  name once, for the oldest row that waits for it, in the order of the
  register (`creation_shares()`). Another row of the same person, with the
  same first name, last name and contact address, shares that account, its
  key, which goes to the referent of the oldest row, and its welcome; it takes
  the error of the creation if there is one, and next round finds the account
  and becomes `created` like the first. A row of somebody else with the same
  name, or of the same person with another address, waits: next round it
  meets the new account as a namesake, `ambiguous`, as before. Taking the next
  free name at once would make a second account for a person who may already
  have one.

* **A referent answers a collision from the register.** On `collision` the
  composed username belongs to an account with a different first or last
  name, and until now the answer went to IT by mail. The register gains the
  field `distinct_username`, *Another person: create this username*: when the
  account is not the person the row is for, the referent pastes into it the
  proposal the row carries in `username`, and the next round creates the
  account under that proposal as it creates an `absent` one, with the key to
  the owner and the welcome to the person; the round after, the row becomes
  `created` and the access message leaves. For the same person the field stays
  blank, and the row is corrected, or IT corrects the account. The answer
  holds only when it equals the proposal of that round, folded as addresses
  are (`collision_answered()`), and only when written after the round wrote
  the proposal (`log_answer_stands()`): an answer filled in when the row was
  filed, or imported already filled, does not. It is an intent field, so
  whoever writes it is an author of the row: an answer by somebody other than
  the owner waits for the owner or IT, and the gate judges the rights of
  whoever wrote it. The field is read on `collision` alone and is never the
  name created: the channel never ties a row to an existing account on the
  referent's word. Namesakes, `ambiguous`, still go to IT by mail.

* **The code of a collision carries the proposal**,
  `DATO_IDENTITA_IN_COLLISIONE:<proposal>`, as `SIGILLO_DIVERSO:<seal>`
  carries its seal. When the proposal moves, because the name was corrected or
  the suffix was taken meanwhile, the outcome changes and the message leaves
  again with the new one; with the bare code nobody would be told. The message
  names the username that is taken, writes the proposal on a line of its own,
  and explains the two answers.

* **An intent field added after the first seals enters the seal only when it
  holds a value** (`register_late_seal_fields()`). The seal is a hash of the
  intent fields, and `distinct_username`, even empty, would have moved the
  seal of every row: on the first round after the import every row ever
  carried out would have read as changed with nobody on record, been held, and
  had its owner mailed. Empty, the seal is the one written before the field
  existed, bit for bit; filled, the field enters after the others as its name
  and its value. A test fails while an intent field is neither among those
  sealed from the start nor in the list.

* **Tests pin the way out of a row stopped on a stray write of `owned_by`.**
  A write of `owned_by` with no author, or one of the channel with another
  field beside it, leaves the owner unknown, and the round writes nothing that
  would release the row. A write of `owned_by` alone with the channel's token,
  above the stray one, does: it is what IT does by hand, with two imports when
  the field already shows the owner, since REDCap logs no import that leaves a
  value as it was. One rare case stays stopped by design (decided on
  2026-10-27): a stray write that lands inside a round, between its reading of
  the log and its seal, and ends below the second-to-last seal. The way out is
  to delete the row and have a referent create it again.

* **A test pins how an account is born.** The creation sends
  `forceChangePasswordNextSignIn` true and no license, in a single call to
  Graph; the test fails if either changes.

* **The register's dictionary changes, so this release touches the schema.**
  The `identity` field gains the choice `disabled`, and `distinct_username`
  follows it: 22 fields. The packaged dictionary and the live one have to
  change together. The new package on the old dictionary stops the round on
  `DIZIONARIO_CAMPO_ASSENTE` and `DIZIONARIO_SCELTE_DIVERSE`, the old package
  on the new one on `DIZIONARIO_SCELTE_DIVERSE`, and in either order the round
  grants nothing until both are done. Import of the dictionary and
  installation in the same window, with the round stopped in between. The
  runners call the package as before, and the round record gains no column.

* **The first round after the installation writes to some owners.** Every
  active row whose account is deactivated, `applied` ones included, becomes
  `disabled` with `TRASPORTO_ACCOUNT_DISATTIVATO`, and its outcome leaves
  once, to the owner with IT in copy: IT should hear of it before the
  release. Every row stopped on a collision changes its detail, which now
  carries the proposal, so its owner receives the message again, with the two
  answers. No seal moves: the new field is empty everywhere.

* **Going back to 0.21.0 is a single act too**, with the old dictionary,
  since the old package stops on the new one. On 0.21.0 a deactivated account
  is `existing` again: the rows waiting on `TRASPORTO_ACCOUNT_DISATTIVATO` are
  granted, and their people mailed an access they cannot use. A row created
  from an answered collision was sealed with the answer inside, and 0.21.0
  seals without it: the row reads as changed with nobody on record, and waits
  for its owner.

# ubep.azure 0.21.0

* **`build_ps1_from_xlsx()` is defunct.** Every instance is now linked to the
  authorization channel, and `jobTitle` is no longer a channel, so the function
  stops at once with an error that says so instead of building the `.ps1`
  scripts. It stays exported, so that an old call fails with the explanation.
  The internal helpers it called are untouched.

* **The note of `approved_seal` in the register's dictionary says that
  approving hands the row over.** Whoever approves a change hands the row to
  whoever wrote it last, unless it is only a revocation: the change is carried
  out with the rights of its author, and from then on the row is theirs. The
  approval mail said so already. The note is to be updated on the live
  project together with the one of `seal_state`.

* **A row passes to the last referent whose change was approved and carried
  out.** Until now a row stayed with its creator for good, and a creator who
  lost *User Rights* on the project, or left UBEP, could not have a colleague's
  change carried out even when they approved it (decided on 2026-10-16). Now
  the referent whose change the round carries out becomes the owner of the
  row, IT accounts included, and with the row go the gate on the rights, the
  approval of later changes, the outcome and the key, and the monthly report.
  A revocation does not move the row, free or approved: so a revocation by the
  owner followed by a change approved from another referent passes the row to
  that other, and a revocation alone leaves it where it is. When several
  accounts wrote since the last execution, the writes still in the row count
  (decided on 2026-10-17): the gate judges the rights of every author who
  counts, not those of whoever approves, and the approval comes from the last
  owner or from IT. The way out of a write by someone without the rights is for
  the owner to change the value and put it back, since REDCap logs no write
  that leaves the value as it was. The message of a held row says so: once
  approved, the change is carried out only if whoever wrote it holds User
  Rights with Full Access on the project, and approving somebody else's change
  hands the row over, unless it is only a revocation. The notes of the
  register's `seal_state` and `approved_seal` fields, which still speak of the
  creator, are to be updated on the live project.

* **`owned_by`, written by the channel and believed only from the log.** A new
  read-only field of the register holds the row's owner. The import right is
  open to the referents, so the value is never trusted: the owner is the value
  of the newest `owned_by` written by the channel's account in the event log,
  or the creator when the channel has not written one (`log_owner()`,
  `log_next_owner()`, `register_owner_import()`). **The field has to be added
  to the register before the package is installed**: 0.20.1 tolerates it
  (`DIZIONARIO_CAMPO_IN_PIU`), 0.21.0 without it stops
  (`DIZIONARIO_CAMPO_ASSENTE`). At the first round every row whose owner is
  established receives it.

* **The channel's account is configured.** `provisioning_reconcile()` and
  `provisioning_report()` take `channel_account`, and `dev/runner-canale.R`
  and `dev/runner-rapporto.R` read it from `UBEP_CANALE_UTENTE`, which is now
  **required** by both jobs: without it they stop and say so. Recognizing the
  channel by what it writes would make a referent who imports `owned_by` on a
  colleague's new row the only "channel" of that row. With the package default,
  `NULL`, no write of `owned_by` is believed and no row passes. Both job
  copies in `/opt` are to be replaced together with the package. With the
  account configured, what any other account writes in the channel's fields
  is ignored (decided on 2026-10-17): a referent who imports a CSV carrying
  the channel's columns neither stops the row nor takes it, and only a write
  of `owned_by` with no author, above the channel's newest, leaves the owner
  unknown. The seal comes from the log too: whether a row changed is judged
  against the last `applied_seal` the channel wrote, not against the field, so
  a referent who changes a row and imports the seal of the changed row has the
  change held for the owner, and a row the channel never sealed is a row never
  carried out. `UBEP_CANALE_UTENTE` (and `channel_account`) takes more than one
  account, separated by commas: when the account that holds the token changes,
  list the new one and the old one, and the old one's writes, its passages of a
  row among them, stay believed while it is listed.

* **Three new error codes in the round's record.** All of them say that the
  event log and the register's fields do not agree, and none grants anything.
  `TRASPORTO_REGISTRO_CANALE_ASSENTE`: the register is sealed and none of the
  listed accounts has written in its log, so the round stops before judging
  any row; the name is typed wrong, or the old account was dropped before the
  new one wrote. `TRASPORTO_PASSAGGIO_NON_REGISTRATO`: a passage whose new
  owner the field already showed, written by an import, could not be put in
  the log (the round writes the owner of today first and the new one after, so
  that REDCap logs both), and the log keeps the old owner. And
  `TRASPORTO_SIGILLO_NON_REGISTRATO`: an applied row's field already holds the
  seal the round writes while the channel's last seal in the log is another,
  so the row is read and carried out again every round, without mail; changing
  the field's value by import lets the next round write and log the seal.

* **`UBEP_POSTA_COPIA` is required with the mail on in the channel's job**,
  `dev/runner-canale.R`, not in the report's. The outcome of a row whose owner
  is not established goes to IT alone, and without the address it would not
  leave.

* **The fallback to `requested_by` is gone.** The outcome of a round that has
  no owner to give (sweep of the tenant failed, creation log or owners' log
  unreadable, no row to judge, a log that does not name the row) goes to IT
  only, with the sentence `referente della riga non stabilito`. The key never
  reaches anybody but the established owner. The round's mail to the owner,
  and the welcome, name the owner and not the creator.

* **A mail tells the person when they have the access.** When the round grants
  a right (`creato`, confirmed by the read-back) the person receives an
  access message with the instance, the project, the role, the group if any,
  the last day of access and who answers for the project. It does not leave
  for an updated right, a revocation, an access already in place (so not when
  a bench is switched back on) or a simulated round, and it goes to
  `contact_email` with nobody in copy. It is not retried: a lost one counts in
  the new `accessi_persi` (and `accessi_recapitati`), with the error
  `POSTA_ACCESSO_PERSA`. **Release order:** the two columns first in the
  `UbepCanale_CL` table and its collection rule, then the package, and last,
  after a record that carries them, the alarm on `accessi_persi > 0` and the
  incomplete-record alarm with the two columns.

* **The welcome sends the questions to the right place.** It no longer
  promises the access itself "within four hours" and then goes silent: it says
  that another e-mail will come when the access is ready, normally within four
  hours (as before, only when the instance's address is known). And it sends
  the person to the owner first for any problem, and to IT second, as the first
  sign-in instruction does.

* **The monthly report goes to the owner.** Each row is attributed to its
  owner as the month covered ended (the newest `owned_by` of the channel up to
  that moment, or the creator), so the list of who is due does not change
  between two attempts. `senza_creatore` keeps its name and now means "without
  an established owner".

# ubep.azure 0.20.1

* **The round's mail to a referent goes to the row's creator.** The outcome
  of every row, and the key of an account the round has just made, went to
  `requested_by`; only a held row's message went to the creator the log
  names. On the form the two agree, because `@USERNAME` fills the field in;
  the Data Import Tool writes it as the CSV has it, measured on 2026-09-02
  and again on 2026-10-16, and the round does not write it back. An import
  that left the field empty lost the key, `POSTA_CREDENZIALE_PERSA` on an
  account nobody could get into, and kept the outcome out of the register
  on `POSTA_SENZA_DESTINATARIO`; one that named another address sent the
  key and the outcomes there, to the person themselves if the file said so.
  Both now go to the creator (`mail_referent()`), the referent the gate
  judged, and the welcome names the creator as the one who hands the key
  over. The round still writes nothing into the request's fields: the
  creator travels in memory, as it does to the gate. The monthly report
  already went to the creator, and does not change.

  `requested_by` remains the fallback for a row without a creator. No key
  reaches it, since a row whose creator the log does not name stops on
  `TRASPORTO_AUTORE_NON_LEGGIBILE` and nobody is made for it. An outcome
  can, on a round with no creator to hand: the sweep of the tenant failed,
  the creation log could not be read or does not name the row, or no row
  needed judging. The 0.16.0 entry kept the notifications on `requested_by`
  because nobody held the import right; that right is to be opened to the
  `referente` role, and this comes first.

# ubep.azure 0.20.0

* **A monthly report to each referent, phase 1.** Decided on 2026-10-15.
  Once a month every referent receives what is new or unexpected about the
  requests they created, and not the list of all their accounts: the accesses
  activated in the month, for information, and the people who have not
  signed in a first time 30 days or more after their access was activated.
  The third item, people with no access in more than a year, needs the
  module and comes with phase 2; until then the mail says it was not
  checked, since an all-clear that covered it would say something false.
  `provisioning_report()` runs it, and **it reads and sends mail, and nothing
  else**: it does not write in the register and does not touch Entra, and a
  guard follows every function it reaches to keep it so.

  A request belongs to whoever created it, as the creation log says, the
  same person the round asks to approve a change; a person asked for by two
  referents is in both reports, each with their own rows. Only active and
  applied rows count. The date of activation is the channel's first write of
  the seal in the row's log, not `outcome_at`, which moves at every outcome;
  a row executed again after a change is listed as modified, and a new one
  says whether its account was new: Entra made it no earlier than the minute
  the row was made. Not from `identity`, which the round turns from
  `created` to `existing` one round after the creation, so every account the
  channel made would have read as an old one (measured in production on
  2026-10-16). The log is filtered by record here too, although
  `exportLogging` was measured on 2026-10-16 to honor the parameter, and
  read from the row's newest creation on, as the round reads it, since the
  register reuses ids; it is in Italian time, measured again the same day,
  as the month is cut.

  Whether a person has signed in is read from Entra with the permission the
  round already holds: an enabled account whose `lastPasswordChangeDateTime`
  is within 60 seconds of its `createdDateTime` (`report_tolerance()`, one
  constant) has never been entered, since the round creates accounts with the
  change of key forced at first sign-in. The tolerance was confirmed on
  2026-10-16 over the enabled accounts of the tenant: the accounts known
  never to have been used at 0 seconds, none between 1 and 30. A key reset
  by IT hides the person, and phase 2 removes that. The 30 days run from the
  person and not from the row: from the later of the channel's first
  execution after the newest write of `username`, and the birth of the
  account on Entra (`report_person_since()`), so a username corrected by a
  modification, or an account made again, does not inherit somebody else's
  months. The item names the earlier reports of the same referent that named
  the person, and how many months it has been.

  Two forms, told apart by the first word of the subject: `Tutto in ordine`,
  or `N da guardare` with N the people listed. Italian above, English below,
  IT in copy at the address of `UBEP_POSTA_COPIA`. What has no referent to go
  to (a creator the log does not name, or whose account is disabled or
  missing; a person whose account cannot be judged; a row the log does not
  date, told apart as having no seal by the channel or seals by two
  accounts) goes in one mail to IT, at the same address, only when there is
  something in it. A referent whose people went to IT without being judged
  is told how many in a line of its own, which changes neither the verdict
  nor the number in the subject.

* **The report is a job of its own, run every day.** `dev/runner-rapporto.R`,
  beside the round's and the observer's. A log alert looks back two days at
  most, so the job runs daily: it reads, computes and leaves a record every
  day, and from the 1st it sends the previous month's report to whoever has
  not had it yet. A ledger in the unit's state directory, one file per month,
  says which reports left and which people they named; it is written after a
  send, so a failed write costs a duplicate and never a loss. A day on which
  anything could not be read sends nothing, and judges the month on the
  reports the last whole reading found due, kept beside the ledger; with
  none on record the month is not called late. Only the covered month's
  ledger stops the post: an earlier one that does not read costs its people
  the sentence on earlier reports, and the record
  `RAPPORTO_STORICO_ILLEGGIBILE`. A report of the month before still unsent
  on the 1st is not sent any more, and the record carries
  `RAPPORTO_MESE_PRECEDENTE_INCOMPLETO` while it is missing.

  The post is off by default (`UBEP_RAPPORTO_POSTA`), and
  `UBEP_RAPPORTO_POSTA_A` redirects it for a field test; they are not the
  round's two, so a redirect for the report leaves the round's outcomes
  alone. `--mese AAAA-MM` forces the month for a run by hand; it is an
  argument so that it cannot be left on in the environment the jobs share.
  Neither a redirected run nor one with a forced month writes the real
  ledger: a field test at the end of October would otherwise make October
  read as sent, and nothing would leave on the 1st of November. A redirected
  run keeps a ledger of its own, so the timer of a field test does not send
  everything again every day; a run with a forced month writes nothing, and
  with the post on it requires the redirect.

  The record goes to its own table, through `UBEP_DCR_RAPPORTO` and
  `UBEP_STREAM_RAPPORTO`, with the columns of the design
  (`report_record()`). `mese_completo` is the design's `gia_mandati +
  mandati == referenti`, and `in_ritardo` is computed here and not in the
  query, so a test covers it: from the second day of the month, with the
  month not complete.

* **The register's door refuses a write that was not declared.**
  `register_call()` is the door every reading of the register goes through,
  and a call with `action = "import"` wrote through it all the same, unseen
  by a guard looking for the writers by name. It now refuses `import`,
  `delete` and `rename` unless the caller passes `writes = TRUE`, which only
  `register_field_import()` does. The round writes as before.

* **The sweep asks for `lastPasswordChangeDateTime` too.** One more field in
  `directory_fields()`, which builds the select and names the columns, so the
  round's sweep carries it as well. The resolution does not read it, and it
  asks for no permission beyond `User.Read.All`.

* **Shape of the release.** No dictionary to import, and the round and the
  observer are called as before, so their jobs stay as they are. What is new
  is outside the package and goes in this order: the table and its
  collection rule, before anything emits; the four variables; the package,
  and the new job in `/opt`; its unit and daily timer; a run by hand with a
  forced month and the post redirected; the three alarms, after the first
  record. The post is switched on last.

# ubep.azure 0.19.0

* **A change to a request waits for whoever created it, and only for them.**
  Decided on 2026-10-14. A request belongs to its creator: a change the
  creator made alone is carried out on the next round and sealed again, with
  nobody to ask. A change in which anybody else had a hand holds the row until
  the creator pastes the current seal into `approved_seal`, and an approval
  from anybody else, whoever made the change included, does not count. A
  later edit by the creator does not clear somebody else's change either: it
  does not say the creator saw it, and the approval is the act that does.

  The creator is the account REDCap authenticated when the row was made, read
  from the creation log as the scope gate already reads it, and not
  `requested_by`. The gate checks that account's rights on the project every
  round, so whoever approves has had their rights checked, and nobody else's
  rights need to be. Until now any referent other than the author could
  approve, including one with no rights on the project at all.

  The rule lives in one function, `change_needs_approval()`, and has one
  exception, a revocation by somebody who manages the project (below).

  Rows held today change with the release. An approval already pasted by
  somebody other than the creator stops counting, and the row stays held
  until the creator approves.

* **An approval counts once, and only after what it approves.**
  `approved_seal` is never blanked, so an approval the round had already
  carried out approved again any later change that brought the row back to
  the same content: a role set to admin by somebody else and approved, set
  back by the creator, set to admin again, was granted with nobody asked; a
  request the creator revoked came back the same way. And a seal pasted
  before the change it names, which can be computed in advance since it is a
  public hash of the intent fields, approved that change as soon as it was
  made. An approval now counts only when it stands above the round's last
  execution and above every change by somebody other than the creator, in
  the row's log (`log_approval_stands()`).

* **A change made while the round runs is not the creator's.** The round
  seals the row it read at the start and writes the seal last, so an edit
  made while it swept the tenant and talked to the instances landed below the
  seal, dropped out of the authors, and was carried out with the creator's
  next edit. The round now also reads the stretch between the last execution
  and the one before it: a change by anybody else there counts, unless the
  creator's approval of the seal that execution wrote stands above it
  (`log_uncovered_authors()`; `log_pending_authors()` is what the rule now
  judges).

* **A request not applied yet is protected too.** A row with no seal, just
  filed or left in the queue by a transport or data error, could be changed
  by anybody and the round carried it out on its creator's authority, without
  reading its log. The round now reads the log of every row not applied yet
  that it could act on and whose creator it knows, and applies the same rule;
  a log that names nobody says nobody changed it, since there is no seal that
  moved, and a log that cannot be read stops it on a transport code (below).
  It costs one call per
  waiting row for each round it waits. Setting the fields back does not
  release such a row, since the other change stays in its log: the message
  carries the seal of the restored version for the creator to paste.

* **Who made a change is read from the row's whole log.** The round asked for
  the last 24 hours of the whole register: an edit older than that fell out
  while the approval that followed it stayed in, the change had no author,
  and its author's own approval passed for somebody else's. It now asks for
  the changed row alone, all of its history, one call per changed row (or
  row not applied yet) and none on the ordinary night. If an instance ignored the `record` parameter
  the answer would be the whole log, and the round would still read only that
  row's events from it. `log_since()` is gone.

  What counts is the people who wrote an intent field after the round last
  wrote the row's seal, which is the mark of its last execution. The round's
  own writes do not count. It writes back the username it resolves before it
  reads the log, and `username` is an intent field, so until now the channel
  became the author of the change and anybody else, the real author included,
  its approver. The channel's account is recognized without configuration, as
  the one that wrote the fields only the channel writes, and by account
  rather than by event, since REDCap logs only the fields an import changed.

  A change whose authors the log cannot establish holds the row: two
  accounts writing what only the channel writes, an intent write with no
  author. A log that does not answer, or a creator it does not name, is a
  different case (below).

* **Only the row that stands now is read.** REDCap reuses the ids of
  deleted records, and a row's log, asked with no window, also holds the
  earlier lives of its id: the register was emptied on 2026-09-01, and the
  requests filed since take, one after the other, the ids the field tests
  had. Read whole, a change somebody else made to a field test after its
  seal held the new request on its first round, as if another referent had
  changed it. The round now reads a row's log from its newest creation on
  (`log_current_life()`, through `log_of_record()`, so for every question it
  asks of the log). Only the creation cuts: the wording of a deletion was
  never measured. A log that holds no creation is read whole, as before, and
  the round stops the row anyway, since the creation log does not name its
  creator either.

* **A log that cannot be read reaches the round's record.** Both log
  questions, the creations and the history of a changed row, left their
  `TRASPORTO_` code behind when they failed: the row was held, and nothing
  said why. The code now goes into `errori`.

* **A held row's message goes to its creator, and follows a second change.**
  It went to `requested_by`; it now goes to the creator the log names, the
  only referent whose approval counts. A held row always has its creator
  read now. It names who changed the row, and says that only the creator, or
  IT, can approve.

  The outcome detail of a held row now carries the seal to paste,
  `SIGILLO_DIVERSO:<seal>`. A second change to a row already held left its
  outcome as it was, so the round saw nothing to write and the creator kept a
  seal that approved nothing any more; the seal moves with the row now, the
  outcome reads as changed, and the message leaves again with the new value.
  The seal is computed on the row as the round leaves it, with the username
  it has just written, which is the row the creator pastes it into. On the
  first round after the install every row held today changes detail, and its
  creator receives one message.

* **A revocation by somebody who manages the project does not wait.**
  Decided on 2026-10-15. Somebody else's withdrawal of a request is carried
  out without its creator when everybody other than the creator who had a
  hand in it holds User Rights with Full Access on the project: taking an
  access away grants nothing, and they could have done it by hand. Narrow on
  purpose (`log_revocation_only()`): the row asks for `revoked`, and what the
  others wrote is that and nothing else; a withdrawal that also moves the
  role, the person or the project waits for the creator. The rights come
  from the instance, so such a row is not held before the plan: it stands
  provisionally and the gate decides on the rights of whoever touched it
  (`scope_withdrawal()`). One who does not manage the project sends it back
  to wait for the creator, as `held`; a permission that cannot be read keeps
  it queued on `TRASPORTO_PERMESSO_NON_LEGGIBILE`; the creator's own rights
  are asked only when the creator had a hand in it. Only a row with a person
  to take the access from reaches the gate: a revoked row whose person the
  tenant no longer holds is settled before any instance is asked, so it
  waits for the creator as before.

  A revocation alone is never counted as a change the last execution left
  uncovered (`log_uncovered_authors()`): it grants nothing, and counted it
  made the creator approve the reactivation of their own request after a
  manager's free revocation.

* **IT approves as the creator does.** Decided on 2026-10-15, so that a
  request whose creator has left UBEP does not wait for ever and keeps its
  creator on record. `provisioning_reconcile()` takes `approvers`, the REDCap
  usernames whose approval counts on any row, under the same three
  conditions as the creator's; the runner reads them from
  `UBEP_APPROVATORI_IT`, comma separated, on the machine and never from this
  repository. Without the variable only the creator approves. An approval
  by IT also covers, below the execution it led to, the change it approved,
  as the creator's does; and the list is compared without regard to case, so
  a capital letter typed on the machine does not void it. The scope gate still
  asks the creator's rights, so no approval carries the row of a creator who
  no longer manages the project.

* **A changed row whose log cannot be read is a transport error, not a held
  row.** It took `held`, and its message asked for a seal to paste with
  "Edited by: not established", sent to `requested_by` when the creator was
  the unreadable part, while saying it went to the creator. Nobody could
  approve it: there was no creator to ask, or no log to check the approval
  against. A changed row whose own log could not be read, or whose creator
  the log does not name, now takes `TRASPORTO_AUTORE_NON_LEGGIBILE`, the code
  the gate already gives a row with no author: it is not applied, it comes
  back next round, and the message says the failure is ours. The register's
  own code still goes into `errori`.

* **A person is validated before their account is created.** The row is
  checked under the name the round would create, so a past expiration gives
  `DATO_SCADENZA_NON_VALIDA` and a second row for the same pair gives
  `DATO_COPPIA_DUPLICATA` on the younger one; and the instance rehearses the
  grant as a dry run, which tells whether the role and the group exist. A row
  that fails takes its `DATO_` code and nobody is born. Until now the account
  was made, the welcome and the key left, and the error came one round later.

* **A person to create on an instance that does not answer** now waits as a
  transport error under the instance's code, as a pair does, instead of
  staying `pending` with no code and no limit.

* **With writing on and the post off, the round creates nobody**: the key has
  no road out. The row waits, and the round's errors carry
  `TRASPORTO_CREAZIONE_SENZA_POSTA` whenever somebody would have been
  created.

* **A creation whose answer was lost counts as a lost key and a lost
  welcome**, in the same round, so the alarm on the lost key fires: the
  account may have been born with a key that died with the process, and the
  next round would have found it and applied it with nobody holding the key.
  The cost is an alarm for an account never made, when the request did not
  reach Graph.

* **The approval field shows on a held row not applied yet.** Since a row
  not applied yet can be held, `approved_seal` and `seal_state` show when the
  row carries a seal or its outcome is `held`; shown beside a seal only, the
  field to paste the approval into was hidden on exactly that row, and it
  could not be approved from the form. Their notes say that IT approves too.

* **Release.** An install, and an import of the dictionary on the register:
  the branching logic and the notes of `seal_state` and `approved_seal`
  changed. The dictionary comparison reads neither, so the two can come in
  either order and nothing drifts meanwhile; but until the import a held row
  not applied yet has no field to paste its approval into. No new
  column in the round's record, so the collection rule stays as it is. The
  runner passes `approvers` now, so its copy under `/opt` has to be replaced,
  and `UBEP_APPROVATORI_IT` set in the unit's environment; a runner left as
  it was keeps the creator as the only approver. The register's service
  account still needs REDCap's **Logging** privilege, as it has since row
  protection.

  On the first round after the install every request still waiting to be
  applied costs one log call, and one changed by somebody other than its
  creator is held. A row applied before the release whose last execution
  carried a change by somebody else that its creator never approved, for
  instance one another referent approved under the old rule, is held at its
  next change, until its creator approves.

# ubep.azure 0.18.0

* **The welcome message says where REDCap opens.** It carried the user name
  and the steps of the first sign-in, and not the instance: on the first real
  request of the pilot the link had to be added by hand. It now names the
  address of the row's instance, and says that access to the project normally
  follows within four hours, which is the cadence of the round. The address
  is not composed from `server` and is not written in this repository: the
  round already receives the inventory's map from instance to host, and now
  passes it on to the post. A row whose instance the map does not name gets
  the welcome without those two lines, since a missing address is no reason
  to lose the message. The message with the key still carries no context: no
  instance, no project, no role, nobody in copy.

* **A welcome that did not leave is now counted.** `mail_round()` discarded
  what the send of the welcome returned, so a lost welcome reached neither the
  telemetry nor an alarm. The round record gains `benvenuti_recapitati` and
  `benvenuti_persi`, beside the two counters of the key and not added to
  `posta_fallite`, and a failed send, a missing address included, adds
  `POSTA_BENVENUTO_PERSO` to the errors. Like the key, the welcome is not
  retried: the account is already born and the round does not create it
  twice. Nor does a lost welcome hold its row back, which would keep the
  outcome out of the register without sending the welcome again.

* **The message with the key says how to hand it over.** Another channel if
  there is one, otherwise a new message with the key alone, written by the
  referent to the address they know from their own correspondence rather than
  the one copied from the request, and never a forward. If the two addresses
  differ the referent stops and replies, since the welcome went to the one in
  the request, and leaves the key out of the reply: a mail client quotes the
  body by default, and the reply goes to the round's reply address, where a
  key not yet used would stay readable.

* **The collection rule has to learn the two columns before this release
  lands**, because the ingestion API drops in silence a column the rule does
  not know. Then the package; last, once a record has brought the two columns
  with a value, the new alarm on lost welcomes and the rule on incomplete
  records, which names the columns it requires and must gain these two. No
  dictionary change and no change to what the runner calls, so the runner
  copy under `/opt` stays as it is.

# ubep.azure 0.17.0

* **A bench that is switched off no longer keeps the observer's alarm on
  unreachable instances red.** Benches are instances kept for trials, off by
  default and switched on when needed. Listed among the instances with the
  module, they are unreachable on most runs, and the alarm on unreachable
  instances fires on `irraggiungibili > 0`: it would stay red for good, and an
  alarm that is always red is an alarm nobody reads.

  An entry of the inventory's `con_modulo` may now carry `"banco": true`, and
  the observer's run record gains two fields. `irraggiungibili_produzione`
  counts the unreachable instances not marked as benches, and is the field the
  alarm reads; `irraggiungibili_nomi` names every unreachable instance, benches
  included, as an array even when it holds one. `irraggiungibili` is
  unchanged. A missing flag, or any value other than `true`, means production:
  an instance leaves the alarm only when somebody marked it.

  The mark takes a bench out of that alarm and out of nothing else. When every
  instance with the module is a bench and all are off, the run reads nothing:
  `letture_riuscite` is zero and `tutti_collaudati` is false, so the alarms on
  absence and on the gate fire and stay red, as measured on 2026-08-20. That
  is the observer reporting that it sees no instance, and the steady red goes
  only when a production instance with the module is listed and answers.

  The order of the release is the one every new column asks for, because the
  ingestion API drops in silence a column the collection rule does not know:
  the two columns go into the observer's table and its collection rule first,
  then the package and the runner copy under `/opt`, and last, in the same
  window and once a record has brought `irraggiungibili_produzione` with a
  value, the alarm rule and the rule on incomplete records. The latter names
  the columns it requires, and must gain this one: moved onto it, the alarm
  reads a field no other rule guards, and should it arrive empty after a
  rollback or a collection rule restored from its earlier definition, a
  production instance switched off would fire nothing. No dictionary change and
  no module change.

# ubep.azure 0.16.0

* **The scope gate no longer takes the requester's name from the row.** The
  gate decides whether whoever filed a request may manage the project they
  filed it for, and it built that question out of `requested_by` — a field
  filled in by the `@USERNAME` action tag. An action tag governs the form
  REDCap draws, and an import draws no form: measured on 2026-09-02 on a live
  instance, the Data Import Tool writes that field verbatim. Anyone holding
  the import right could therefore name a colleague who manages the project
  and have the gate check that colleague's rights.

  The round now asks REDCap's event log who was **authenticated** when each
  row was created, and the gate judges that name. It is a fact REDCap
  establishes rather than a value anybody types, so no import can move it.
  The notifications still address the register's own `requested_by`: the two
  agree on every row filed from the form, and the import right that would
  make them disagree is not granted to anybody.
  The creation events are asked for with `logtype`, which is REDCap's own
  classification of the event, and the prose of `action` is read only as a
  guard on top of it. REDCap ignores a parameter it does not know rather than
  refusing it, so a filter REDCap silently dropped would answer with a complete
  log that looks valid — and the newest event for a row is whoever last
  edited it, not whoever opened it. The guard fails closed: no match, no
  creator, and the row is held rather than judged against the wrong person.


  One call for the whole round, `logtype = "record_add"` and no time window:
  a record is created once, so the answer holds one row per record that ever
  existed rather than one per event, and it is asked only when a row is still
  standing to be judged.

  A row whose author the log cannot name is **held, not refused**, under the
  new `TRASPORTO_AUTORE_NON_LEGGIBILE`. Telling the referent they are not
  authorized would send the one person who cannot fix it to go and argue —
  the same reason `TRASPORTO_PERMESSO_NON_LEGGIBILE` exists.

  No dictionary change: this release is an install and not an import. It does
  require the register's service account to hold REDCap's **Logging**
  privilege, which the row-protection release already needed.

# ubep.azure 0.15.0

* **An approved row now says so, and keeps saying so.** `seal_state` had three
  values in its vocabulary and the round wrote two: a row cleared by an
  approval was applied and sealed `intact`, indistinguishable from one nobody
  had ever contested. The register forgot, one round after the protection
  fired, and REDCap's event log was left as the only witness.

  The round now writes `approved` on the row it applies because an approval
  cleared it, and carries that value forward while the seal holds. It gives way
  to `modified` if somebody edits the row again, and to `approved` again once
  that edit is cleared in its turn. `intact` therefore keeps its own meaning:
  nobody has ever contested this row.

  No dictionary change — `approved` was already among the field's choices — so
  this release is an install and not an import.

# ubep.azure 0.14.0

* **A row edited after it was applied is no longer applied again.** REDCap has
  no per-row ownership — rights are per instrument, and the only thing that
  partitions rows are data access groups, which this register does not have on
  purpose — so any referent can edit any other referent's row. Until now the
  round would carry that edit out, on the authority of a pass that ran before
  the edit existed.

  The round now seals what it applied, compares the seal on the next pass, and
  stops the row where a withdrawn one stops: before the desired state is built,
  so no instance is ever asked about it. The outcome vocabulary grows a sixth
  word, `held`, which is neither a state nor a fault — nothing went wrong, and
  the row is waiting for a person.

* **A change is cleared by somebody other than whoever made it.** The approval
  carries the seal it approves, so it covers that change and no later one, and
  the round reads REDCap's event log to check the two are different people. The
  log names whoever was *authenticated*, which is not a value anybody can type
  — the same reason `requested_by` cannot be trusted on its own once the Data
  Import Tool is granted.

  A log that cannot be read leaves the row held. "I could not ask who did this"
  is not "somebody else approved it", and of the two ways to be wrong that is
  the one that does not grant.

* Three fields join the register's dictionary: `applied_seal`, `seal_state`,
  `approved_seal`. They stay hidden until a row has been applied, since a fresh
  request has nothing to protect.

  **The collection rule has to learn `esiti_held` before this release lands**,
  and the dictionary import and the package installation are **a single act**:
  this version also adds `held` to the choices of `outcome`, and
  `DIZIONARIO_SCELTE_DIVERSE` stops the round in **both** directions — unlike
  a field, which stops it only when missing. The round is meant to sit on
  `DIZIONARIO_DERIVATO` between the two gestures.

# ubep.azure 0.13.0

* **The round's record says whether the post was switched on.** Every mail
  counter is zero both when there was nothing to send and when sending was
  off, and `posta_dirottata` is false in both cases too — so the two rounds
  produced the same record and the telemetry could not tell a quiet night from
  a mute channel. The new `posta` field is the twin of `scrittura`, and it
  matters more than that one: under "send first, write after" the switch it
  reports gates every write into the register.

  Neither field has a fallback, and for the same reason: a caller that forgot
  to pass one would report the switch as off, which is the single reading the
  field exists to make impossible.

# ubep.azure 0.12.1

* **The outcome message names the identity the round settled**, instead of
  saying it is not established yet. A referent files a row with the UPN blank,
  as the work instruction asks; the round resolves it and writes it through the
  identity door *before* the message leaves. The message, though, was composed
  from the register as read — which is deliberately frozen, since it is what
  the round measures change against — so the first notice about any new request
  told the referent less than the register beside it already carried.

  Repaired by telling `mail_round()` what the round settled, rather than by
  widening the frame that gets imported: that frame is the other write door,
  and the two stay separate.

# ubep.azure 0.12.0

* **The round sends the post itself, in Italian and in English.** Three
  messages: the outcome of a request to whoever filed it, first-access
  instructions to the person the request is about, and the way into a
  newly created account to the referent who asked for it. It replaces the
  REDCap alerts, which deliver once per record and cannot be made to do
  otherwise — the trigger that sees writes arriving through the API is the one
  that has no "every time" to offer. A row whose outcome changed twice
  therefore warned once, and the last word a referent was left with could be
  the wrong one.

* **A row enters the register only once its message has left.** The round
  sends first and writes after, so a message that did not go out leaves the row
  as the register has it — the next round finds it changed again and retries.
  The queue is the register itself: no second state, no file, nothing to keep
  aligned. What this buys is that a notification cannot be lost; what it costs
  is that one can arrive twice, and that trade was chosen deliberately.

  The message about a new account's access is the exception, and it says so.
  The account is already created and the round does not create it twice, so a
  failure there is not retried: it is reported under its own code, because
  nobody but a person can repair it.

* **`UBEP_POSTA` and `UBEP_POSTA_A` govern the post.** Without the first the
  round behaves exactly as it did in 0.11.0 — it computes, it writes, it sends
  nothing — so installing this version changes no behavior on its own. The
  second replaces every recipient with one address so a field test can run on
  real data, and the round record reports that it is on.

* **A refused message says why, on stderr.** The outcome keeps the closed
  vocabulary the telemetry counts — `TRASPORTO_POSTA_RIFIUTATA` — and the
  service's own answer now goes to the journal beside the HTTP status. Neither
  half carries the diagnosis alone: on 2026-08-27 a single condition returned
  403 from one endpoint and 401 from another, both saying the requesting
  address was not on the allowlist, and the status by itself would have sent
  the reader looking for a network fault.

* **The round record carries five new columns**: `posta_partite`,
  `posta_fallite`, `credenziali_recapitate`, `credenziali_perse` and
  `posta_dirottata`. The collection rule has to learn them before this version
  ships, or they arrive empty and any alarm watching them is watching nothing.

* **A duplicated pair no longer takes the older row's access out of reach.**
  `register_to_desired()` marked every row of a repeated pair, and a marked row
  never reaches the plan — so a revocation written on the row that had granted
  the access was not carried out. The access stayed on the instance, its
  mandate read `data_error`, and nothing anybody could write in the register
  would remove it. That is a right standing with its mandate marked invalid,
  which is the failure this register exists to prevent, arriving from the side
  nobody was watching.

  **The oldest row keeps its mandate**, and only the rows filed after it carry
  `DATO_COPPIA_DUPLICATA`. The two were never equals: the older one may already
  have been served, and the newer is the one that did what the work instruction
  says not to do, which is to file a second request instead of changing the
  first. What looked like refusing to guess was picking the outcome that leaves
  no way out — the referent could not delete the row, could not revoke it, and
  could not change the three fields the key is made of, because the round
  rewrites the username at every pass.

  **Age is the `record_id`, which REDCap auto-numbers, and not the order the
  rows arrive in.** The API promises no order, and a register read newest-first
  would otherwise reverse who keeps the mandate. Non-numeric ids still get a
  definite order rather than an accidental one, and `"10"` sorts after `"9"`.

  **Putting `request_status` in the key would have been the smaller change and
  is unsafe**, which is worth recording because it is the obvious one to reach
  for. It would stop an `active` and a `revoked` row for one pair from being
  duplicates, and then both enter the plan: `provisioning_reconcile()` builds
  its apply batches before its revoke batches and reads the real state before
  either, so the round would grant the pair and remove it in the same pass. And
  it would be silent — `round_changed()` compares outcome, detail and
  `applied_as`, all three identical from one round to the next — so the
  instance would be written to twice every four hours with nothing in the
  register to show for it. A test now states the invariant that no pair lands
  in both lists.

  **What it does not fix, stated because the next person will ask.** Two
  `active` rows disagreeing about the role still resolve to the older one, and
  whoever filed the newer must change the older instead. The
  alternative is a third `request_status` that retires a row without revoking
  the access it stands for, and that costs a dictionary import on the register
  project — worth it only if the case turns up.

* **A request revoked before it was ever served no longer makes the person
  exist.** `request_status` reached only `register_to_desired()`, so the
  creation branch hung off the identity verdict alone and revoking a row that
  had not yet been served left the account to be born from it anyway. The two
  are not the same question — a revocation speaks about the access and the
  verdict about who somebody is — but nobody who revokes a request that has not
  been served expects an identity to come of it, and the only answer left was to
  tell people to delete the record instead, which contradicts what the form
  itself promises: absence is not a request.

  **The row closes rather than waiting**, under the word this round already uses
  for the same shape: a revocation of a right that is not there is settled as
  `applied`, with the read-back saying `absent`. Asking for absence and finding
  it is a success, and `pending` would have left open for ever a row nobody is
  going to touch again.

* **The round erases the username it wrote itself and keeps the one it did
  not.** This is the writing half of the rule that stopped a resolved row from
  being read as a declaration of its own handwriting, and it hangs on the same
  discriminator, the previous verdict. Read in both directions it is a single
  sentence: an empty `identity` means the `username` beside it belongs to
  whoever filed the row, and a filled one means it belongs to the round.

  **Why it must not empty a declaration.** A row that an error of data stops
  carries an empty `identity` by construction, so the earlier rule never spoke
  for it. The round emptied the username; the next pass read that emptiness back
  as a field the referent had left blank, took the other branch of the rule on
  internal contact addresses, filled the username in from the contact and found
  the account's surname was another person's. One row collected two different
  diagnoses without anybody touching it — and the field it was being asked to
  correct had been blanked, so the mistake was no longer in front of the person
  who made it.

  **Why it must still empty its own.** Emptying nothing at all is the wrong fix
  and the tests now say so: a row that was `existing` carries the canonical UPN,
  in the tenant's domain, beside a contact address that ordinarily is not. Kept
  past the verdict that backed it, that value is read as a declaration on the
  next pass and the row closes against the referent for a word the round wrote.
  Both branches settle in one step.

* **The round makes the accounts that are missing, under a permission that can
  do nothing else.** `directory_create_user()` is the second and last thing
  this package does on Microsoft Graph, and `User.Create` is what it runs
  under: it cannot modify an account that already exists, reset a credential,
  disable or delete one. So the worst a wrong creation can do is leave an
  account nobody has used, with the request that caused it written in the
  register beside the name of whoever filed it.

  **It does not compose the name it creates.** The UPN is an argument, and the
  round takes it from the verdict that found it free. Composing it a second
  time on the way to Graph would be two paths to one answer: the day somebody
  hands a domain to the resolution and not to the creation, the round would
  check that one name is free and create another — a UPN nobody has checked for
  a collision, which is the failure this whole sub-project is about.

  **`givenName` and `surname` are in the body because the criterion is the
  surname.** An account created without a surname is one the next sweep cannot
  find, while the UPN it would compose is now taken — so the row comes back
  `collision`, and the round would have created the person and then told them
  for ever that their name is another person's.

  **Neither `jobTitle` nor `officeLocation`.** The authorization has one
  channel and it is the channel; the contact address goes in the field that
  means contact address. The old carrier is read for as long as accounts carry
  it — the sweep counts them, and the day the count is zero the fallback is
  dead — and written never again. A guard arms the not-inheriting, because the
  serialized authorization is a live mechanism and not a fossil: 2.828 accounts
  carry it, 254 of them created in 2026.

  **The row it creates stays `absent` for that pass** and becomes `created` at
  the next one. That is not a delay being tolerated: `created` is defined as
  the row whose previous verdict was `absent` and that now matches, and the
  memory lives in the register. A round that wrote `created` on the strength of
  having just made the account would keep a second source of truth beside the
  sweep.

  **Making somebody exist is bounded by the same gate as granting them a
  right**, and by a guard. An `absent` row is not a pair, so before this it
  stopped at the identity gate and never reached the instance that answers the
  scope question — the round was rearranged so that it does. An instance that
  did not answer has neither allowed nor refused, and the row waits. A
  simulated round creates nobody: a creation is not a write on an instance, so
  nothing else in the round would have stopped it.

  **One credential per person, drawn from `openssl` and not from `sample()`.**
  There is no batch to be the password of, which is the property the historical
  flow lacked — one password at the top of a generated `.ps1`, shared by
  fifteen people, in a file that outlived the act. The generator matters
  because the account is created enabled and with no second factor enrolled:
  what a guess buys is the enrollment of another person's, which is the tenant's
  whole defense. R seeds its own generator from the clock and the process id
  and this round runs on a timer at six known times a day, which is a search
  space rather than a secret. The credential leaves by the return value and by
  no other road — not the register, not the telemetry record, not standard
  output — and a guard forbids the runner from naming it at all.

* **The round resolves who a row is talking about before deciding what to do
  with it.** `provisioning_reconcile()` gains a step between reading the
  register and building the desired state: it sweeps the tenant whole, resolves
  every row against it, writes `username` and `identity` back through the door
  that takes nothing else, and hands on to the desired state only what the gate
  admits. The order of the questions is the design, and the function's own
  documentation carries the new one.

  **The gate has no window.** It asks after the verdict the round has just
  computed, never after the one the register carries: a round that read the
  stored value would be looking at something up to four hours old, and after a
  failed sweep at something nothing had confirmed this pass at all.

  **A sweep that failed is a transport error on every row, and no instance is
  interrogated.** "I could not ask" is not "you are not the one", so the rows
  go back in the queue instead of closing against whoever filed them — and
  nothing is acted on, because acting would mean granting under a verdict
  nobody produced this round.

  **What the gate stops, and what the register then says.** `ambiguous` and
  `collision` close the row as data errors, so `A-13` mails the referent, under
  codes that name what they can correct rather than what the round observed:
  `DATO_RECAPITO_NON_IDENTIFICA` — give a contact address that picks out this
  person and nobody else — and `DATO_IDENTITA_IN_COLLISIONE`, whose proposal
  travels beside it in `username`. `absent` stays `pending`, because the round
  will create the account itself and mailing somebody about a row nobody has to
  touch is how an alert stops being read.

  Guard A ships in the same commit: no function that can write on an instance
  may do so without naming the gate on the identity, the twin of the rule that
  has guarded the gate on scope since 0.10.0. Both now read one list of what
  counts as a write, so a fourth write path cannot be added to one rule and
  missed by the other.

  `round_changed()` takes a `fields` argument so the same "only what changed"
  filter serves both families of field rather than being copied, and the Graph
  token and endpoint are arguments of the round with no defaults — this
  repository is public, and an endpoint written in is an endpoint published.

* **The resolution no longer mistakes its own handwriting for a declaration.**
  `resolve_identity()` treated the register's `username` as a claim by whoever
  filed the row, every pass. That is right until the round has answered, and
  wrong from then on: the two fields are never written apart, so a row carrying
  a verdict carries a username this package wrote. Read as a declaration it is
  the very shape decision 12 refuses — a UPN in the tenant's domain beside a
  contact address that ordinarily is not — so a resolved row oscillated with
  period two: `existing`, then closed against the referent with
  `DATO_RECAPITO_INTERNO_DIVERGENTE`, then `existing` again, mailing them about
  it every other round.

  `identity` is what tells the two apart, and it can, because nothing writes a
  username without writing it. Nothing is lost: the declared UPN is confirmed
  on the first resolution, which is the only pass that has a declaration to
  confirm, and re-deriving the account every pass afterwards is also what makes
  a renamed login surface as a changed verdict instead of as
  `DATO_UTENTE_DICHIARATO_DIVERSO` blamed on the person who filed the row.

  Invisible to the pure layer's own tests, which hand the resolution rows
  written by hand: the loop only closes when the round writes back and reads
  again.

* **The resolved identity has a body of its own, and a door that takes nothing
  else.** `identity_payload()` fixes the three columns — `record_id`,
  `username`, `identity` — and `register_identity_import()` refuses at the
  threshold anything that is not exactly those, the way `register_import()`
  already refuses anything that is not the five outcome fields. The register
  holds three families of field: what a person asked for, what the round
  resolved about who they mean, and what happened. No body may carry two of
  them, and neither door accepts the other's, so the separation is structural
  rather than a promise kept by whoever assembles the body.

  **Neither field is written without the other.** A username written without
  the verdict that authorizes it is the state this sub-project exists to close:
  the channel decides by looking at whether `username` is filled, and nothing
  has ever put a verdict beside it. The invariant that follows is
  **conditional**, and it is the condition the gate will check — a username is
  authoritative if and only if `identity` is `existing` or `created`. It is
  conditional rather than absolute because a collision carries its proposal:
  there is a determined value to show, and it is the one a person has to act
  on, so keeping it out of the register would leave it living only inside an
  e-mail.

  `overwriteBehavior` is `overwrite`, and the reason is not the one it is right
  for the outcomes. The body carries the totality of what the round owns on
  this axis, so overwriting can only blank the round's own two fields — and the
  blanking is the point: a row that was `existing` and becomes `ambiguous`,
  which is the renamed-login case, has to lose the username that became false
  rather than keep it beside a verdict that no longer supports it. The empty
  verdict is writable for the same reason. It is not a missing value: it is
  "not resolved", which is what a row stopped by a data error carries, and a
  row that stops has to shed the username it earned back when it still
  resolved.

  The transport the two writers share now has one copy rather than two.
  `register_field_import()` holds the mechanics — the JSON body, the overwrite,
  the check that REDCap took every row it was sent — while each writer fixes
  its own column list and its own refusal. What keeps the families apart is the
  door, not the call.

* **The package can say who a register row is talking about.**
  `resolve_identity()` is pure — a function of the row and of the swept
  directory, in the same shape as `provisioning_diff()` and `scope_errors()` —
  and it asks **two questions, not one**. `ambiguous` is read off the number of
  matches on the identity criterion; `collision` off the composed UPN being
  held by somebody else. A resolver asking one question could not tell
  `collision` from `absent`, and would either create a duplicate or take a
  uniqueness refusal from Entra and report it as a transport error, that is, as
  something that will pass by itself next round. It will not. Said in one line,
  because that is how the two stop being confused: `ambiguous` is too many
  people with one identity, `collision` is two people with one name.

  **The surname is the criterion and the contact address confirms it.** An
  account carrying the surname — and the given name too, when the account
  carries one — is a candidate for being this person; whether it is *the* one
  is settled by the contact address. Read the other way round, the resolution
  would call an ambiguity what is merely a shared address: 99 addresses in the
  tenant sit on more than one account, 221 accounts involved, and a mailbox
  shared by a lab says nothing about who anybody is. It would also miss the
  failure that matters most — a person who exists under a UPN this package
  would not have composed, whose contact address has since changed, read as
  "nobody matched" and given a second account.

  So one homonym is enough to stop the row. An account with this surname whose
  contact address is not the one given is `ambiguous`: nothing here tells "the
  same person, with an address we did not know" from "somebody else with the
  same name", and the second reading is the one that creates a duplicate. The
  addresses are read from `officeLocation`, where the historical flow put them
  and where 6.494 accounts still carry them, from `otherMails`, and from the
  UPN, because an address in the tenant's domain **is** a UPN. Both sides are
  normalized: 74 accounts carry the address with spaces at the edges, and an
  exact comparison would report `absent` for people who exist. Guests are
  excluded by invariant, not by measurement.

  `collision` therefore means something narrower than it looks. A homonym is
  caught by the surname rule and never reaches it, so reaching it means the UPN
  this package would compose is held by an account that does **not** carry that
  surname — odd data in the tenant rather than two people with one name. The
  numeric-suffix proposal stands, because a free UPN is still needed.

  **Two things stop a row that matched**, and the prefix on each is a delivery
  address rather than a label. An account whose `userType` cannot be read, and
  a contact address sitting on an account with no surname at all, are ours:
  neither is something the filer could fix, and telling the one person who
  cannot reach a directory attribute that they are not authorized sends them to
  go and argue. The unclassified account still matches, on purpose — dropped
  instead, it would become "nobody matched" and earn its person a second
  account.

  The declared username is confirmed as an identity and not as a string. An
  alias, an `@unipd.it` address that is the same institution but not the
  tenant's domain, a shared mailbox: divergence between the UPN and an address
  the same person writes from is the ordinary case, and a string comparison
  would refuse it. When the account carries the declared value among its own
  identifiers the canonical UPN replaces it; when it does not, the row holds
  two incompatible claims and goes back to whoever filed it.

  The internal-address rule holds in both directions, and its third branch is
  the counter-intuitive one: an address in the domain that matches nobody is a
  typo rather than an absence, so the creation branch does not open — creating
  it would fabricate the account the typo describes. It is the one place
  `absent` is suppressed, and it is asked before the collision so that the
  diagnosis names the typo instead of a homonym who has nothing to do with it.
  The symmetric case stays ordinary: an external address matching nobody is
  `absent`, and somebody from outside is a row to create rather than one to
  refuse.

  On a collision the round **proposes** rather than decides: `nome.cognome.2`,
  `.3`, the first free one. Without a proposal the row hands a person two
  questions and no material; with it exactly one is left, and it is the one
  only the referent can close.

* **The package can read the tenant's directory, and it reads all of it.**
  `directory_users()` is the only function that speaks to Microsoft Graph, and
  it does one thing: it sweeps. It does not filter, and that is a measurement
  rather than a preference — `officeLocation`, where the historical flow put
  the contact address and where 6.494 accounts still carry it, is not
  filterable server-side at all, and `mail`, which would be, is `null` on
  6.412 accounts out of 7.664. The obvious attribute is empty on exactly the
  population to be found. Reading in full costs 8 pages and 3,5 seconds
  measured on 2026-08-15, less than the round that will consume it, and it
  yields decision 4 of the channel's design by construction rather than by
  discipline: no local copy of the state, the real one re-read every round. It
  also buys a property a server-side filter could not have given — the
  comparison is ours, so it can normalize, and it has to, because 74 accounts
  carry the address with spaces at the edges and an `eq` would have missed
  them in silence.

  It answers in the shape the other adapters answer in — `ok`, `errors`,
  `payload` — plus `users`, the frame, and the shape is what keeps "I could
  not ask" apart from "nobody is there": the first is `ok = FALSE` with no
  frame at all, the second is a clean read of zero rows. **A failure at any
  page returns no rows whatsoever.** A half-read directory is not a small
  directory: every account on a page that did not arrive is missing, a missing
  account resolves to `absent`, and `absent` is the verdict that opens the
  creation branch — so partial rows escaping would turn a transport failure
  into duplicate people.

  Two bounds beyond what the plan asked for, both on the continuation Graph
  hands back. The sweep stops after 100 pages rather than following a
  continuation that never ends: the measured shape is 8 pages, and the failure
  avoided is the one this project can least afford, a round that never returns
  and so leaves no record, with the severity-1 alarm reporting that the channel
  is not running while it runs very hard. And a continuation is followed only
  when it is https on the host the caller named, compared on the parsed host
  rather than on a prefix, because `https://graph.example.org@elsewhere.test/`
  starts with the right text and resolves to the wrong machine. Following it
  blindly would hand an application credential to whatever host the other end
  names.

  The token travels as a redacted bearer header, so it is a weak reference
  inside the request object and cannot be spilled by printing it while
  diagnosing a round; it never reaches a URL, on the first page or on any
  continuation; and it is scrubbed out of a refusal's message before that
  message is kept. Graph does not echo it today, and relying on that would be
  trusting the other end to keep our credential. The refusal keeps Graph's
  `code` as well as its prose, because `Authorization_RequestDenied` and
  `Request_UnsupportedQuery` send whoever reads them to different places — the
  consent and the query — and a 403 on every row is precisely the shape a
  missing consent takes.

* **The `identity` field gains a fifth choice, `absent`, and the register's
  packaged dictionary changes with it.** The four approved on 2026-08-07 are
  not exhaustive over what the identity resolution can observe: they assume
  resolving a person and creating them are a single act, so "nobody matches
  and the composed UPN is free" becomes `created` at once. It does not — a
  creation can fail, and a person can be looking at the row in between — and a
  state that lasts needs a name. `absent` is a verdict rather than an
  instruction, the way `outcome` reports what happened rather than what to do.
  `identity_vocabulary()` holds the five words, next to `outcome_vocabulary()`
  and for the same reason: more than one reader needs them, and a second copy
  drifts. A test binds every field whose vocabulary this package owns to the
  choices the packaged dictionary offers, in order — order included, because
  `compare_dictionary()` matches the whole choices string, so a reordering
  reads as drift against the live project. Without that binding, a word added
  on one side only is silent in both directions: one the package never emits,
  the other one the project refuses to store.

  **This changes a schema, so it stops the channel until the live project is
  re-imported**, in either order: `DIZIONARIO_SCELTE_DIVERSE` blocks a round,
  and the comparison is symmetric. The halt is safe — it happens before the
  register is read, writes nothing, and raises a severity-1 alarm — but it is
  not silent, and the two acts belong to one maintenance window.

* **The channel's round leaves a record, and it goes in a table of its own.**
  A round left no trace but the outcomes it wrote into the register, and those
  say nothing about the round itself. `round_record()` builds that trace and
  `dev/runner-canale.R` emits it. It carries `registro_letto` — the channel's
  counterpart of the observer's `letture_riuscite` — because an alarm firing
  on the absence of a record would be satisfied by a round that started,
  stopped on a drifted dictionary and exited; and because an empty register
  and an unreachable one both give `righe = 0`, while only one of them needs
  somebody. One counter per word of the closed outcome vocabulary rather than
  a single total, since a night of data errors and a night of transport errors
  go to different people. **A second table rather than a column in the
  observer's**: the observer's alarm rules read its table without asking who
  wrote the record, and five of the seven read whichever record is the most
  recent — so a channel record in there would have made one of them a standing
  red and three of them silently green, masking the observer's findings
  instead of reporting them.

* **The module resolves the names a write would need on every run, simulated
  or not.** A role or a DAG that does not exist was refused only by a real
  write, because the resolutions lived inside the branch a dry run skips — so
  a simulation answered `creato` for a role that cannot exist and echoed it
  back in `after`. Measured on the field on 2026-08-14. Both resolutions are
  reads, so a dry run can afford them, and a rehearsal that cannot refuse what
  the performance refuses cannot warn about anything — which is the whole
  purpose of the phase in which the channel only simulates. The existence of a
  *user* remains unchecked, there and everywhere: REDCap accepts rights for a
  login that does not exist, which is how orphan rows are born.

# ubep.azure 0.11.0

* **The channel reads the request register with the token API and writes back
  only the outcome.** `provisioning_reconcile()` is the one function that
  holds the register and the instances together, and the only place a write
  can start from. A `project_id` the register accepted but that is not a
  number is reported `DATO_PROGETTO_INESISTENTE` before the scope gate ever
  sees the row — such a row may not be a pair yet, so nothing upstream
  validated it, and left to the gate it would come back "you may not ask for
  that project" when the truth is "that is not a project number".
* **The gate on scope is wired in.** A request is applicable only if whoever
  filed it holds REDCap's `user_rights` permission on the project it names,
  and a guard refuses any package function that can write on an instance
  without naming the gate — with one declared exemption, the conformance
  tool, which does not read the register and has no requester to gate on. An
  instance that did not answer returns its own transport code — whatever
  `module_state()` reports, or `TRASPORTO_ISTANZA_SENZA_MODULO` /
  `TRASPORTO_SEGRETO_NON_LEGGIBILE` when it was never even asked; one that
  answered but whose module is too old to carry the permission on any row
  returns `TRASPORTO_AMBITO_NON_LEGGIBILE` instead. Either way only the rows
  already resolved into a pair go back to the queue, never a declaration of
  out of scope. The same rule holds one granularity down: a single row whose
  own permission cannot be resolved — a role deleted underneath it, on an
  instance that otherwise answers — returns
  `TRASPORTO_PERMESSO_NON_LEGGIBILE` and queues. It is refused either way,
  because the alternative would be to widen access exactly when the channel
  has stopped being able to see it; what the code decides is who is told.
  Whoever filed that request filed it correctly and may well hold the
  permission — what is broken sits in REDCap's rights table, which IT can
  reach and they cannot.
* **`applied` is a claim about evidence, not about the absence of an
  error.** A real write is followed by a read-back, and the outcome is
  `applied` only if the re-read confirms it — the pair present after an
  apply, absent after a revoke; otherwise the row is reported
  `TRASPORTO_SCRITTURA_NON_CONFERMATA` and returns to the queue. Confirmation
  is by presence and not by field-by-field equality, deliberately: REDCap
  normalizes what it stores, and a rule demanding an exact match could make a
  row impossible to confirm and retried for ever. What the instance actually
  shows travels in `applied_as`, and the next round's diff is where a real
  disagreement gets acted on.
* Writes on the instances are grouped by `(server, project_id)`: the module
  refuses a write that touches more than one project, and the refusal arrives
  before touching anything.
* The dictionary comparison finally has a caller: the round stops before
  writing if the register's schema has drifted in a way that changes what it
  reads.

# ubep.azure 0.10.0

* **A request is bounded by what the person who filed it could already do by
  hand.** The channel applies without anyone reading, so the gate on *who may
  ask* — rights on the request register — said nothing about *what they may ask
  for*: any authorized requester could name any project on any instance.
  `scope_errors()` refuses a row whose requester does not hold REDCap's
  `user_rights` permission on the project the row names, with
  `DATO_AMBITO_NON_AUTORIZZATO`, and `scope_pairs()` says which pairs the
  instances have to be asked about. The rule automates a power instead of
  adding one: holding that permission is exactly "could have granted this
  access themselves".
* **The gate refuses whenever it could not read, and never grants.** A module
  too old to report the permission, a role deleted underneath a row, a value
  that read as empty, a row nobody can be attributed with: none of these is a
  permission. The one that decides the shape is the first — a missing column
  refuses every row loudly, rather than granting them all quietly.
* **`StateReader` reports the permission that governs, role first.** A user
  with a role inherits the role's permissions and the columns on their own row
  do not govern; a user without a role carries their own. Reading one table
  only returns the wrong answer for everybody in the other half, silently —
  the same trap the DAG read already documents. The resolution is a pure method
  so it is tested without a REDCap instance, and it reports the raw REDCap
  value rather than a verdict: what counts as "may manage users" is policy, and
  policy lives with the caller.
* **Fixture project identifiers moved to a reserved block, and a guard keeps
  them there.** Two of the values in the fixtures were projects that exist. The
  guard states the rule on the class rather than on a list of forbidden values,
  because a guard naming them would have to write them into this public
  repository; it covers the three syntaxes the repository writes an identifier
  in, refuses to pass when it read nothing, and names the offending file rather
  than the value it found.

# ubep.azure 0.9.1

* **The endpoint imports the class it calls.** `api.php` declares no namespace,
  so the `Allowlist` added in 0.9.0 resolved to the global one and every
  authorized request raised an `Error` that REDCap turned into its generic API
  reply — the channel answered 400 to a valid secret and nothing was logged. A
  new test reads `api.php` as tokens and refuses any class it names unqualified
  that does not resolve once the module is loaded, which is the failure
  `php -l` cannot see. Anyone running 0.9.0 must move to this
  release: the module directory of 0.9.0 serves no request that authenticates.
* **The module's `VERSION` tracks the package again.** It had stayed at 0.7.0
  through two releases, so `module_version` in every reply named a version the
  code was not.

# ubep.azure 0.9.0

* **The job runs from a dedicated machine, and observes without comparing.**
  `observe_instance()` turns one instance's `state` reply into a row — version,
  major, gate, surface fingerprint, reachability, and the pairs whose
  expiration has already passed — and `run_record()` builds the record a run
  leaves behind. Neither touches the diff: with no register every real pair
  would be classified as no longer wanted, so the danger is not the write call
  but the comparison feeding it, and the comparison is not computed at all.
* **A record states its own scope.** `flotta_a_una_major` is true only when
  every instance was attempted and answered. The clause that retires a
  compatibility branch fires on that flag, so a value computed over whichever
  instances happened to answer would retire a branch still in use: a flag that
  authorizes a destructive decision is false when it cannot know.
* **The module reports the fingerprint of its own IP allow list**, never its
  contents. The caller keeps no expected value and alarms on the change between
  two runs, which makes a hand on any instance's perimeter an observed event
  and avoids storing a digest small enough to enumerate. Parsing lives in one
  place and the address check uses it, so the reported fingerprint and the
  enforced list cannot drift apart.
* `contract_version` becomes **3**. Reads tolerate every version; writes
  tolerate 2 and everything after it, rather than 2 alone — pinning to one
  version would refuse an instance the moment its module is updated.

# ubep.azure 0.8.0

* **The request register gains a schema.**
  `inst/extdata/request-register-dictionary.csv` is the data dictionary of the
  REDCap project that carries the desired state, and the pure layer can now
  turn that register into the lists the diff already consumes.
  `register_to_desired()` splits requested from revoked, refuses a pair that
  appears twice rather than guessing which row wins, and leaves a row whose
  identity is unresolved out of the desired state without calling it an error.
* **A pair that exists in REDCap and appears nowhere in the register means
  nothing.** Removing an access takes an explicit request, never an absence.
  The diff has always classified an unrequested pair as `revocato`, which with
  an empty register would name every right in the fleet: the register declares
  requests, so it never produces a revocation nobody asked for.
* The register's field names are the ones the pure layer already speaks, so no
  map exists between the form and the request, and no key can fall into a
  default without raising. Every coded field uses its label as its own code,
  and a test on the dictionary keeps it that way.
* `outcome_payload()` builds the body that writes an outcome back, with the
  columns fixed in the function rather than assembled by the caller. What a
  person asked for is intent and what happened is observation; a transport
  error records itself without taking the row out of the desired state.


# ubep.azure 0.7.0

* **Writing is no longer confined to designated test projects.** The
  `test-project-ids` setting is gone from the module manifest. What removed it
  is not a decision to trust the channel but a recorded fact: a conformance run
  passed against the surface the instance actually runs, re-reading every field
  the channel writes and comparing it to what was asserted. A test in this
  package fails if that date is ever present while the manifest still declares
  the confinement, so the two cannot drift apart.
* What still restrains a write: the module refuses anything below its version
  floor, simulates above its tested ceiling, simulates when the caller's
  declared surfaces do not include its own, refuses a write spanning more than
  one project, and writes at all only on an explicit `dry_run: false`. Nothing
  restrains it per project, by design — a permanent project allow list would
  cost one configuration per server, growing with the projects, which is the
  friction this channel exists to stop paying.


# ubep.azure 0.6.0

* Writing now requires the caller to declare which REDCap surfaces it has been
  tested against. The module compares its own runtime fingerprint against that
  declaration and simulates the write when it is not among them, on the same
  branch that already forces a simulation above the tested ceiling. The
  previous release computed the fingerprint, reported it, and let every write
  through regardless — the check ran client side, on the answer, after the
  module had written.
* The endpoint contract moves to version 2. A write is refused against a
  module still on contract 1, which cannot enforce the declaration; reads
  accept either, so a partial deployment does not blind the fleet audit on the
  instances still to be upgraded.
* A passed conformance run is now recorded against the pair (major,
  fingerprint) rather than the major alone. A major can hold more than one
  surface — an upgrade inside it changes the fingerprint and leaves the major
  alone — and the previous behavior stamped every row sharing the major.
* Writing is still confined to the projects listed in the module's
  `test-project-ids` setting. That confinement is removed in the next release,
  and only once a conformance run has been recorded against the surface the
  instance actually runs.

# ubep.azure 0.5.0

* The REDCap authorization channel gained a write path: it can now assert
  project rights (role, DAG, expiration) on a real instance, and revoke them.
  Every operation simulates by default; the instance is touched only on an
  explicit `dry_run: false`.
* Added a conformance check that certifies a channel against an instance
  rather than trusting a write's own report of success: it applies, re-reads
  what was written, and compares it field by field against what was
  asserted, before revoking and re-reading again to confirm nothing was left
  behind. A passed run is recorded by REDCap major.
* **Writing is confined to the projects listed in the module's
  `test-project-ids` setting, and an unconfigured or empty list denies every
  write.** No wildcard exists to lift this from the REDCap side. The
  confinement is removed only once a conformance run has been recorded
  against the instance's REDCap major — which has not happened yet for any
  instance. Anyone installing this version expecting to provision production
  projects will find writes refused, not simulated: this is deliberate, not
  a bug.

# ubep.azure 0.4.0

* Added the REDCap authorization channel, read only in this release. A REDCap
  External Module lives in `inst/redcap-module/` and answers with the real
  state of project rights, the instance version, the version gate and a
  fingerprint of the REDCap surface it depends on. No write path exists yet.
* Added `build_redcap_module()`, the only exported addition: it packs the
  module into the archive REDCap expects. The module and this package share a
  single version number, so the two ends of the endpoint contract cannot drift.
* The client reads a response by its shape rather than by its status code. A
  module that is installed but disabled answers HTTP 200 with plain text, so
  inferring success from the status fails inside the JSON parser with an error
  that does not name the cause.
* The surface fingerprint downgrades an instance to untested when it does not
  match a measured one, even if the version says otherwise. An instance can be
  in the right major and have a changed surface, which no version comparison
  can see.
* Requires R (>= 4.4).

# ubep.azure 0.3.0

* Fixed `logImportUsers.csv`: each row now records one user with an intact
  UPN-to-person mapping (previously every row repeated the whole batch and the
  column count varied with batch size).
* `build_ps1_from_xlsx()` now stops on rows with a missing `Nome`/`Cognome`
  instead of silently emitting a `NA.NA@...` account.
* Input is now restricted to Excel files; the (broken) CSV input path was
  removed.
* The generation no longer leaves a dangling `sink()` if an error occurs
  mid-run (which used to mute the R session).
* The initial password is no longer the hardcoded `P@ssw0rd`: a strong random
  password is generated per run by default, and can be set via the new `pwd`
  argument. Accounts are still forced to change it at first sign-in.
* Added tests covering the generated Microsoft Graph scripts (previously the
  `New-MgUser`/`Remove-MgUser` output had no automated coverage) and removed
  real-looking student e-mail addresses from the test fixtures.

# ubep.azure 0.2.1

* Fix verbosity of `read_cvs`
* Considered `ubep.unipd.it` the default domain, pass it to functions explicitly is no more necessary.
* Removed `here()` from project detecting path systems; now the files are
  created in the correct folder depending on their location and not on the r script project running the procedures.

# ubep.azure 0.2.0

* exported `build_ps1_from_xlsx` that is currently the main interface function to the package utils.
* Setup pkgdown for documentation website

# ubep.azure 0.1.0

* Refactoring functions into dedicated files and coherent naming
* Added (copy-pasted) all the old functions and tests into the project.
* Added standard basic support for package development.
