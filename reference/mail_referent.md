# Who the round's mail to a row's referent goes to

The row's owner: who the creation log names as having made the row,
until an approved change by another referent hands it over, which the
log holds as a write of `owned_by` by the channel's account. The round
settles it from the log and passes it on as `owner`. It is the only one
whose approval of a change counts, IT aside; the scope gate judges
whoever wrote what the round carries out, which is the owner only when
nobody else changed the row. Every message the round sends to whoever
asked goes there: the outcome, whatever it is, and the key of an account
just made.

## Usage

``` r
mail_referent(row)
```

## Arguments

- row:

  One register row as a list, with this round's outcome and the `owner`
  the round settled.

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

And there is no fallback to it. Once a row can change hands, a fallback
would write to a former owner, the one person who should no longer hear
about the row. An empty owner means the round could not settle it, and
the outcome then goes to IT alone and says so (see
[`mail_round()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_round.md)).
That happens on a sweep of the tenant that failed, which asks no log; on
a creation log or an owners' log that could not be read; on a round with
no row to judge, which asks neither; on a creation log that does not
name the row; and on an owner the log cannot say,
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md),
as when a write of `owned_by` with no author stands above the channel's.
No key reaches anybody then: a row whose owner the log does not name
stops at the gate on `TRASPORTO_AUTORE_NON_LEGGIBILE`, and nobody is
made for it.
