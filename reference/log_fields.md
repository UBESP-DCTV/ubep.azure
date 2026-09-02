# The five columns REDCap's event log answers with

Fixed here rather than derived from the answer, unlike
[`records_frame()`](https://ubesp-dctv.github.io/ubep.azure/reference/records_frame.md),
and the difference is what the two are for: a register record set is
whatever the project's dictionary holds today, while the log's shape
belongs to REDCap and does not move with the project. Deriving it would
make an empty window — the common case on a quiet night — come back with
no columns at all, and every reader would then have to guard against a
frame that has no `username`.

## Usage

``` r
log_fields()
```

## Value

A character vector of column names.
