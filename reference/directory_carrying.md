# The accounts whose addresses hold a contact

One `%in%` on the addresses of the whole directory, flat
([`directory_folds()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_folds.md)),
in place of `contact %in% addresses` asked of every account with a
closure of its own. The same answer: for one value, `%in%` matches the
same pairs in both directions, a missing value with a missing one
included.

## Usage

``` r
directory_carrying(folds, contact)
```

## Arguments

- folds:

  The directory folded,
  [`directory_folds()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_folds.md).

- contact:

  One normalized contact address.

## Value

A logical vector, one per account of the directory.
