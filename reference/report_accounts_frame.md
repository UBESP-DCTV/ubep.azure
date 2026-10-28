# Turn the answer of `accounts` into a frame, or refuse it

The answer is a reading only if it speaks about everyone who was asked.
A missing name read as it stands would be a person who never entered, so
an answer that leaves one out, or that is not shaped as the module
shapes it, is refused whole: the caller treats the server as not read.
An entry that lacks one of the date keys, or has a date that is there
but does not read, refuses the answer too, because neither is the same
as no date (a key with a null value).

## Usage

``` r
report_accounts_frame(payload, asked)
```

## Arguments

- payload:

  The `payload` of a
  [`module_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_accounts.md)
  answer.

- asked:

  Character vector of the names that were asked.

## Value

A data frame with `username`, `exists`, `firstvisit`, `lastlogin` and
`lastactivity`, the last three `POSIXct` in UTC with `NA` for an absent
date; `NULL` when the answer is not a reading.

## Details

Names are compared without regard to case or to spaces at the edges, and
the frame carries them that way.
