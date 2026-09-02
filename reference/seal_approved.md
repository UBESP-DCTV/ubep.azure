# Whether a change to an applied row has been approved

Two conditions, and neither is enough on its own.

## Usage

``` r
seal_approved(register, events)
```

## Arguments

- register:

  The register as read, one row per request.

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

## Value

A logical vector, one answer per row.

## Details

The approval has to carry **this** row's seal. A value that is some
other seal approves some other version of the row, and accepting it
would make one approval stand for every change that came after it.

And it has to come from **somebody else**. Otherwise the protection is a
formality: whoever edits another referent's row would paste the seal on
the way out, and the round would apply a change nobody but its author
ever saw. The seal detects that the row moved; only the log can say who
moved it, because it names whoever was authenticated rather than a value
somebody typed — which is the same reason `requested_by` cannot be
trusted alone.

An unreadable log is not this function's to decide. It answers about the
events it was handed, and a caller holding no events gets `FALSE` on
every changed row: the row waits, which is the direction that does not
grant.
