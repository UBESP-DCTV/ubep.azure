# Hand the way in to the person who asked for the account

It carries the UPN, the key, and nothing else. No project, no role, no
instance, nobody in copy: a message with a way in must not also carry
the context that makes it spendable.

## Usage

``` r
mail_credential_message(row, upn, credential)
```

## Arguments

- row:

  One register row as a list.

- upn:

  The account's user principal name.

- credential:

  What the account was born with.

## Value

A list with `subject` and `body`.

## Details

This message has no second chance, and that is what separates it from
every other one the round sends. The account is already born and the
round does not create it twice, so a send that fails leaves an account
nobody can get into – and the managed identity cannot repair that,
because `User.Create` and `User.Read.All` do not touch an account that
exists.
[`mail_round()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_round.md)
reports the failure under its own code, so an alarm can tell it apart
from a message that will simply be retried.
