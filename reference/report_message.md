# Compose a referent's monthly report

Two forms, told apart by the **first word of the subject**, which is
what shows in a list of mail without opening anything:
`Tutto in ordine: ...` when there is nobody to look at,
`Da guardare (N): ...` otherwise, with N in brackets so that the subject
does not carry two colons in a row. The mail is plain text, so the
verdict is said again on the first line of the body, in capitals
(`TUTTO IN ORDINE`, `DA GUARDARE: N`; `ALL CLEAR`, `TO REVIEW: N`): a
number right before a numbered list would read as the number of its
first item. N counts the people listed in full in the items to look at,
a person once even when they are on two servers or in both items (the
user name compared without case), and not the accesses activated or the
expirations, which are information.

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

The items come in the order of the draft: 1. no first sign-in on the
server, 2. no access in more than a year, 3. the expirations of the
month (only if there are any), then the accesses activated. In the
all-clear form items 1 and 2 say "none" with their number. The people of
the referent that went to IT without being judged are counted in a line
of their own, which changes neither the verdict nor the number in the
subject: those say what was measured.

Italian above and English below, as every mail of the channel, since the
address says nothing about which one its reader reads.
