# Whether each of these stamps reads as one of the log's

REDCap writes its stamps `"%Y-%m-%d %H:%M"`, to the minute, in the
instance's civil time. A stamp that does not start that way cannot be
placed before or after anything, and every reader that dates by the log
answers "unknown" on it rather than comparing a string it cannot read.

## Usage

``` r
log_stamp_reads(stamps)
```

## Arguments

- stamps:

  The stamps, as the log's `timestamp` column carries them.

## Value

A logical vector, one answer per stamp.
