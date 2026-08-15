# ubep.azure (development version)

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
