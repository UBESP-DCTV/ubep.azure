# Fingerprints whose write behavior a conformance run has verified

The list the ordinary caller declares when it is about to write. It is
deliberately narrower than the measured one that
[`tested_fingerprints()`](https://ubesp-dctv.github.io/ubep.azure/reference/tested_fingerprints.md)
returns: a row added after a bare `state` measures a surface, it does
not certify what writing to it does.

## Usage

``` r
certified_fingerprints(registry = tested_fingerprints())
```

## Arguments

- registry:

  Data frame of tested fingerprints.

## Value

A character vector, possibly empty.

## Details

The conformance run itself declares the measured list instead, and must:
the surface it is about to certify has no date yet by definition, so
requiring one would recreate the ordering trap the ceiling already has —
the run could never earn what it exists to earn.
