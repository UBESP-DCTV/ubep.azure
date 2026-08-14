# The pairs one instance has to be asked about

Two questions need a state read and they are not the same question: the
diff needs the grantees' rows, the scope gate needs the requesters'.
Asking for both in one call is not an optimization — it is what makes
the gate and the diff see the same instant of reality, instead of two
instants a write could fit between.

## Usage

``` r
round_state_pairs(requests, asks)
```

## Arguments

- requests:

  The validated requests bound for this instance, each carrying
  `username` and `project_id`.

- asks:

  The rows of
  [`scope_pairs()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_pairs.md)
  for this instance.

## Value

A list of `list(username, project_id)`, deduplicated.
