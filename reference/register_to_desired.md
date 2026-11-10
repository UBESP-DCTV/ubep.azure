# Turn the register into the desired state

The register declares requests; it does not describe reality. A pair
that exists in REDCap and appears nowhere here means nothing, so this
function never produces a revocation that a person did not ask for: only
`request_status = "revoked"` does that.

## Usage

``` r
register_to_desired(register, executed = character())
```

## Arguments

- register:

  The register as a data frame, one row per pair, carrying at least
  `record_id` and `request_status`.

- executed:

  The `record_id`s of the rows the round carried out and nobody changed
  since: the channel's seal is there and has not moved.

## Value

A list with `desired`, `revoked`, `errors` and `lapsed`. The first two
hold requests that already went through
[`intake_request()`](https://ubesp-dctv.github.io/ubep.azure/reference/intake_request.md),
each carrying its `record_id` so the outcome knows where to go back.
`errors` is named by `record_id`. `lapsed` holds the `record_id`s of the
rows in `desired` whose last day has passed, admitted because they are
in `executed`.

## Details

Three things keep a row out of the desired state, and they are not the
same thing. A row with no resolved username is not a pair yet and is not
an error. A pair that appears twice is an error on **every row but the
oldest**. A row that fails validation carries the data-error codes back
to whoever wrote it.

**Why the oldest row survives a duplicate, when it used to fail with the
rest.** The two rows were never equals: the older one may already have
granted an access, and the newer is the one that did what the work
instruction says not to do, which is to file a second request instead of
changing the first. Failing closed on both looked like refusing to
guess, and was: a marked row never reaches the plan, so **a revocation
written on the older row was never carried out either**. The access
stayed, the mandate read `data_error`, and nothing in the register could
take the access away — a right standing with its mandate marked invalid,
which is the failure this register exists to prevent, arriving from the
side nobody was watching.

Age is the `record_id` and nothing else. "The row already served wins"
would name the right row more precisely and is refused on the same
ground as the identity gate's: it would ask the `outcome` the register
carries, a verdict up to four hours old, instead of a fact about the
row.

A row the round carried out and nobody changed since keeps a last day
that has passed,
[`validate_request()`](https://ubesp-dctv.github.io/ubep.azure/reference/validate_request.md):
the expiration is REDCap's to apply. Its id is returned in `lapsed`,
because such a row may be compared with the instance and brought back to
what it says, and never written as a new access: on a pair the instance
no longer holds, the round writes nothing and closes the row as a
revocation already done is closed, `applied` and read back as absent
([`provisioning_reconcile()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_reconcile.md)).
