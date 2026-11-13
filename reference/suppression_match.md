# Cross the suppression lists with the channel's recipients

Addresses compare without case and without blanks at the edges. The four
lists that suppress are a state, any entry whatever its age; *Blocks* is
an event. So is `soppressi_recapiti_nuovi`, the recipients with an entry
that is new: created in the 24 hours before the last cut, `cut` UTC, the
time the job's timer starts, at or before `now`. The window is aligned
to the timer and not to the moment of the run, which comes up to five
minutes later (`RandomizedDelaySec=300`): an entry made between the cut
and the run counts the next day, and every entry counts on one day only,
with no overlap and no gap between two runs of the timer. A run by hand
on the same day counts the same window. A day with no run at all (the
machine off from before one cut to after the next) loses its entries as
news; one of the four lists stays in the state counts and in the mail to
IT.

## Usage

``` r
suppression_match(reading, recipients, now, cut = "06:30")
```

## Arguments

- reading:

  What
  [`suppression_read()`](https://ubesp-dctv.github.io/ubep.azure/reference/suppression_read.md)
  answered, or `NULL` when nothing was read.

- recipients:

  What
  [`suppression_recipients()`](https://ubesp-dctv.github.io/ubep.azure/reference/suppression_recipients.md)
  answered.

- now:

  The moment the run reads.

- cut:

  The time of day, `"%H:%M"` in UTC, at which the job's timer starts
  (`OnCalendar=*-*-* 06:30:00 UTC`). If the timer moves, this moves with
  it.

## Value

A list with `soppressioni_lette`, `soppressa_casella_it`,
`soppressi_referenti`, `soppressi_recapiti`, `soppressi_recapiti_nuovi`,
`bloccati_nuovi`, and `dettaglio`, a data frame of `lista`, `classe`,
`record_id` (the rows of the address, separated by commas), `creata`
(UTC, to the minute), `motivo` (the service's reason, on one line and
cut) and `indirizzo`: one row per address, class and entry that counts.

## Details

Counts and nothing else for the record, which a workspace keeps and
others read: never an address, and no hash of one, which on a known
domain is reversed by dictionary. The addresses are in `dettaglio`,
which the runner writes to the standard error, the unit's journal.

`NA` is "not computed", not zero. With the lists not read every count is
`NA`. With the lists read, the address of IT is judged whenever there is
one, and the rest only with the register and the directory read;
`bloccati_nuovi` counts the three classes, so it needs all of them read
that can be. `soppressioni_lette` is the lists read whole and the
register and the directory read.
