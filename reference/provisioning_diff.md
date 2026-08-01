# Compare the desired state with the real one

The engine of the channel, and the one piece that decides what will
actually happen. Pure: no network, no state of its own.

## Usage

``` r
provisioning_diff(desired, actual)
```

## Arguments

- desired:

  List of validated requests.

- actual:

  List of rows as returned by the module's `state`.

## Value

A data frame with one row per pair.

## Details

The unit of comparison is the (user, project) pair, not the user: the
same person may legitimately hold different rights in different
projects, and REDCap stores one row per pair.

A field wanted absent but present in reality is an update, never a noop.
That follows from `apply` asserting the full state rather than a delta,
so a DAG nobody asked for has to show up as a difference instead of
being tolerated.
