# The real rows somebody actually asked about

The one filter that keeps the mass revocation from being reachable.
[`provisioning_diff()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_diff.md)
classifies as `revocato` every pair present in reality and absent from
the desired state, and the state read carries the requesters' own rows
because the scope gate needed them. Handed the unfiltered reply, the
diff would propose revoking the referents.

## Usage

``` r
round_actual(results, requests)
```

## Arguments

- results:

  The `results` of a `state` reply.

- requests:

  The requests this instance was asked to satisfy.

## Value

The subset of `results` whose pair appears in `requests`.

## Details

Absence means nothing (decision 5) and only an explicit `revoked` takes
something away. This is what makes that structural rather than
remembered.
