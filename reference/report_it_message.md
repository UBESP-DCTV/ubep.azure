# Compose the monthly mail to IT

One mail, and only when there is something in it: the rows with no
referent to send them to, the people the report cannot judge, the rows
the log does not date. It has the referents' form to review, and its
number counts the rows and people listed. A section with nothing in it
is not announced.

## Usage

``` r
report_it_message(it, period)
```

## Arguments

- it:

  The `it` part of what
  [`report_assemble()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_assemble.md)
  answered.

- period:

  What
  [`report_month()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_month.md)
  answered.

## Value

A list with `subject`, `body`, `forma` and `n`.
