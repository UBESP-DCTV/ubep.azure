# The lines of the entries' stopped rows, in both languages

One line for each row of an entry of the first sign-in or of the year
without access whose request is stopped, `ferme` as
[`report_assemble()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_assemble.md)
builds it.

## Usage

``` r
report_stopped_lines(stopped)
```

## Arguments

- stopped:

  The `ferme` of an entry, or `NULL`.

## Value

A list of two character vectors, `it` and `en`, empty without stopped
rows.
