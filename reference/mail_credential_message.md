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

What it asks of the referent is the rule decided for handing the key
over: another channel if there is one, otherwise a new message with the
key alone, never a forward of this one, and to the address the referent
knows from their own correspondence rather than the one copied from the
request. The welcome went to the address in the request, so a referent
who finds the two different is asked to stop and reply instead of
sending. The same sentence asks them to leave the key out of the reply:
a mail client quotes this body by default, and the reply goes to the
round's reply address, where a key not yet used would stay readable.

This message has no second chance, and that is what separates it from
every other one the round sends. The account is already born and the
round does not create it twice, so a send that fails leaves an account
nobody can get into – and the managed identity cannot repair that,
because `User.Create` and `User.Read.All` do not touch an account that
exists.
[`mail_round()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_round.md)
reports the failure under its own code, so an alarm can tell it apart
from a message that will simply be retried.
