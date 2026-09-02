# The fields the seal does not cover

Every read-only field, plus the one a person writes that must still stay
out of the seal.

## Usage

``` r
register_unsealed_fields()
```

## Value

A character vector of field names.

## Details

The two lists were the same until row protection needed them apart, and
the reason they were the same is worth keeping: a field the channel
writes is a field a requester must not, and a field the channel writes
must not move the seal, or the round would accuse itself one pass after
every write.

`approved_seal` breaks that coincidence. It carries the seal it
approves, so if writing it moved the seal it would never match the row
it was written for — the comparison would chase itself and no change
could ever be approved. But a person writes it, so it cannot be
`@READONLY`, and
[`register_readonly_fields()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_readonly_fields.md)
is also what the dictionary test checks the tags against. Two questions,
two lists.
