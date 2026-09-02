# Build the body that writes a seal back into the register

A third door beside the outcome and the identity, and it exists for the
reason those two are separate rather than for a new one: the columns are
fixed here so a bug cannot rewrite anything else.

## Usage

``` r
seal_payload(record_id, seal, state)
```

## Arguments

- record_id:

  The register record to write to.

- seal:

  The seal of what was applied, `""` when nothing was.

- state:

  One of
  [`seal_state_vocabulary()`](https://ubesp-dctv.github.io/ubep.azure/reference/seal_state_vocabulary.md).

## Value

A one-row data frame with exactly the seal columns.

## Details

It could not be a column of
[`outcome_payload()`](https://ubesp-dctv.github.io/ubep.azure/reference/outcome_payload.md),
and the reason is worth keeping. That body is written on every outcome,
so a seal column would carry a value on every outcome too — and the
honest default is empty. A `data_error` on an already applied row would
then blank the seal, quietly taking the protection off the one kind of
row that has any.
