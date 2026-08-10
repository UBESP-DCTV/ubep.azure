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
