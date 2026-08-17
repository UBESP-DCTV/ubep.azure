# Fold an address to the form the comparison happens in

The whole resolution rests on this being applied to both sides of every
comparison. Measured on the tenant on 2026-08-15: 74 accounts carry the
contact address with spaces at the edges, and a service-side `eq` would
have missed all 74 in silence — reporting `absent` for people who exist,
which is the verdict that opens the creation branch. Reading the
directory whole is what makes the comparison ours, and therefore able to
normalize at all.

## Usage

``` r
identity_normalize(values)
```

## Arguments

- values:

  A character vector, or anything coercible to one.

## Value

A character vector, trimmed and folded to lower case.
