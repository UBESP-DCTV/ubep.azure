# The addresses of the channel that a suppression would silence

Three classes, as the design of 2026-11-12 names them:

## Usage

``` r
suppression_recipients(
  register,
  creators,
  owners,
  directory,
  copy_to,
  domain = "ubep.unipd.it"
)
```

## Arguments

- register:

  The register as read, or `NULL` when it was not read.

- creators, owners:

  As long as the register: who created each row
  ([`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)),
  and its owner as the log names it today, `""` or `NA` where it does
  not.

- directory:

  The directory frame, or `NULL` when it was not read.

- copy_to:

  The address of IT, or `NULL`.

- domain:

  The tenant's verified domain, as
  [`identity_internal()`](https://ubesp-dctv.github.io/ubep.azure/reference/identity_internal.md)
  takes it.

## Value

A list with `destinatari`, a data frame of `indirizzo` (as written),
`classe` and `record_id` (`""` for the address of IT), and `classi`, the
classes that could be computed: `casella_it` with an address of IT, the
other two with the register and the directory read.

## Details

- `casella_it`: the address of IT (`UBEP_POSTA_COPIA`), in copy on every
  outcome and the recipient of what has nowhere else to go. It does not
  depend on the register and is there whenever the address is;

- `referente`: whom the channel sends keys, outcomes and reports to, the
  owners of the rows that are not revoked. A superset that asks for no
  reading of its own: the owner the log names today
  ([`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md))
  where the report read the row's log, plus `owned_by` and the creator
  ([`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md))
  of every `active` row. One address too many costs at most a notice on
  an address that works with the register;

- `recapito`: where the channel writes to the person of each `active`
  row. The recipients of the access message as the round computes them,
  with the same function
  ([`mail_access_recipients()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_access_recipients.md),
  fed by
  [`directory_mailboxes()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_mailboxes.md)
  on the row's `username`), so that a correction of those recipients
  holds here without touching this code; plus *Contact e-mail* when the
  channel created the account (`identity` `created`), the only case in
  which the welcome went there. An internal contact on an account the
  channel did not create is the UPN, and the channel no longer writes to
  it.

The IT approvers are not here: they are REDCap usernames the channel
never writes to. Nor is the address replies reach, which a reply leaves
from the program of whoever replies, nor `requested_by`, which the
channel does not write to.
