# The closed vocabulary of identity verdicts

What the round observed about the person a request names, never what
somebody should do about it. The distinction is the same one `outcome`
makes: a verdict, not an instruction.

## Usage

``` r
identity_vocabulary()
```

## Value

A character vector of the six verdicts.

## Details

Six words, and they are exhaustive over the three questions the
resolution asks (how many accounts match the contact address, whether
the composed UPN is taken, and whether the one account matched can sign
in):

- one match: `existing`, or `created` when the account was not there
  when the row was last looked at;

- one match on a deactivated account: `disabled`;

- no match, composed UPN free: `absent`;

- no match, composed UPN taken: `collision`;

- more than one match: `ambiguous`.

`absent` is the one the four approved on 2026-08-07 were missing, and
its absence was not an oversight: they assume resolving and creating are
a single act, so the case became `created` at once. It does not, and a
state that can last needs a name — for a creation that failed, and for
the row a person is still looking at.

`disabled` is the sixth, and the last in the list so that the five the
live dictionary already carried keep their order. The channel never
enables an account, so the row waits for IT
([`identity_stop_codes()`](https://ubesp-dctv.github.io/ubep.azure/reference/identity_stop_codes.md)).

Only the first two admit an action: the gate refuses a row whose verdict
is any of the other four, which is why the vocabulary being closed
matters more here than a vocabulary usually does. A revocation on a
`disabled` account is the one exception, and it is the round's
([`provisioning_reconcile()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_reconcile.md)):
taking a right away does not need anybody to sign in.
