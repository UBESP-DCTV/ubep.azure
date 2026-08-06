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

A missing or malformed `surface_fingerprint` downgrades the same way: an
absent field makes `NULL %in% known` a zero-length logical, and an
unguarded `if()` around it raises "argument is of length zero" instead
of answering. The shape is checked before the comparison, never after,
the same reason
[`parse_module_response()`](https://ubesp-dctv.github.io/ubep.azure/reference/parse_module_response.md)
checks `contract_version`'s shape before coercing it — a JSON array of
one element parses to an R list, not a character scalar, and would
otherwise be compared (and could match) where a scalar belongs.
