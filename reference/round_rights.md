# The rights one instance reported, in the shape the gate consumes

The permission column is added only when the instance actually reported
it. Inventing a column of NAs would reach
[`scope_errors()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_errors.md)'s
closed failure by a different route and make the two cases
indistinguishable upstream, where they have to be told apart.

## Usage

``` r
round_rights(server, state)
```

## Arguments

- server:

  The instance name, which a `state` reply names once at the top and not
  on every row.

- state:

  What
  [`module_state()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_state.md)
  returned.

## Value

A data frame with `server`, `project_id`, `username`, and `user_rights`
only when it was reported.
