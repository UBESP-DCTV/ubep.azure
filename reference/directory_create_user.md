# Create on Entra the account a request needs and nobody has

The second and last thing this package does on Microsoft Graph, and it
does one thing: it creates. `User.Create` is what it runs under, and
that permission cannot modify an existing account, reset a credential,
disable or delete — which is why the round can hold it without holding
everything else.

## Usage

``` r
directory_create_user(token, base_url, request, upn)
```

## Arguments

- token:

  A Graph access token, sent as a bearer credential in the
  `Authorization` header and never in the URL. The managed identity
  holds `User.Read.All` and `User.Create`, and neither can modify,
  disable or delete an existing account.

- base_url:

  The Graph endpoint, as in `"host.example.org/v1.0"`. It is an argument
  and not a constant in this file: this repository is public, and an
  endpoint written in is an endpoint published. A scheme is dropped
  rather than honored, so a base handed over as http is corrected
  instead of sending a bearer token in clear.

- request:

  The register row, read only for `first_name`, `last_name` and
  `contact_email`.

- upn:

  The name to create, which the resolution found free.

## Value

A list with `ok`, `errors`, `payload`, `upn`, and `credential` — the one
the account was born with, present only on success. It leaves by the
return value and by no other road: not the register, not the telemetry
record, not standard output.

## Details

**It does not compose the name it creates.** The UPN is an argument, and
the caller takes it from the verdict that found it free. Composing it
again here would be two paths to one answer: the day somebody hands a
domain to the resolution and not to this, the round would check that one
name is free and create another — a UPN nobody has checked for a
collision, which is the failure this whole sub-project is about.

**`givenName` and `surname` are in the body because the criterion is the
surname.** They are not decoration and they are not in the plan's list,
which predates the reversal of 2026-08-15: an account created without a
surname is an account the next sweep cannot find, while the UPN it would
compose is now taken — so the row comes back `collision`, and the round
would have created the person and then told them for ever that their
name is another person's.

**No `jobTitle` and no `officeLocation`.** The first is a live mechanism
and not a fossil — 2.828 accounts carry the serialized authorization,
254 of them created in 2026 — so what has to be armed is the
not-inheriting, and a guard does it. The second is the legacy carrier of
the contact address: read for as long as accounts carry it, written
never again.
