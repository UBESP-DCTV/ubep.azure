# Whether a change to an applied row has been approved

Three conditions, and none is enough on its own.

## Usage

``` r
seal_approved(register, events, creators, approvers = character())
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
  answers, in the order of `register`. `""` approves nothing.

- approvers:

  The IT accounts whose approval counts on any row, as REDCap usernames.

## Value

A logical vector, one answer per row.

## Details

The approval has to carry **this** row's seal. A value that is some
other seal approves some other version of the row, and accepting it
would make one approval stand for every change that came after it.

It has to come from **whoever created the row**. Not merely from
somebody other than the author of the change: the request is the
creator's, the scope gate checks the creator's rights on the project
every round and nobody else's, so an approval from a third referent
would grant on the word of somebody whose rights on that project nobody
has looked at. The seal detects that the row moved; only the log can say
who approved it and who created the row, because it names whoever was
authenticated rather than a value somebody typed – which is the same
reason `requested_by` cannot be trusted alone.

And it has to be **newer than what it approves**: above the round's last
execution and above every change somebody other than the creator made,
as
[`log_approval_stands()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_approval_stands.md)
reads the log. The value alone cannot say so. `approved_seal` is never
blanked, so an approval the round has already carried out would approve
again any later change that brings the row back to it; and the seal is a
public hash of the intent fields, so it can be pasted before the change
it names exists.

**IT approves as the creator does**, decided on 2026-10-15: the accounts
named in `approvers` stand where the creator stands, under the same
three conditions. It is what keeps a request whose creator has left UBEP
from waiting for ever, without deleting the row and losing who filed it.
The list lives on the machine that runs the round and never in this
repository. One limit is worth knowing: the scope gate still asks the
creator's rights on the project, so no approval, from IT or anybody
else, carries a row whose creator no longer manages the project.

An unreadable log is not this function's to decide. It answers about the
events and the creators it was handed, and a caller holding neither gets
`FALSE` on every changed row: the row waits, which is the direction that
does not grant.
