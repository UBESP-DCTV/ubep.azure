# Whether an address is in the tenant's domain

Decision 12 in one line: an address in the domain **is** a UPN. The
resolution reads it to tell an internal contact from an external one,
the access message to decide where it goes
([`mail_access_recipients()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_access_recipients.md)),
and
[`directory_mailboxes()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_mailboxes.md)
to tell an external address from an alias. Written once, so that what
counts as internal cannot drift apart between the three.

## Usage

``` r
identity_internal(addresses, domain = "ubep.unipd.it")
```

## Arguments

- addresses:

  A character vector, or anything coercible to one.

- domain:

  The tenant's verified domain, defaulting as
  [`compose_upn()`](https://ubesp-dctv.github.io/ubep.azure/reference/compose_upn.md)
  does.

## Value

A logical vector, `FALSE` on an empty or missing address.
