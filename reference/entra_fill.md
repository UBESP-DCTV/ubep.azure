# The Entra account of a row carried out before the identifier existed

Item 11 of the 0.27.0 (decided on 2026-11-12): the rows the channel
carried out before `applied_entra_id` existed have none, and get it from
the sweep, with a guard. The account that carries the username carried
out now is the one served only if it was born before the row was first
carried out under that name: `since` is the first seal of the newest run
of executions of that name,
[`report_person_since()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_person_since.md),
in Rome's civil time and to the minute as the log stamps it. The
reference is the first seal of the run and not the last: with the last,
a name given again and then an execution for a change of role would
pass. The run goes across a closure on a person gone from Entra
(`across_closures`, item 14 of the limits, 0.29.0): a row set back to
active after it, or granted again after it by an earlier version, is
dated from the first execution of the name, not from the reopening.

## Usage

``` r
entra_fill(
  executed_username,
  directory,
  since,
  revoked = FALSE,
  folds = directory_folds(directory)
)
```

## Arguments

- executed_username:

  The username the row was carried out for.

- directory:

  The sweep, as
  [`directory_users()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_users.md)
  returns it.

- since:

  `"%Y-%m-%d %H:%M"` in Rome, as
  [`report_person_since()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_person_since.md)
  answers; [`character()`](https://rdrr.io/r/base/character.html) or
  `NA` when the log does not say.

- revoked:

  Whether the row asks for `revoked`.

- folds:

  The sweep folded,
  [`directory_folds()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_folds.md),
  made from `directory`; by default folded here.

## Value

A list with `id`, the identifier to write or `""`, `code`,
`TRASPORTO_NOME_RIASSEGNATO` or `""`, and `undecided`, `TRUE` when the
guard cannot decide.

## Details

- Born before the end of that minute, `createdDateTime` read in UTC
  ([`report_graph_time()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_graph_time.md)):
  the identifier is written, with no message.

- Born after: on a row not revoked `TRASPORTO_NOME_RIASSEGNATO` and no
  identifier; on a revoked row neither.

- Nobody carrying the name, or no name: nothing to say.

- Two accounts carrying the name, no `since` or one that does not read,
  a date of creation that does not read, an identifier the door would
  refuse: the guard cannot decide, `undecided`.

The last two write nothing and stop nothing, and the next round tries
again. The caller tells them apart on a row closed on a person gone from
Entra and set back to active, which stops for IT when the guard cannot
decide (item 14 of the limits, 0.29.0); on every other row both are
nothing.

An account born in the same minute as the first seal passes: the log has
minutes and Graph seconds, and a creation precedes the first execution
by a round. An older account renamed onto the name freed by a deleted
one passes too, the one case the guard does not see.
