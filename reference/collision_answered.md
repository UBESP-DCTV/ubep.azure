# Whether the referent answered this collision

The answer is the row's `distinct_username`, decided on 2026-10-27: the
referent pastes the proposal they were sent there when the account that
holds the composed name is somebody else, and the round then creates an
account under the proposal, as it creates one for `absent`. It answers
that proposal and no other: compared, folded on both sides, with the
proposal the resolution has just made, so a proposal that moved (the
name changed, or the suffix was taken meanwhile) leaves the answer
standing for nothing until the new one is pasted.

## Usage

``` r
collision_answered(register, resolutions)
```

## Arguments

- register:

  The register as read, carrying `distinct_username`.

- resolutions:

  What
  [`resolve_identity()`](https://ubesp-dctv.github.io/ubep.azure/reference/resolve_identity.md)
  answered for each row, in the order of `register`.

## Value

A logical vector, one answer per row.

## Details

The value is never the name created, nor a name the row resolves to. The
name is the proposal the round found free in this sweep, and the field
only says yes to it; on every verdict but `collision` nobody reads it.

Pure, and only half of the question: whether the answer was written
after the proposal it names is the log's to say,
[`log_answer_stands()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_answer_stands.md).
