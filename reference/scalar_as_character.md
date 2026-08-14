# Read one list element as a length-one character, or as an empty string

Both frame builders below walk a REDCap list-of-lists field by field,
and both meet the same two edges there: a field a given record does not
carry, and a value REDCap hands back longer than one (a checkbox field,
most often). Neither is an error at this layer — it becomes `""`, so a
shape this reader is not the one meant to judge cannot raise before the
caller's own shape check gets to see it.

## Usage

``` r
scalar_as_character(value)
```

## Arguments

- value:

  One raw list element: `NULL`, length one, or longer.

## Value

A length-one character vector.
