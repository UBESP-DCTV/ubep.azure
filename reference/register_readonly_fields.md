# The register fields only the job writes

Marked `@READONLY` in the dictionary, which governs the form and not the
API: the job keeps writing them while a requester cannot. Without the
tag a requester could type `applied` into the outcome, and the register
would carry a success nobody produced.

## Usage

``` r
register_readonly_fields()
```

## Value

A character vector of field names.

## Details

`owned_by` is written by the channel alone, and its value is not
believed as written: who owns a row is read from the event log
([`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md)).
