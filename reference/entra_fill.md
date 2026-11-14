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
pass.

## Usage

``` r
entra_fill(executed_username, directory, since, revoked = FALSE)
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

## Value

A list with `id`, the identifier to write or `""`, and `code`,
`TRASPORTO_NOME_RIASSEGNATO` or `""`.

## Details

- Born before the end of that minute, `createdDateTime` read in UTC
  ([`report_graph_time()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_graph_time.md)):
  the identifier is written, with no message.

- Born after: on a row not revoked `TRASPORTO_NOME_RIASSEGNATO` and no
  identifier; on a revoked row neither.

- A date that does not read, no `since`, nobody or two accounts carrying
  the name, an identifier the door would refuse: neither, and the next
  round tries again.

An account born in the same minute as the first seal passes: the log has
minutes and Graph seconds, and a creation precedes the first execution
by a round. An older account renamed onto the name freed by a deleted
one passes too, the one case the guard does not see.
