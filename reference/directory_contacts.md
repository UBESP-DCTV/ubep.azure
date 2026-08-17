# The addresses a directory row can be found by

Both carriers are read: `officeLocation`, where the historical flow put
the contact address and where 6.494 accounts still carry it, and
`otherMails`, the proper carrier this package writes from now on. The
fallback retires when the sweep counts zero accounts with an address in
the first — a number, not an intention, and one the sweep produces by
itself every round.

## Usage

``` r
directory_contacts(directory)
```

## Arguments

- directory:

  A directory frame as
  [`directory_users()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_users.md)
  returns.

## Value

A list with one character vector per row, normalized, with empties
dropped so that an empty criterion cannot match an empty field.
