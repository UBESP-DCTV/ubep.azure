# Which events wrote one of these fields

Reads `details`, which REDCap fills with the fields an event wrote and
the values it gave them, `role_name = 'read only'`.

## Usage

``` r
log_wrote(events, fields)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- fields:

  Field names to look for.

## Value

A logical vector, one answer per event.
