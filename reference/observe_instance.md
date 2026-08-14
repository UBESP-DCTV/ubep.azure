# Turn one instance's `state` reply into a single observation row

Pure: no network. The observer never calls
[`provisioning_diff()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_diff.md),
and not because the request register does not exist yet: it reads an
instance's state whole, with no pairs named, so a comparison here would
classify every real pair `revocato` regardless of how populated the
register grows to be. That is a property of what this job reads, not a
stage the register will outgrow — version, gate, reachability and
expirations are properties of reality alone, and stay available without
that comparison.

## Usage

``` r
observe_instance(server, state, today = Sys.Date())
```

## Arguments

- server:

  The instance name.

- state:

  What
  [`module_state()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_state.md)
  returned: a list with `ok`, `errors`, `payload` and `gate`.

- today:

  The date expirations are compared against. Injected rather than read
  from the clock so a fixture cannot turn red on a calendar date for a
  reason unrelated to the code.

## Value

A one-row data frame.

## Details

A server that cannot be reached becomes a row rather than an exception,
for the same reason
[`provisioning_audit()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_audit.md)
does it: one instance being down must not hide the state of the others.

`scadute` counts pairs REDCap should already be refusing. It is the one
of the three drifts that needs no desired state, and the boundary is
inclusive because REDCap denies on `expiration <= TODAY` — the day
written is already interdicted.
