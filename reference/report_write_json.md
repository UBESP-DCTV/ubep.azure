# Write a file of the state directory whole, or leave the old one

Written beside its final name and moved over it, so a run killed halfway
leaves the old file or the new one, and not half of either.

## Usage

``` r
report_write_json(path, json)
```

## Arguments

- path:

  Where the file lives.

- json:

  The content.

## Value

Whether the file now holds `json`.
