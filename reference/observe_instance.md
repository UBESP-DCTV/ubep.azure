# Turn one instance's `state` reply into a single observation row

Pure: no network. The v1 of the job observes and does not compare, so
this never touches
[`provisioning_diff()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_diff.md).
That is not a disabled write path but a missing comparison: with no
register, every real pair would be classified `revocato`, so the diff is
not dangerous but empty of information — while version, gate,
reachability and expirations are properties of reality alone and are
available now.

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
