# Whether what somebody other than the creator wrote is a revocation alone

The half of the revocation exception that the log answers, for
[`change_needs_approval()`](https://ubesp-dctv.github.io/ubep.azure/reference/change_needs_approval.md).
Since the round's last execution, every write to an intent field by an
account that is neither the creator nor the channel wrote
`request_status = 'revoked'` and no other intent field; and there is at
least one such write, or there is no withdrawal by somebody else to
free.

## Usage

``` r
log_revocation_only(
  events,
  record,
  creator,
  fields = register_intent_fields(),
  approvers = character()
)
```

## Arguments

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id to look at.

- creator:

  Who created the row, as
  [`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
  answers.

- fields:

  The intent fields.

- approvers:

  The IT accounts whose approval counts on any row.

## Value

`TRUE` when the others wrote a revocation and nothing else.

## Details

A change below the newest execution that the execution did not cover,
[`log_uncovered_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_uncovered_authors.md),
makes the answer `FALSE`. That stretch is the rare case of an edit made
while a round ran, and reading it for its fields as well would buy
nothing but code: the row waits for the creator, as it would have before
the exception existed.
