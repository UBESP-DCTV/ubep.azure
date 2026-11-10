# The lines of the accesses activated in the month, in both languages

A new request says whether its account was new, from the `account`
column
[`report_assemble()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_assemble.md)
computes on the date Entra made the account; a modified one says it was
modified. A stopped one says its outcome,
[`report_stopped_words()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_stopped_words.md),
and one whose name executed is not known (`nome_eseguito` empty) says so
in place of the name, as the mail to IT.

## Usage

``` r
report_activated_lines(rows)
```

## Arguments

- rows:

  The `attivati` of a referent's report.

## Value

A list of two character vectors, `it` and `en`.
