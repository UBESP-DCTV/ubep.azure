# Where a field written by an event starts in its details

REDCap logs an edit as `field = 'value'`, the fields apart by a comma
and a space or a line break. So a field starts at the start of
`details`, or right after a comma, and its name is followed by `=` and
the apostrophe that opens the value. Searched anywhere in `details`, as
before 2026-11-12, a field name matched inside the value of another
field: the channel's *Read back as*,
`applied_as = 'role_name=...; dag_name=...; expiration=...'`
([`round_applied_as()`](https://ubesp-dctv.github.io/ubep.azure/reference/round_applied_as.md)),
read as a write of all three, measured on 2026-11-12 (M1b) on 46 events
out of 102 that "wrote" `role_name`, on every row of the register. The
name has to be followed by the apostrophe too, which a value that quotes
`name=` does not carry.

## Usage

``` r
log_field_at(fields)
```

## Arguments

- fields:

  Field names, one or more.

## Value

A regular expression, Perl syntax, that matches up to and including the
apostrophe that opens the value.

## Details

What it cannot tell apart is a value that holds `', field = '` itself:
the log does not escape an apostrophe inside a value, and no reading of
the text can say where such a value ends.

The one pattern every reader of a field in `details` starts from:
[`log_wrote()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_wrote.md),
[`log_value()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_value.md),
[`log_written_value()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_written_value.md),
and the check of a whole value in
[`log_change_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_change_authors.md).
