# Compose the monthly mail to IT

One mail, and only when there is something in it. Eight sections,
numbered in this order: the rows with no referent to send them to, the
people the report cannot judge, the rows the log does not date, the
servers that were not read (with the reason, and how many pairs of
person and server fell back on Entra or could not be checked for the
year without access), the rows stopped on a disabled account (with
whether the person has ever entered the server, when the server was
read), and the rows stopped with an access executed (with the outcome
and its codes, whether the revocation is the one that stopped, the same
column of the access, or why it is missing when the name executed is not
known, and the owner). From 0.26.0 two more, from the suppression lists
of the mail service read on the day of the run
([`report_suppressed_for_it()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_suppressed_for_it.md)):
the active rows with a recipient on a list that suppresses, with the
request, the server, the project, the address, the list and the date of
the entry; and the referents on one. A row of the first or of the third
section that is stopped says its outcome. It has the referents' form to
review, and its number counts the rows, people and servers listed, a row
once even when it is in two sections, by its `record_id`. A section with
nothing in it is not announced.

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
