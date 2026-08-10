# Turn one register row into a request

The register's field names are the request's field names, so there is no
map between the two and no key can fall into a default without raising.
That is the whole reason the names were chosen.

## Usage

``` r
request_from_row(row)
```

## Arguments

- row:

  A one-row data frame from the register.

## Value

A named list holding only the fields that carry a value.

## Details

A blank cell is dropped rather than carried as `""`. The difference
matters downstream:
[`provisioning_diff()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_diff.md)
reads an absent field as "not set", while an empty string would be a
value nobody asked for — and a DAG nobody asked for is an update, never
a `noop`.
