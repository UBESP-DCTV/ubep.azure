# Whether the month's reports are late

From the second day of the month on, with the month not complete, or
while a month lost still misses a report. Computed here and not in the
query of the alarm, so that a test covers it. A forced run speaks about
another month and cannot say the real one is late: it says false, and
the next run of the timer says the truth.

## Usage

``` r
report_late(giorno, completo, forzato, persi = 0L)
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

## Value

One logical.
