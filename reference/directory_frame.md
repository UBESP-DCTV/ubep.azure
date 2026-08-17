# Turn parsed Graph user records into a frame of one row per account

Every column keeps the type the wire gives it, which is not the same as
guessing one. Eight of the nine fields arrive as strings and stay
character, with a field the record does not carry becoming `""` rather
than `NA` — the absence is what it means, and 1.170 accounts of the
tenant have no `officeLocation`. `accountEnabled` is a JSON boolean and
stays logical: carried as the string `"FALSE"` it would be a value every
`if ()` reads as false and every
[`nzchar()`](https://rdrr.io/r/base/nchar.html) reads as present.
`otherMails` is the one field that is an array on the wire and stays a
list column, because collapsing it would leave the resolution splitting
it back apart on a separator no rule says an address cannot contain.

## Usage

``` r
directory_frame(users)
```

## Arguments

- users:

  The parsed `value` array, a list of one list per account.

## Value

A data frame with one row per account and the columns
[`directory_fields()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_fields.md)
names, in that order.
