# Compare what was read back against what was asserted

The criterion is the re-read, never the return value: in the spike four
cases out of four reported success while three had done something else.
A missing row is the loudest failure and must not read as nothing to
compare.

## Usage

``` r
compare_readback(expected, actual)
```

## Arguments

- expected:

  Named list of the asserted fields.

- actual:

  Named list read back, or `NULL` when no row came back.

## Value

A list with `conforms` and `differences`.
