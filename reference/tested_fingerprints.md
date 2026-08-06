# Fingerprints of REDCap surfaces this client has been tested against

One row per surface actually measured on a running instance. Rows with
an empty fingerprint are dropped: a placeholder must not be able to
certify an instance as tested.

## Usage

``` r
tested_fingerprints(
  path = system.file("extdata", "tested-fingerprints.csv", package = "ubep.azure")
)
```

## Arguments

- path:

  Registry CSV. Defaults to the one shipped with the package, but a
  conformance run must be able to point this at the same registry it is
  about to write to: with a custom `registry_path`, the shipped file is
  not the one that matters, and reading from it while writing to another
  would declare one registry's surfaces while stamping a different one —
  an accepted pairing nobody actually measured.

## Value

A data frame with `redcap_major` and `fingerprint`.
