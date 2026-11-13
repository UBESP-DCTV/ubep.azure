# A value of the log in the form the register gives it

The one place where a value read from `details` would be brought to the
form the API gives for the same field, before anything compares the two:
the seal of a version rebuilt from the log,
[`log_executed_row()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executed_row.md),
and the names the report dates,
[`report_person_since()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_person_since.md),
both read through
[`log_written_value()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_written_value.md),
which calls this.

## Usage

``` r
log_value_as_register(value, field)
```

## Arguments

- value:

  Values as `details` carries them, `NA` where none was read.

- field:

  The field they were written into.

## Value

`value`, in the register's form.

## Details

Today it changes nothing, decided on 2026-11-12: M1 found no difference
on the live register between the values the log carries and those of the
register (non-ASCII letters, capitals, spaces at the edges, fields never
written), and the forms it did not cover (apostrophes, `& < >`, quotes,
dates written by the form, emptied fields, a `project_id` with a leading
zero) are to be measured on the test instance (M2). A difference found
there, systematic and reversible (an HTML entity, the order of a date),
is undone here, by field. A wrong undoing cannot pass for a right one:
the rebuilt version would no longer give the channel's seal, and the row
would read as not verified.
