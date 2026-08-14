# The rights an instance has to be asked about before a request is applied

The scope gate asks whether the person who filed a request may manage
the users of the project they filed it for. That question is about the
**requester**, not about the person the request is for, so it needs a
state read the channel does not otherwise make:
[`module_state()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_state.md)
answers for the pairs it is given, and the pairs it is given are the
grantees.

## Usage

``` r
scope_pairs(register)
```

## Arguments

- register:

  The register as a data frame, carrying at least `server`, `project_id`
  and `requested_by`.

## Value

A data frame with `server`, `project_id` and `username`, one row per
distinct triple. The requester travels under `username` because that is
the name
[`module_state()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_state.md)
expects in a pair.

## Details

Rows with no server or no project are not asked about. There is nothing
to ask — and
[`validate_request()`](https://ubesp-dctv.github.io/ubep.azure/reference/validate_request.md)
already reports the project one. A row with no requester is not asked
about either, and is refused by
[`scope_errors()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_errors.md)
instead: an unattributable row cannot be answered by any instance.
