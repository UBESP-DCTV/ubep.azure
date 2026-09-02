# Where a log window starts, in the clock the instance stamps with

Two jobs in one small function, and the second is what makes the first
safe.

## Usage

``` r
log_since(at, hours = 24L)
```

## Arguments

- at:

  When the round ran, `"%Y-%m-%d %H:%M"` in UTC.

- hours:

  How far back to reach.

## Value

The start of the window as REDCap writes it, or `NA_character_` if `at`
does not parse — a window starting at a wrong hour is worse than a
caller that has to say it could not build one.

## Details

It converts, because REDCap stamps the log with the server clock while
the channel keeps UTC: measured on 2026-09-01, a round that ran at 21:03
UTC appears in the log at 23:03. And it reaches back, because that
conversion assumes the instance sits in Italian civil time — true of the
three served today, and not a property this package can check. With a
day of margin an hour out in either direction still leaves every round
since yesterday inside the window.

The margin costs a longer answer and nothing else. What decides anything
is the filtering done on the rows, never the boundary.
