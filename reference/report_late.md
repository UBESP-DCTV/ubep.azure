# Whether the month's reports are late

From the second day of the month on, with the month not complete or with
who is due not known, or while a month lost still misses a report. Who
is due is not known when no reading of the month was whole, today or on
an earlier day: nothing is counted then, and a month counted on nothing
reads complete. Computed here and not in the query of the alarm, so that
a test covers it. A forced run speaks about another month and cannot say
the real one is late: it says false, and the next run of the timer says
the truth.

## Usage

``` r
report_late(giorno, completo, forzato, persi = 0L, sconosciuti = FALSE)
```

## Arguments

- giorno:

  The day of the month the run is in, in Rome.

- completo:

  Whether every report of the month has left.

- forzato:

  Whether the month was forced.

- persi:

  How many months lost still miss a report.

- sconosciuti:

  Whether who is due is not known, from
  [`provisioning_report()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_report.md)'s
  `dovuti_sconosciuti`.

## Value

One logical.
