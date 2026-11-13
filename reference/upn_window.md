# The names a round asks REDCap about, for one row that may create

Decided on 2026-11-10 (item 4 (b') of the 0.26.0): a name REDCap still
knows counts as taken, as a UPN held on Entra does, since whoever were
given it would find on the instances the projects of the old login. So
before a verdict that can make an account the round asks the production
instances about the names it could create: the composed one, when it is
free on Entra, and the first `size` suffixes free on Entra, in the order
[`upn_proposal()`](https://ubesp-dctv.github.io/ubep.azure/reference/upn_proposal.md)
takes them. A fixed window, so that one call per instance is enough: the
proposal is the first name of the window REDCap does not know, and a
window REDCap knows whole stops the row
([`resolve_against_directory()`](https://ubesp-dctv.github.io/ubep.azure/reference/resolve_against_directory.md)).

## Usage

``` r
upn_window(composed, taken, size = 5L)
```

## Arguments

- composed:

  The UPN
  [`compose_upn()`](https://ubesp-dctv.github.io/ubep.azure/reference/compose_upn.md)
  built.

- taken:

  Normalized UPNs held by the whole tenant, as for
  [`upn_proposal()`](https://ubesp-dctv.github.io/ubep.azure/reference/upn_proposal.md).

- size:

  How many suffixes the window holds.

## Value

A character vector: the composed name first when it is free on Entra,
then the suffixes, written as `composed` is.
