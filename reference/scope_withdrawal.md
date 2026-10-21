# Judge at the gate a revocation somebody other than its owner made

The second half of the exception
[`change_needs_approval()`](https://ubesp-dctv.github.io/ubep.azure/reference/change_needs_approval.md)
makes for a revocation, the half only an instance can answer. The round
holds the row provisionally until it knows who manages the project, and
this is where it finds out.

## Usage

``` r
scope_withdrawal(row, authors, owner, sealed, rights)
```

## Arguments

- row:

  The row, one line of the register as the gate reads it.

- authors:

  Who has a hand in the change, as
  [`log_pending_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_pending_authors.md)
  answers.

- owner:

  Who the row belongs to: the creator, or the referent it passed to.

- sealed:

  Whether the row carries the seal of an execution.

- rights:

  The rights the instance reported, as
  [`round_rights()`](https://ubesp-dctv.github.io/ubep.azure/reference/round_rights.md)
  builds them.

## Value

`""` when the revocation stands; `"held"` when it waits for the owner;
otherwise the refusal code, as
[`scope_errors()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_errors.md)
gives it.

## Details

The question is the gate's own, asked of different people. A revocation
stands on the authority of whoever had a hand in it, so each of them is
asked "could you have done this by hand", which for a removal is "do you
hold User Rights on this project". The owner is asked only when the
owner is one of them: an owner who no longer manages the project does
not stop a manager from removing somebody, since the manager could have
done it in REDCap anyway.

Three answers. A permission that could not be read is ours, as on the
ordinary gate, and keeps the row queued. An owner who had a hand in it
and does not manage the project is refused as the owner's own change
would be. Anybody else who does not manage it puts the row back under
the common rule: it waits for the owner.
