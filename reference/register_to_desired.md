# Turn the register into the desired state

The register declares requests; it does not describe reality. A pair
that exists in REDCap and appears nowhere here means nothing, so this
function never produces a revocation that a person did not ask for: only
`request_status = "revoked"` does that.

## Usage

``` r
register_to_desired(register)
```

## Arguments

- register:

  The register as a data frame, one row per pair, carrying at least
  `record_id` and `request_status`.

## Value

A list with `desired`, `revoked` and `errors`. The first two hold
requests that already went through
[`intake_request()`](https://ubesp-dctv.github.io/ubep.azure/reference/intake_request.md),
each carrying its `record_id` so the outcome knows where to go back.
`errors` is named by `record_id`.

## Details

Three things keep a row out of the desired state, and they are not the
same thing. A row with no resolved username is not a pair yet and is not
an error. A pair that appears twice is an error on **both** rows,
because either one of them is the mistake and there is no way to tell
which — guessing which one wins is what a ledger does, and a register
refuses. A row that fails validation carries the data-error codes back
to whoever wrote it.
