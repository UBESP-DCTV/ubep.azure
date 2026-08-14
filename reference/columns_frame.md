# Assemble named character columns into a data frame, untouched by either

`check.names = FALSE` is what keeps a name like `Variable / Field Name`
from being mangled into a syntactic one, and `stringsAsFactors = FALSE`
is what keeps a character column character instead of becoming a factor.

## Usage

``` r
columns_frame(columns)
```

## Arguments

- columns:

  A named list of equal-length character vectors, one per column, in the
  order they should appear.

## Value

A data frame built from `columns`, names and types as given.
