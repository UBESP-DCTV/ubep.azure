# Compose the monthly mail to IT

One mail, and only when there is something in it. Five sections,
numbered in this order: the rows with no referent to send them to, the
people the report cannot judge, the rows the log does not date, the
servers that were not read (with the reason, and how many pairs of
person and server fell back on Entra or could not be checked for the
year without access), and the rows stopped on a disabled account (with
whether the person has ever entered the server, when the server was
read). It has the referents' form to review, and its number counts the
rows, people and servers listed. A section with nothing in it is not
announced.

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
