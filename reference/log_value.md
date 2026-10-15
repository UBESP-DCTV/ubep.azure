# The value each event wrote into one field

Reads `details`, `applied_seal = '0a1b2c3d4e5f'`. Meant for the seals,
which are twelve hex characters and so never hold the quote that would
end the value early.

## Usage

``` r
log_value(events, field)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- field:

  One field name.

## Value

A character vector, one value per event, `""` where the event did not
write the field.
