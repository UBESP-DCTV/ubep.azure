# Whether two project ids name the same project

A project is a number, and `09003` is the project `9003`. Anything that
is not all digits is compared as it is.

## Usage

``` r
same_project(a, b)
```

## Arguments

- a, b:

  Two project ids, one string each.

## Value

`TRUE` or `FALSE`.
