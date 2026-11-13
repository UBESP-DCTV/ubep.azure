# The suppressed recipients the mail to IT lists

From the detail of
[`suppression_match()`](https://ubesp-dctv.github.io/ubep.azure/reference/suppression_match.md),
the entries of the four lists that suppress, and not *Blocks*: one row
per request, address and list for the people, with the request's server
and project from the register, and one per address and list for the
referents. The address of IT is not here: a mail to it would not arrive,
and its rule says it.

## Usage

``` r
report_suppressed_for_it(detail, register)
```

## Arguments

- detail:

  The `dettaglio` of
  [`suppression_match()`](https://ubesp-dctv.github.io/ubep.azure/reference/suppression_match.md).

- register:

  The register as read, or `NULL`.

## Value

A list with `soppressioni` (`record_id`, `first_name`, `last_name`,
`server`, `project_id`, `indirizzo`, `lista`, `creata`) and
`referenti_soppressi` (`indirizzo`, `lista`, `creata`), `creata` as
POSIXct in UTC.
