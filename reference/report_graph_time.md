# Read a time as Microsoft Graph writes it

Read a time as Microsoft Graph writes it

## Usage

``` r
report_graph_time(value)
```

## Arguments

- value:

  A string such as `"2026-10-08T09:12:33Z"`, or `""`.

## Value

A `POSIXct` in UTC, `NA` when the value is absent or does not read.
