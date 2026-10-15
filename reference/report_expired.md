# Whether an access is past its last day, on a given date

REDCap refuses the pair when `expiration` is today or earlier, so the
day written is already over.

## Usage

``` r
report_expired(expiration, today)
```

## Arguments

- expiration:

  The register's `expiration`, `"%Y-%m-%d"` or empty.

- today:

  The date to judge on.

## Value

A logical vector; an empty or unreadable date is not expired.
