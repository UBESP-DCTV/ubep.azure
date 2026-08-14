# Which dictionary differences stop the round and which are only reported

Five of the seven codes change what the round reads and one of them — a
`@READONLY` that fell — means a requester may have typed `applied` into
the outcome, so the register could be carrying a success nobody
produced. The other two cannot: a field the round ignores does not
corrupt its reading, and choices that could not be compared are the
declared consequence of calling without the fleet list.

## Usage

``` r
round_schema_verdict(differences)
```

## Arguments

- differences:

  The `differences` of
  [`compare_dictionary()`](https://ubesp-dctv.github.io/ubep.azure/reference/compare_dictionary.md).

## Value

A list with `blocks`, `blocking` and `tolerated`.
