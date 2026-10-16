# Tell a person an account now exists for them, and what stands in the way

It carries no way in, and that is the decision rather than an omission:
`contact_email` is chosen by whoever fills the form and verified by
nobody, so a secret sent there would let anyone who can file a request
have an account born in the tenant and its key delivered to an address
of their own choosing. The referent who asked for the account hands it
over instead; this message says so, and names them as
[`mail_referent()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_referent.md)
does: the creator the log named, who receives the key, and not
`requested_by`.

## Usage

``` r
mail_welcome_message(row, upn, url = NULL)
```

## Arguments

- row:

  One register row as a list.

- upn:

  The account's user principal name, as created.

- url:

  The address the row's instance opens at, from
  [`mail_instance_url()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_instance_url.md);
  `NULL`, `NA` or empty leaves it out.

## Value

A list with `subject` and `body`.

## Details

It does name the instance, as the address REDCap opens at, and that is
the same decision read from the other side. A message without a secret
can carry the context, and of the two messages a creation sends this is
the one that can: the message with the key carries none of it, because
context is what makes a key spendable. It also says that access to the
project normally follows within four hours, which is the cadence of the
round. Without an address the message still leaves, without those two
lines: a missing address is no reason to lose it.
