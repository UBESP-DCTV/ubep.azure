# Did the instance show what the write asked for

Confirmation is by presence and not by field-by-field equality, and the
difference is deliberate: REDCap normalizes what it stores — a role
name's spacing, a case — and a row that had to match exactly could
become impossible to confirm and would be retried for ever. Presence is
the fact the write was about. Disagreement on the fields stays visible
in `applied_as`, and the next round's diff is where the design acts on
it.

## Usage

``` r
round_write_confirmed(operation, observed)
```

## Arguments

- operation:

  `"apply"` or `"revoke"`, from the batch that was written.

- observed:

  What
  [`round_observed()`](https://ubesp-dctv.github.io/ubep.azure/reference/round_observed.md)
  returned for this entry.

## Value

`TRUE` when the write is confirmed: the pair is there after an apply, or
gone after a revoke.
