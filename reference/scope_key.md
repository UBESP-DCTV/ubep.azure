# The key three fields make, with a separator that cannot occur in them

Same discipline as the register's own key, and for the same reason:
joined without a separator, `("edc05", 90, "3a@x")` and
`("edc05", 903, "a@x")` read as one string, and a lookup would answer
for the wrong pair. A control character occurs in none of the three.

## Usage

``` r
scope_key(server, project_id, username)
```

## Arguments

- server, project_id, username:

  The three parts, as character vectors.

## Value

A character vector of keys.
