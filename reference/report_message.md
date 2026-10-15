# Compose a referent's monthly report

Two forms, told apart by the **first word of the subject**, which is
what shows in a list of mail without opening anything: `Tutto in ordine`
when there is nobody to look at, `N da guardare` otherwise. The mail is
plain text, so the verdict is said again on the first line of the body,
in capitals. N counts the people listed in full in the items to look at,
and not the accesses activated, which are information; in the form to
review the anomalies come first and the information after.

## Usage

``` r
report_message(report, period)
```

## Arguments

- report:

  One referent's report, as
  [`report_assemble()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_assemble.md)
  builds it.

- period:

  What
  [`report_month()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_month.md)
  answered.

## Value

A list with `subject`, `body`, `forma` (`in_ordine` or `da_guardare`)
and `n`.

## Details

The year without access is not measured in phase 1, and the mail says so
in both forms: an all-clear that covered an item nobody looked at would
say something false. For the same reason the people of the referent that
went to IT without being judged are counted in a line of their own,
which changes neither the verdict nor the number in the subject: those
say what was measured.

Italian above and English below, as every mail of the channel, since the
address says nothing about which one its reader reads.
