# Whether each changed row waits for an approval

[`change_needs_approval()`](https://ubesp-dctv.github.io/ubep.azure/reference/change_needs_approval.md)
asked once per row, of the authors the row's log names,
[`log_pending_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_pending_authors.md),
and of the creator the creation log names. Whether the row carries a
seal is read from its `applied_seal`.

## Usage

``` r
seal_needs_approval(register, events, creators, approvers = character())
```

## Arguments

- register:

  The register as read, one row per request.

- events:

  The event log of the rows that changed, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- creators:

  Who created each row, as
  [`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
  answers, in the order of `register`.

- approvers:

  The IT accounts whose approval counts on any row: it decides what an
  earlier execution covered.

## Value

A logical vector, one answer per row. It answers about every row it is
handed, so the caller restricts it to the rows that changed.
