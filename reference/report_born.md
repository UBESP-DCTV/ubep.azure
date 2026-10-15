# When the row that stands now was made, from the creation log

The same event
[`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
names the creator from: the creations asked of REDCap with
`logtype = "record_add"`, newest first, so that a record id used twice
answers with the life standing now.

## Usage

``` r
report_born(events, records)
```

## Arguments

- events:

  The creation events, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns them when asked with `logtype = "record_add"`.

- records:

  The record ids to answer about.

## Value

A character vector as long as `records`, holding the stamp in the
instance's civil time, `"%Y-%m-%d %H:%M"`, or `""` where no creation
names that row or its stamp does not read as one.
