# Validate a provisioning request

Returns the data-error codes of the spec's taxonomy. These are errors
that belong to whoever filed the request, not to IT: a request carrying
them is badly filled in, not badly transported.

## Usage

``` r
validate_request(request)
```

## Arguments

- request:

  A named list, one request as described in the spec.

## Value

A character vector of error codes; empty when the request is valid.

## Details

Errors that need the instance to be answered — a project, role or DAG
that does not exist there — cannot be decided here and are left to the
module.
