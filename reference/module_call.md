# Call one operation on one instance

The only function in the package that speaks to a REDCap server, and the
only one that builds the URL. Keeping the base normalization here is
what stops the three operations from each carrying their own copy of it.

## Usage

``` r
module_call(
  server,
  secret,
  operation,
  requests = list(),
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

- operation:

  One of `"state"`, `"apply"`, `"revoke"`.

- requests:

  List of requests; empty reads the whole instance.

- dry_run:

  Logical; the module writes only on an explicit `FALSE`.

- registry:

  Tested fingerprints, see
  [`check_fingerprint()`](https://ubesp-dctv.github.io/ubep.azure/reference/check_fingerprint.md).

## Value

A list with `ok`, `errors`, `payload` and `gate`.
