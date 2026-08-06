# Remove the rights a set of people hold in a set of projects

Carries the pair and nothing else: revocation does not care which rights
are there, and sending them would suggest it does.

## Usage

``` r
module_revoke(
  server,
  secret,
  requests,
  dry_run = TRUE,
  registry = tested_fingerprints(),
  declare = certified_fingerprints(registry)
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

- declare:

  Fingerprints the caller states it has been tested against. The module
  refuses to write when its own is not among them, so an empty
  declaration writes nothing. Reads and dry runs ignore it.

## Value

A list with `ok`, `errors`, `payload` and `gate`.

## Details

A write (`dry_run = FALSE`) must concern a single `project_id` across
all `requests`; the module rejects a mixed-project write with `400` and
code `INTERNO`, because `PROJECT_ID` is an immutable per-process PHP
`define()` that selects which project's log gets the trace, so a write
spanning two projects would leave one of them untraced. That gate lives
in the module, not here. Reads and dry runs are free to span more than
one project.
