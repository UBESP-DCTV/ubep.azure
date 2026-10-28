# Build the record the monthly report leaves behind

The columns are those of its own table, `UbepRapporto_CL`, and only
those: the job has a table of its own rather than a discriminating
column in the round's or the observer's, whose rules read the last
record without asking who wrote it. Every column is present on every
run, zeroed when there is nothing to count, because the rule on the
incomplete record counts them.

## Usage

``` r
report_record(esito, posta)
```

## Arguments

- esito:

  What
  [`provisioning_report()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_report.md)
  returned.

- posta:

  Whether the run was allowed to send. No fallback, as in the round's
  record: a caller that forgot it would report the post as off.

## Value

A named list, ready for
[`run_record_json()`](https://ubesp-dctv.github.io/ubep.azure/reference/run_record_json.md).

## Details

`referenti` counts the reports of the month, the one to IT included:
those due, as today's reading or the last whole one found them, and
those the ledger says left on earlier days. `mese_completo` is the
design's `gia_mandati + mandati == referenti`, on those, and `mandati`
there are the reports of the month covered only: the late reports of the
months lost count in `mandati` and `falliti` of the record, and not in
the completeness of the month, which a recovery of two of three would
otherwise make look whole. A day that cannot read judges the month on
the last whole reading, so a reading that fails after the month was sent
does not make it late; with no whole reading on record nothing is due,
and the month is not called late on a guess. `in_ritardo` is
[`report_late()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_late.md):
from day 2 with the month not complete, or while a month lost still
misses a report (`mesi_persi`).

`istanze_non_lette` counts the servers the report asked and could not
read. `voci_senza_accessi` counts the pairs of person and server listed
in full for the year without access: those already named in an earlier
report and those on a server not read are not in it.

Names and codes only, and never a person: the record is shipped to a
workspace and kept.
