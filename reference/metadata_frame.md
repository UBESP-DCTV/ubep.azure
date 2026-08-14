# The four dictionary columns the comparison reads, in the API's vocabulary

REDCap holds one schema under two sets of names: the CSV a project
imports says `Variable / Field Name`, the API's metadata says
`field_name`. A map between two sets of names is exactly where this
project's worst class of bug lives, so the map is small, explicit, and
covered by a test that sends the packaged dictionary back through it and
requires the comparison to conform.

## Usage

``` r
metadata_frame(fields)
```

## Arguments

- fields:

  The parsed metadata, a list of one list per field.

## Value

A data frame with the four columns
[`compare_dictionary()`](https://ubesp-dctv.github.io/ubep.azure/reference/compare_dictionary.md)
reads.
