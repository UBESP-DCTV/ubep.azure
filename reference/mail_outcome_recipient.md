# Who the message about a row's outcome goes to

`requested_by`, except on a held row, whose message asks its reader to
approve a change. Only whoever created the row can, IT aside, and that
is the account REDCap authenticated when the row was made, which the
round reads from the creation log and passes on as `creator`. The two
agree on every row filed from the form; an import is what makes them
disagree, and then the message goes where the approval can come from.
The round does not hold a row whose creator it could not read – that row
takes `TRASPORTO_AUTORE_NON_LEGGIBILE` – so the fallback to
`requested_by` is for a caller that hands this a held row without one.

## Usage

``` r
mail_outcome_recipient(row)
```

## Arguments

- row:

  One register row as a list, with this round's outcome.

## Value

One address, possibly empty.
