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
