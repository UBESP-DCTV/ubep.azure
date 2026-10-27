# The intent fields added after the first seals were written

Listed and not derived, decided on 2026-10-27. The seal is a hash of the
intent fields joined in order, so a field added to them, even empty,
changes the seal of every row: on the first round after the dictionary
is imported every row the round ever carried out would read as changed
with nobody on record for it, and
[`change_needs_approval()`](https://ubesp-dctv.github.io/ubep.azure/reference/change_needs_approval.md)
holds a sealed row whose change has no author. Every executed row would
be held, and every owner mailed.

## Usage

``` r
register_late_seal_fields()
```

## Value

A character vector of field names.

## Details

So a field in this list enters the seal only when it holds a value,
after the others, as its name and its value
([`request_seal()`](https://ubesp-dctv.github.io/ubep.azure/reference/request_seal.md)):
empty, the seal is the one written before the field existed, bit for
bit. A rule on empty fields in general would change the seals already
written, since the old fields are sealed empty too. An intent field
added from now on goes in here, and a test fails while it is neither
among the fields sealed from the start nor in this list.
