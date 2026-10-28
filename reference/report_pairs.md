# The people a report named, as the ledger keeps them

A person and a server, one row each: the same person can be named for
one server and not for another, and a repeated sentence about "reported
before" has to tell them apart.

## Usage

``` r
report_pairs(x = NULL)
```

## Arguments

- x:

  A data frame of `upn` and `server`, or `NULL` for none.

## Value

A data frame of `upn` and `server`, both character.
