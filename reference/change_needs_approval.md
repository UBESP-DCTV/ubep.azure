# Whether a change to a request waits for an approval

**The one place the rule lives**, decided on 2026-10-14. A request
belongs to whoever created it, and the creator answers for it: the scope
gate asks the creator's rights on the project every round, and the
credentials of an account it makes go to the creator. So:

## Usage

``` r
change_needs_approval(
  authors,
  creator,
  sealed = TRUE,
  revocation = FALSE,
  managers = character()
)
```

## Arguments

- authors:

  Who has a hand in the version the round would carry out, as
  [`log_pending_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_pending_authors.md)
  answers.

- creator:

  Who created the row, as
  [`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
  answers.

- sealed:

  Whether the row carries the seal of an execution, whose mismatch is
  what says it changed.

- revocation:

  Whether the change is a revocation and nothing else: the row asks for
  `revoked` and
  [`log_revocation_only()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_revocation_only.md)
  holds.

- managers:

  Who holds User Rights with Full Access on the project the row names,
  as the instance reported it this round.

## Value

`TRUE` when the change has to wait for the creator's approval.

## Details

- a change made only by the creator is carried out on the next round,
  with nobody to ask;

- a change in which anybody else had a hand waits for the creator, even
  when the creator edited the row afterwards: a later edit does not say
  the creator saw the other one, and an approval is the act that does;

- a change whose authors or whose creator the log cannot establish waits
  too. "I could not establish who did this" is not "the creator did it".

It holds whether or not the round has applied the row yet. The one
difference is what a log naming nobody means. On a row that carries a
seal the seal has already moved, so the row did change and nobody is on
record for it: it waits. On a row never applied there is no such
evidence, and a log that names nobody says nobody changed it.

**A revocation is the one exception**, decided on 2026-10-15: somebody
else's withdrawal of the request does not wait when everybody other than
the creator who has a hand in it holds User Rights with Full Access on
the project. Taking an access away grants nothing, and whoever manages
the users of a project could have removed that person by hand – the rule
the scope gate enforces, "nobody does through the channel what they
could not do by hand", holds as it is. What counts as a revocation is
narrow on purpose,
[`log_revocation_only()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_revocation_only.md):
the row now asks for `revoked`, and what the others wrote is that and
nothing else. A withdrawal that also moves the role, the person or the
project is a change like any other.

The rights come from the instance, and the round has them only once it
has asked it. So the round asks this question twice for a revocation:
before talking to the instance, with no managers, which holds it
provisionally; and at the gate, with the managers the instance reported,
which decides.
