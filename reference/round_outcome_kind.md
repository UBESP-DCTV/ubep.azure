# Which outcome a set of module error codes deserves

The prefix decides the recipient, which is the taxonomy the channel has
used since its first design: `DATO_` belongs to whoever filed the
request, and anything else is ours. Mixed codes fail towards ours,
because a transport error leaves the row in the desired state for the
next round while a data error closes it against the requester — and
closing a row on a fault that is half ours is the expensive direction.

## Usage

``` r
round_outcome_kind(codes, dry_run)
```

## Arguments

- codes:

  Character vector of codes the module reported for one entry.

- dry_run:

  Whether this round simulated.

## Value

One word of
[`outcome_payload()`](https://ubesp-dctv.github.io/ubep.azure/reference/outcome_payload.md)'s
vocabulary.
