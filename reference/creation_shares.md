# Which creation each row waiting for an account shares

The rows `absent` that a round is about to create, and the name the
resolution found free for each. The name is free when the round sweeps
and taken once the first POST of it has made the account, so the round
sends each name once, for the oldest row that waits for it. Age is the
numeric `record_id`, as the oldest row of a repeated pair keeps it in
[`register_to_desired()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_to_desired.md),
and not the order of the export; without a `record_id` it is the order
of the rows.

## Usage

``` r
creation_shares(rows, upns)
```

## Arguments

- rows:

  The register rows, carrying `record_id`, `first_name`, `last_name` and
  `contact_email`.

- upns:

  The name each row would be created under, as the resolution composed
  it.

## Value

An integer vector, one per row: the position of the row whose creation
it shares, its own when it makes one, and `NA` when it waits for the
next round.

## Details

The other rows that wait for the same name are one of two things. The
same person asked for again, on another project: the same name and
surname, as
[`directory_named()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_named.md)
folds them, and the same contact address. That row shares the creation,
one account, one key and one welcome, and next round finds the account
by the criterion the resolution uses and is `created` like the first. Or
somebody else with the same name, or the same person with another
address, which nothing in the round can tell apart: that row waits, and
next round meets the new account as a namesake, `ambiguous`, which the
referent and IT settle. Taking the next free name at once would make a
second account for a person who may already have one.
