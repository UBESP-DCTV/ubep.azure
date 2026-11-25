# Validate a provisioning request

Returns the data-error codes of the spec's taxonomy. These are errors
that belong to whoever filed the request, not to IT: a request carrying
them is badly filled in, not badly transported.

## Usage

``` r
validate_request(request, executed = FALSE, today = redcap_today())
```

## Arguments

- request:

  A named list, one request as described in the spec.

- executed:

  Whether the round carried this request out and nobody changed it
  since: the channel's seal is there and has not moved.

- today:

  REDCap's date, the one in Rome,
  [`redcap_today()`](https://ubesp-dctv.github.io/ubep.azure/reference/redcap_today.md)
  by default. The round computes it once, from the instant it started,
  and passes it down, so that every row is judged on the same day.

## Value

A character vector of error codes; empty when the request is valid.

## Details

Errors that need the instance to be answered — a project, role or DAG
that does not exist there — cannot be decided here and are left to the
module.

A last day of access in the past is refused on a request that would
write a new one, and only there. A request the round carried out and
nobody changed since had a valid last day when it was carried out: its
passing is the expiration REDCap applies on the access, decided on
2026-11-10, and refusing it sent the referent to write a date that has
not passed, or none, which reopened the access the expiration had
closed. A value that is not a date is refused either way.
