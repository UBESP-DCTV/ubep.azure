# Whether a change to an applied row has been approved

Three conditions, and none is enough on its own.

## Usage

``` r
seal_approved(
  register,
  events,
  creators,
  approvers = character(),
  channel_account = NULL
)
```

## Arguments

- register:

  The register as read, one row per request.

- events:

  The event log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- creators:

  Who created each row, as
  [`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
  answers, in the order of `register`; the owner is read from the log
  with them.

- approvers:

  The IT accounts whose approval counts on any row, as REDCap usernames.

- channel_account:

  The REDCap usernames that hold the round's token, one or more, or
  `NULL` when they are not configured, for
  [`log_channel_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_accounts.md)
  and
  [`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md).

## Value

A logical vector, one answer per row.

## Details

The approval has to carry **this** row's seal. A value that is some
other seal approves some other version of the row, and accepting it
would make one approval stand for every change that came after it.

It has to come from **whoever owns the row**,
[`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md):
its creator until the round passes it on, then the last referent whose
change was approved and carried out. Not merely from somebody other than
the author of the change: the request is the owner's, so an approval
from a third referent would grant on the word of somebody the row does
not answer to. The seal detects that the row moved; only the log can say
who approved it and who owns the row, because it names whoever was
authenticated rather than a value somebody typed – which is the same
reason neither `requested_by` nor `owned_by` can be trusted alone. An
owner the log cannot establish approves nothing.

And it has to be **newer than what it approves**: above the round's last
execution and above every change somebody other than the owner made, as
[`log_approval_stands()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_approval_stands.md)
reads the log. The value alone cannot say so. `approved_seal` is never
blanked, so an approval the round has already carried out would approve
again any later change that brings the row back to it; and the seal is a
public hash of the intent fields, so it can be pasted before the change
it names exists.

**IT approves as the owner does**, decided on 2026-10-15: the accounts
named in `approvers` stand where the owner stands, under the same three
conditions. It is what keeps a request whose owner has left UBEP from
waiting for ever, without deleting the row and losing who filed it. The
list lives on the machine that runs the round and never in this
repository. Whoever approves has no rights checked: the scope gate asks
the rights of whoever wrote the change the round carries out, so an
approval carries a manager's change on a row whose owner no longer
manages the project, and never a change by somebody who does not.

An unreadable log is not this function's to decide. It answers about the
events and the creators it was handed, and a caller holding neither gets
`FALSE` on every changed row: the row waits, which is the direction that
does not grant.
