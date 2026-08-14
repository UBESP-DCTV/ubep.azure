# Say what was read back, in one line a person can read

`applied_as` carries the read-back and not the return code: an outcome
that only said "no error" would be the same thing as the four spike
cases that reported `true` while doing something else. After a
revocation the read-back finding nothing is the success, so absence has
to be sayable too.

## Usage

``` r
round_applied_as(row)
```

## Arguments

- row:

  One row of a `state` reply, or `NULL` when the pair is not there.

## Value

A single string.

## Details

The expiration shown is the value REDCap stores, which is the day after
the last day of access. That is the boundary, not an off-by-one: from
[`intake_request()`](https://ubesp-dctv.github.io/ubep.azure/reference/intake_request.md)
onwards every component speaks the stored value.
