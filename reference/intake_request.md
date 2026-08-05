# Take a request in, validated and normalized, or not at all

The single door into the pure layer. Validation and the expiration
conversion happen together because separating them would leave a way to
get a valid request that was never converted, and the way to get the
conversion wrong is to forget it.

## Usage

``` r
intake_request(request)
```

## Arguments

- request:

  A named list, one request as described in the spec.

## Value

A list with `errors` and `request`; `request` is `NULL` when `errors` is
not empty.

## Details

From here on every component — the diff, `apply`, `before` and `after` —
speaks the value REDCap stores. The request speaks what a person means.
