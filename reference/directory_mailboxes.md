# Where the account an internal contact names reads its mail

The access message of a row whose contact is internal does not go to
that contact. By decision 12 it is the UPN, and for most accounts of the
tenant the UPN has no mailbox behind it: Exchange Online refuses the
message, and from then on the mail service suppresses the address and
drops every later send to it in silence, after the person has been given
a mailbox too. Decided on 2026-11-10: the message goes to two candidates
instead, both read here from the sweep the round has already made, with
no call of its own.

## Usage

``` r
directory_mailboxes(directory, upns, domain = "ubep.unipd.it")
```

## Arguments

- directory:

  A directory frame as
  [`directory_users()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_users.md)
  returns.

- upns:

  The UPN each row resolved to, as the resolution answered it. A name
  that is not an account of the tenant, as a collision's proposal, gets
  two empty strings.

- domain:

  The tenant's verified domain, as
  [`identity_internal()`](https://ubesp-dctv.github.io/ubep.azure/reference/identity_internal.md)
  takes it.

## Value

A data frame with `mailbox` and `external`, one row per UPN: `mailbox`
trimmed and otherwise as the directory writes it, `external` as
[`directory_address()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_address.md)
reads it.

## Details

`mailbox` is the account's `mail`, when it carries one: Exchange writes
the primary address there when it gives the account a mailbox, and on
about 6.400 of the 7.700 accounts it is empty. The UPN does not count as
one.

`external` is the first address the account carries outside the domain:
the first of `otherMails`, otherwise `officeLocation`, the historical
carrier of decision 9, which on many accounts holds a room instead. Each
is read with
[`directory_address()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_address.md),
which takes punctuation off its ends and keeps it only when what is left
has the strict form of an address; one that does not is skipped for the
next. An alias in the domain is skipped too, being the same mailbox or
none.
