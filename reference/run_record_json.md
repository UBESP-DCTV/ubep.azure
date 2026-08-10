# Serialize a run record, keeping list-valued fields as arrays

`auto_unbox` collapses a one-element vector into a scalar, which is
right for the counters and wrong for everything that is semantically a
list: a fleet with a single instance would emit a string where the alert
query expects an array, and the fault would stay hidden until the day
only one instance answers.

## Usage

``` r
run_record_json(record)
```

## Arguments

- record:

  What
  [`run_record()`](https://ubesp-dctv.github.io/ubep.azure/reference/run_record.md)
  returned.

## Value

A JSON string, one object.

## Details

This is the same length-one array trap the client already met on the
request side, where the declared fingerprints had to be sent as a list
because the registry holds one row. Same trap, other end of the wire.
