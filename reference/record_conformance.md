# Record a passed conformance run in the registry

Written by the run itself rather than by hand: a trigger that depends on
someone remembering to type a date is a reminder, which is the thing the
mechanism exists to replace.

## Usage

``` r
record_conformance(path, major, fingerprint, on)
```

## Arguments

- path:

  Registry CSV.

- major:

  REDCap major the run covered.

- fingerprint:

  Surface fingerprint the run covered, read from the instance's own
  answer. The key is the pair, not the major: a major can hold more than
  one surface — an upgrade inside it changes the fingerprint and leaves
  the major alone — and stamping every row of a major would certify a
  surface nobody tested.

- on:

  Date of the run.

## Value

The updated registry, invisibly.

## Details

Called with `path` defaulted from
[`run_conformance_check()`](https://ubesp-dctv.github.io/ubep.azure/reference/run_conformance_check.md),
so the same caveat applies here: under
[`devtools::load_all()`](https://devtools.r-lib.org/reference/load_all.html)
the default resolves inside the source tree and the write lands where
the next task's `git add` can see it, while against an installed copy it
lands in the installation library instead and never reaches the
repository.

Raises when the pair matches no row: assigning into a `[` index that is
all `FALSE` is a silent no-op in R, and `write_csv()` would then rewrite
the file unchanged. A run against a pair the registry has never heard of
is precisely the case this mechanism exists for, and it must not be
indistinguishable from a run that actually recorded a date.
