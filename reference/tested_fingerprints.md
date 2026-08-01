# Fingerprints of REDCap surfaces this client has been tested against

One row per surface actually measured on a running instance. Rows with
an empty fingerprint are dropped: a placeholder must not be able to
certify an instance as tested.

## Usage

``` r
tested_fingerprints()
```

## Value

A data frame with `redcap_major` and `fingerprint`.
