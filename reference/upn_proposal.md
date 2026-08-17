# Propose the first free UPN with a numeric suffix

The convention was fixed by UBEP on 2026-08-15: `nome.cognome.2`, `.3`,
and so on, taking the first free one. It reads as a naming detail and is
what makes a collision workable — without a proposal the row hands a
person two questions and no material, and with it exactly one is left,
the one only the referent can close.

## Usage

``` r
upn_proposal(composed, taken)
```

## Arguments

- composed:

  The UPN
  [`compose_upn()`](https://ubesp-dctv.github.io/ubep.azure/reference/compose_upn.md)
  built, already taken.

- taken:

  Normalized UPNs held by the whole tenant — guests included, because
  uniqueness is tenant-wide and not a property of the candidates.

## Value

A single UPN, free in the directory that was swept.

## Details

The search terminates because each attempt is a value not yet in
`taken`, and `taken` is finite.
