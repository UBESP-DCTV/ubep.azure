# Build the body that writes an outcome back into the register

The register holds two kinds of field and they must never mix. What a
person asked for is intent; what happened is observation. This body
carries only the second, and the columns are fixed here rather than
assembled from the caller so that a bug cannot rewrite intent: without
that separation a repeated transport error could switch off legitimate
requests, and nobody could tell "a person removed it" from "a bug
removed it".

## Usage

``` r
outcome_payload(record_id, outcome, detail = "", at = "", applied_as = "")
```

## Arguments

- record_id:

  The register record to write to.

- outcome:

  One of `"pending"`, `"applied"`, `"data_error"`, `"transport_error"`,
  `"simulated"`.

- detail:

  Error codes or a human-readable note.

- at:

  When the outcome was recorded, as `YYYY-MM-DD HH:MM`.

- applied_as:

  What the re-read found.

## Value

A one-row data frame with exactly the outcome columns.

## Details

`applied_as` is meant to carry what the channel **read back** after
writing, not the return code. An outcome that only said "no error" would
be the same thing as the four spike cases that reported `true` while
doing something else.
