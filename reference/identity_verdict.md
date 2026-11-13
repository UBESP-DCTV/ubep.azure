# Say what the resolution decided about one row

Say what the resolution decided about one row

## Usage

``` r
identity_verdict(
  identity,
  username = "",
  errors = character(),
  composed = "",
  known_to_redcap = FALSE
)
```

## Arguments

- identity:

  One of the six words, or `""` when the row could not be resolved and
  has to stop.

- username:

  The UPN, the proposal, or `""`.

- errors:

  Codes, addressed by their prefix.

- composed:

  The name
  [`compose_upn()`](https://ubesp-dctv.github.io/ubep.azure/reference/compose_upn.md)
  built for this row, carried out of here so that the creation can
  create **the one that was checked**. It is read only on `absent`,
  which is the verdict that says it was free, and it is not the same
  thing as `username`: a name that does not exist yet is not a
  confirmation and does not belong in the register.

- known_to_redcap:

  Whether the composed name is free on Entra and known to REDCap on a
  production instance (0.26.0): a `collision` with nobody in the
  directory to look at, whose message says so.

## Value

A list with `identity`, `username`, `errors`, `composed` and
`known_to_redcap`.
