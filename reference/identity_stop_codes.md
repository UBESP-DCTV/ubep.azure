# What a row the gate refused reports about itself

The gate says which rows stop; this says what the register then carries
in `outcome_detail`, which is the only sentence the referent gets.
Decided by Corrado on 2026-08-15: `ambiguous` and `collision` close the
row as data errors, so `A-13` mails whoever filed it, while `absent`
carries no code at all — the round creates the account in the same pass,
and mailing somebody about a row nobody has to touch is how an alert
stops being read.

## Usage

``` r
identity_stop_codes(identity, errors = character())
```

## Arguments

- identity:

  The verdict the resolution has just computed.

- errors:

  The codes the resolution itself produced, which win: a row stopped
  before any verdict already knows exactly what is wrong with it, and
  the generic summary would cost the referent the sentence they can act
  on.

## Value

A character vector of codes, empty when there is nothing to report.

## Details

**The two codes name what to correct rather than what was observed**,
and the reason is that sub-project 5 writes its message from the code.
What was observed is already in `identity`, where a person can read it;
a code that repeated it would hand the referent a diagnosis and no
instruction. `DATO_RECAPITO_NON_IDENTIFICA` says the one thing they can
do — give a contact address that picks out this person and nobody else —
and it is true of both ways an ambiguity arises: the address that sits
on two accounts, and the address that matched nothing while a namesake
exists.

The collision keeps its own code because it is a different question with
a different owner: not "which of these people", but "is the account that
is already there the one you mean". The proposal they are answering
about travels beside it, in the row's `username`, which is why decision
11 writes it into the register instead of leaving it inside an e-mail.

The `DATO_` prefix on both is a delivery address and not a label, the
way
[`scope_errors()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_errors.md)
uses it: it is what
[`round_outcome_kind()`](https://ubesp-dctv.github.io/ubep.azure/reference/round_outcome_kind.md)
reads to close the row against whoever filed it rather than keeping it
in the queue for us.
