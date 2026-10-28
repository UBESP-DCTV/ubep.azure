# Read one of the lists of people of a ledger entry

An entry written by the 0.22.0 holds the people as an array of
addresses, with no server: they read with an empty `server`, "all of the
person's servers". An entry from now on holds an array of
`{upn, server}`. A list that is absent reads as none.

## Usage

``` r
report_ledger_pairs(x)
```

## Arguments

- x:

  What `jsonlite::fromJSON(simplifyVector = FALSE)` made of it.

## Value

A data frame of `upn` and `server`, or `NULL` when it is neither shape:
the ledger does not read.
