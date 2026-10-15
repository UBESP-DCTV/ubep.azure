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
design's `gia_mandati + mandati == referenti`, on those. A day that
cannot read judges the month on the last whole reading, so a reading
that fails after the month was sent does not make it late; with no whole
reading on record nothing is due, and the month is not called late on a
guess. `in_ritardo` is
[`report_late()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_late.md).

Phase 1 asks no instance and does not measure the year without access,
so `istanze_non_lette` and `voci_senza_accessi` are zero.

Names and codes only, and never a person: the record is shipped to a
workspace and kept.
