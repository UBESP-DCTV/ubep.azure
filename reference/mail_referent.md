# Who the round's mail to a row's referent goes to

The creator: the account REDCap authenticated when the row was made,
which the round reads from the creation log and passes on as `creator`.
It is the referent the scope gate judged, and the only one whose
approval of a change counts, IT aside. Every message the round sends to
whoever asked goes there: the outcome, whatever it is, and the key of an
account just made.

## Usage

``` r
mail_referent(row)
```

## Arguments

- row:

  One register row as a list, with this round's outcome and the
  `creator` the round read.

## Value

One address, possibly empty.

## Details

Not `requested_by`. On the form `@USERNAME` fills it in and the two
agree; the Data Import Tool writes it as the CSV has it (measured on
2026-09-02 and again on 2026-10-16), and the round does not write it
back. Sent to that field, an import that left it empty lost the key and
the outcome, and one naming another address sent both there, to the
person themselves if the file said so, against the rule that the key
stays with the referent.

`requested_by` remains the fallback for a row without a creator, and no
key reaches it: a row whose creator the log does not name stops at the
gate on `TRASPORTO_AUTORE_NON_LEGGIBILE`, and nobody is made for it. An
outcome can, on a round that has no creator to hand: one whose sweep of
the tenant failed, which asks no log; one whose creation log could not
be read, or does not name the row; one where no row needed judging,
which does not ask the creation log at all.
