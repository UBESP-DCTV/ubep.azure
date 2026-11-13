# The value each event wrote into one field, read whole

Up to the apostrophe that closes the value, the one followed by the next
field or by the end of `details`: a UPN can hold an apostrophe, and cut
at the first one `luca.d'amico` would read `luca.d`. For every intent
field; a value ends early only where somebody typed `', name = '` inside
it. The one reader of a whole value:
[`log_executed_row()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executed_row.md)
rebuilds the version carried out with it, and the monthly report reads
the name each execution carried out
([`report_person_since()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_person_since.md)),
so that the values the two compare are read the same way, and brought to
the register's form in the same place,
[`log_value_as_register()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_value_as_register.md).

## Usage

``` r
log_written_value(events, field)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- field:

  One field name.

## Value

A character vector, one value per event, `NA` where the event did not
write the field or the value does not read.
