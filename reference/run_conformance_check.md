# Run the conformance check against one instance

The gate the ceiling policy rests on, and the only thing that earns a
conformance date. Seven steps, on a designated test project:

## Usage

``` r
run_conformance_check(
  server,
  secret,
  project_id,
  username,
  registry_path = system.file("extdata", "tested-fingerprints.csv", package =
    "ubep.azure")
)
```

## Arguments

- server:

  Hostname, optionally with the path REDCap is mounted under.

- secret:

  Shared secret.

- project_id:

  Test project; writes are refused outside the module's configured test
  projects. Must already define the roles and the data access group the
  cases name — see the note above.

- username:

  Test account to assert rights for. Must hold no rights in `project_id`
  before the run starts — see the note on step 5 above.

- registry_path:

  CSV to record the outcome in. See the note above on
  [`devtools::load_all()`](https://devtools.r-lib.org/reference/load_all.html)
  versus an installed package.

## Value

A list with `conforms`, `steps` and `differences`, invisibly. `steps`
gains a `recorded` entry once every other step is green: `TRUE` once
[`record_conformance()`](https://ubesp-dctv.github.io/ubep.azure/reference/record_conformance.md)
succeeds, `FALSE` if it errors — a failure to write the registry must
not discard the result of five real writes already performed against the
instance.

## Details

1.  read the baseline;

2.  apply as a dry run, re-read, and require that nothing changed;

3.  apply for real, one case at a time;

4.  re-read and compare field by field against what was asserted;

5.  revoke;

6.  re-read and compare against the baseline;

7.  record the date, and only if every step was green.

Step 2 is what measures the dry run guarantee instead of asserting it.

Step 5 does not restore anything: a revoke removes rights outright, and
that equals the baseline read in step 1 only when that baseline was
already empty. **The designated test account must hold no rights in the
test project before the run starts.** If it already does, the run
overwrites them through the five cases and then removes them entirely;
step 6 will correctly report a failed `restored` step, so nothing false
gets certified, but the account is left with fewer rights than it had —
that precondition is on the caller, not on this function.

Every write is a network call that can be refused, time out, or hit a
closed version gate. Its `ok` flag is captured and checked before the
re-read that follows it is trusted, and the re-read itself gets the same
treatment: a call that failed to answer must not be read as "nothing
differs", or a transport failure would be filed as a conformance failure
— or worse, on the final re-read, as a restore nobody actually observed.
When either a write or the re-read after it reports `ok = FALSE`, the
corresponding step is failed immediately and the reported errors are
recorded in `differences` prefixed `TRASPORTO`, instead of a list of
fields — the same vocabulary
[`module_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_call.md)
already uses for a failure that is not the instance's answer.

If the instance itself does not answer the baseline read — no payload,
so no major — the run stops right there: every later step compares
against a baseline and a major that were never established, so
continuing would measure nothing and could still send further requests
to a server already known to be unreachable.

Run under
[`devtools::load_all()`](https://devtools.r-lib.org/reference/load_all.html),
`registry_path`'s default resolves inside the source tree, so a passing
run is written where the next task's `git add` can see it. Run against
an installed copy of the package, the same default resolves inside the
installation library instead, and the date never reaches the repository
— no error, just nothing to commit.

The test project must already define every role and data access group
the cases name, because the channel asserts memberships and does not
create them: a role or a DAG that is not there is a data error the
instance returns, not something this run can provision on the way past.
Read
[`conformance_cases()`](https://ubesp-dctv.github.io/ubep.azure/reference/conformance_cases.md)
for the exact names, and check them against the project before running —
a missing role surfaces as a `DATO_RUOLO_INESISTENTE` on one case, which
reads like a conformance failure and is not one.

Server, secret, project and usernames come from the caller: this
repository is public and none of them may appear in it.
