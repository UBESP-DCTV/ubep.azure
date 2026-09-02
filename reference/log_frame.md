# Turn REDCap's event log export into a frame of character columns

Turn REDCap's event log export into a frame of character columns

## Usage

``` r
log_frame(entries)
```

## Arguments

- entries:

  The parsed export, a list of one list per event.

## Value

A data frame with one row per event and always
[`log_fields()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_fields.md)
as columns, empty of rows when nothing happened in the window.
