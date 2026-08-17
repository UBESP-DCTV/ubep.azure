# Keep only the rows that are not what the register already says

`outcome_at` is deliberately outside the default comparison: it changes
every run by construction, so including it would make every row differ
and the filter would filter nothing. Without the filter every quiet
night rewrites every row, and the alert on the outcome field becomes
background noise — which is the thing people stop reading, and the alert
exists to be read.

## Usage

``` r
round_changed(
  register,
  payload,
  fields = c("outcome", "outcome_detail", "applied_as")
)
```

## Arguments

- register:

  The register as read, before the round rewrote anything in it. Handed
  the frame the round has already mutated, this compares a value against
  itself and reports that nothing ever changes.

- payload:

  The rows this round produced, from
  [`outcome_payload()`](https://ubesp-dctv.github.io/ubep.azure/reference/outcome_payload.md)
  or from
  [`identity_payload()`](https://ubesp-dctv.github.io/ubep.azure/reference/identity_payload.md).

- fields:

  The columns a change can show in. The default is the three an outcome
  can differ in; the identity body passes its own two.

## Value

`payload`, reduced to the rows that changed something.

## Details

One function with a `fields` argument rather than a copy per family, for
the reason
[`register_field_import()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_field_import.md)
is one transport for two doors: two copies of the same comparison are a
place to fix a defect once and leave it standing in the other. What
differs between the families is which columns can carry a change, and
that is exactly what the argument says.
