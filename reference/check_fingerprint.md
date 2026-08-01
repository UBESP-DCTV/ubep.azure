# Confirm the instance surface is one we have tested against

The major says which code path applies; the fingerprint says whether
that path is still the one we tested. An instance can be in the right
major and have a changed surface — the case no version comparison can
see.

## Usage

``` r
check_fingerprint(payload, registry = tested_fingerprints())
```

## Arguments

- payload:

  Parsed module response.

- registry:

  Data frame of tested fingerprints.

## Value

The effective gate, as a single string.

## Details

Downgrades only: a fingerprint can move an instance from `collaudata` to
`non_collaudata`, never the other way. An unknown fingerprint is not a
failure, it is a version waiting to be tested, and downgrading is how
the system asks for that instead of writing blind.
