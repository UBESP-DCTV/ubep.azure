# The endpoint this package talks to, from the base it was handed

One place builds the URL for both calls. A scheme is dropped rather than
honored, so a base handed over as http is corrected instead of sending a
bearer token in clear — and it is corrected once, where two copies would
be the place to fix that in one call and leave it standing in the other.

## Usage

``` r
directory_endpoint(base_url)
```

## Arguments

- base_url:

  The Graph endpoint, as in `"host.example.org/v1.0"`. It is an argument
  and not a constant in this file: this repository is public, and an
  endpoint written in is an endpoint published. A scheme is dropped
  rather than honored, so a base handed over as http is corrected
  instead of sending a bearer token in clear.

## Value

The endpoint, always https and with no trailing slash.
