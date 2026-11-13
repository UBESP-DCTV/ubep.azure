# Which events have the form of the seals door

`details` holding `applied_seal` and at most `seal_state` beside it,
nothing else: the door has written only those two fields since the seal
exists, and REDCap logs only the fields an import changed. A seal
written with any other field, a referent's CSV carrying the row and its
seal, or an outcome whose *Read back as* quotes a seal, does not have
it.

## Usage

``` r
log_seals_door(events)
```

## Arguments

- events:

  Events of the log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns them.

## Value

A logical vector, one answer per event.
