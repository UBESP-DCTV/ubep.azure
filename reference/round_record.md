# Build the record the channel's round leaves behind

The channel keeps no copy of what it reconciles, so a round leaves no
other trace than the outcomes it writes into the register — and those
say nothing about the round itself. This record is that.

## Usage

``` r
round_record(esito, scrittura)
```

## Arguments

- esito:

  What
  [`provisioning_reconcile()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_reconcile.md)
  returned.

- scrittura:

  Whether the round was allowed to write, so a reader of the telemetry
  can tell the same counts apart simulated and real.

## Value

A named list, ready to be serialized as one JSON object.

## Details

`registro_letto` is the channel's counterpart of the observer's
`letture_riuscite`, and it exists for the same reason: an alarm that
fired on the absence of a record would be satisfied by a round that
started, stopped on a drifted dictionary and exited. The question the
alarm has to ask is not "did it run?" but "did it get to read the
register?".

It also separates an empty register from an unreachable one. Both give
`righe = 0`, and only one of them needs somebody.

One counter per word of the closed outcome vocabulary, named after the
word rather than summed into a single "errors": a night of data errors
and a night of transport errors look identical in a total, and they go
to different people — the referent who filled the row, and IT.
