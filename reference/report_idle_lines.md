# The lines of the people with no access for more than a year, in both languages

One entry for each person and server that crossed the threshold this
month, with the project of the person on that server, when the server
last saw them and since when they have had the access. The pairs named
in an earlier report of the same referent and still without access are
counted in a line of their own, not listed again. The pairs on a server
that did not answer are counted per server and said not to be checked:
an item that covered a server nobody read would say "none" about
something nobody measured, so "none" is only said when there is nothing
else to say.

## Usage

``` r
report_idle_lines(report)
```

## Arguments

- report:

  One referent's report, as
  [`report_assemble()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_assemble.md)
  builds it: `senza_accessi` (the pairs listed in full),
  `senza_accessi_gia` (how many were named before) and `non_controllati`
  (a frame of `server` and `coppie`).

## Value

A list of two character vectors, `it` and `en`.
