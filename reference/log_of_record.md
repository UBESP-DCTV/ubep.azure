# The events of the row that stands now under a record id

The rows of the log that belong to `record`, in the order REDCap gave
them, and of those only the current life of the row,
[`log_current_life()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_current_life.md).
Every reader of a row's log comes through here (who changed the row, who
approved it, which account is the channel), so none of them reads the
history of an earlier row that had the same id. REDCap reuses the ids of
deleted records: the register was emptied on 2026-09-01, and the first
request filed after it took id 1, which had been a field test's.

## Usage

``` r
log_of_record(events, record)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id.

## Value

The rows of `events` that belong to `record`, from its newest creation
on.
