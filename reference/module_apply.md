# Assert the rights a set of people must hold in a set of projects

Always asserts the complete state, never a delta: `updatePrivileges`
skips fields it is not given, except the DAG, which it clears instead. A
delta would revoke DAGs on every renewal and report success — so the
caller must pass everything, not just what changed.

## Usage

``` r
module_apply(
  server,
  secret,
  requests,
  dry_run = TRUE,
  registry = tested_fingerprints()
)
```

## Arguments

- server:

  Hostname of the instance, optionally followed by the path REDCap is
  mounted under, as in `"host.example.org/redcap"`. The fleet is not
  uniform on this point, so the mount cannot be assumed.

- secret:

  Shared secret, sent as the `X-UBEP-Secret` header.

- requests:

  List of requests; empty reads the whole instance.

- dry_run:

  Logical; the module writes only on an explicit `FALSE`.

- registry:

  Tested fingerprints, see
  [`check_fingerprint()`](https://ubesp-dctv.github.io/ubep.azure/reference/check_fingerprint.md).

## Value

A list with `ok`, `errors`, `payload` and `gate`.

## Details

`dry_run` defaults to `TRUE`, and the module writes only on an explicit
`FALSE`. In a dry run `after` is an intention, not an outcome: REDCap
can accept a value, store a different one, and still report success, so
a green dry run is not a guarantee that the same call will apply
cleanly.

A write (`dry_run = FALSE`) must concern a single `project_id` across
all `requests`; the module rejects a mixed-project write with `400` and
code `INTERNO`, because `PROJECT_ID` is an immutable per-process PHP
`define()` that selects which project's log gets the trace, so a write
spanning two projects would leave one of them untraced. That gate lives
in the module, not here. Reads and dry runs are free to span more than
one project.
