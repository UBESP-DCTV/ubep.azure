# The lines of the accesses that expire this month, in both languages

Information only: it is not an item to look at, and it does not count in
the number of the subject. Each expiration is one line with the person,
the server, the project and the day, as in the approved draft
(`Name: server, progetto N, scade il AAAA-MM-GG.`). Without any, no
lines at all, since "none" would be a claim and the item is only a
reminder.

## Usage

``` r
report_expiring_lines(rows, period)
```

## Arguments

- rows:

  The `scadenze` of a referent's report.

- period:

  What
  [`report_month()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_month.md)
  answered: the month named is the one of the reading.

## Value

A list of two character vectors, `it` and `en`; empty without rows.
