# Say where the access message reaches the person

To `contact_email`, as the welcome, when it is outside the tenant's
domain. When it is inside, decision 12 makes it the UPN, and the UPN is
not where the person reads mail: for most accounts of the tenant it has
no mailbox, Exchange Online refuses the message ("550 5.4.1 Recipient
address rejected: Access denied"), and the mail service then suppresses
the address and drops every later send to it in silence, while it still
answers 202 and `accessi_recapitati` still counts it. So the message
goes, decided on 2026-11-10, to the account's mailbox and to its first
external address, both read by the sweep
([`directory_mailboxes()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_mailboxes.md))
and carried here by `identified`: to both in one message when both are
there, the same address once.

## Usage

``` r
mail_access_recipients(row, domain = "ubep.unipd.it")
```

## Arguments

- row:

  One register row as a list, with `mailbox` and `external` as the round
  settled them.

- domain:

  The tenant's verified domain, as
  [`identity_internal()`](https://ubesp-dctv.github.io/ubep.azure/reference/identity_internal.md)
  takes it.

## Value

A character vector: the contact as written when it is external, possibly
empty; otherwise the mailbox and the external address that are there,
without duplicates, possibly none. `NULL` for an internal contact on a
row that does not carry `mailbox` or `external`.

## Details

Nothing when neither is: the caller then sends the message to the
referent, who tells the person
([`mail_access_message()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_access_message.md)).
Never the UPN alone, for the reason above.

A row that does not carry the two fields is another case, and not the
same as one that carries them empty: the round did not say where the
account reads mail, so nobody knows it has nowhere. `NULL` says so, and
the caller loses the message, as a row without an address loses it,
rather than tell the referent something nobody read.
