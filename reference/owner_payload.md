# Build the body that writes the row owner into the register

A fourth door beside the outcome, the identity and the seal, with the
same reason: the columns are fixed here so a bug cannot rewrite anything
else. The owner is the referent a row belongs to after its last approved
change, and it is written apart from the seal and from the outcome
because it is neither: a body that also carried them could move a seal
or restate what the round did while only meaning to say whose the row
is.

## Usage

``` r
owner_payload(record_id, owner)
```

## Arguments

- record_id:

  The register record to write to.

- owner:

  The owner's address, never empty.

## Value

A one-row data frame with exactly `record_id` and `owned_by`.

## Details

An empty or missing owner is refused rather than written. The register
reads an empty `owned_by` as "whoever created the row", so writing one
would erase a decision with something that looks like an absence.
