# Who owns a row once the round has carried it out

The owner after the execution of the version the log describes: the row
passes to the newest of the authors who count,
[`log_pending_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_pending_authors.md),
which is the referent whose change the round is carrying out. IT
included: a change IT wrote and the round carried out makes IT the
owner.

## Usage

``` r
log_next_owner(
  events,
  record,
  creator,
  fields = register_intent_fields(),
  approvers = character(),
  channel_account = NULL,
  current = NULL
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

- channel_account:

  The REDCap usernames that hold the round's token, one or more, or
  `NULL` when they are not configured.

- current:

  The row as the round will leave it, a data frame of one row, or `NULL`
  when there is no row in hand, for
  [`log_pending_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_pending_authors.md).

## Value

One username; `""` or `NA_character_` as
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md)
answers them, and `NA_character_` too when the log cannot say who the
authors are.

## Details

The passage is decided once, by the round that carries the change out,
after the gate has let it through: what this function reads is a version
already approved, and it does not judge the approval again.

The act is judged, not the path that led to it (decided on 2026-10-17).
A revocation does not move the row, whether it went through freely or
was approved: whoever wrote only `request_status = 'revoked'` and no
other intent field never becomes the owner, even when the version also
holds somebody else's change. The row passes to the newest of the other
authors who count, and stays with the owner of today when only
withdrawals are left.

An author counts in two stretches, and is a withdrawal alone only when
every write of theirs that counts, in both, is one. Above the last
execution, every write of theirs is read, not only the ones still in the
row, as
[`log_revocation_only()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_revocation_only.md)
reads the others. Below it, an uncovered change,
[`log_uncovered_authors()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_uncovered_authors.md),
is never a withdrawal, which that function leaves out: an author it
names changed something the version carried out holds, and can take the
row, whatever they wrote above. So a revocation above the execution over
an uncovered change by somebody else passes the row to that somebody,
and over an uncovered change of their own to its author.

Without the channel's account, `channel_account = NULL`, no write of
`owned_by` is believed and no row passes: the answer is the one of
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md),
the creator, or unknown on a row whose channel the log cannot tell.
