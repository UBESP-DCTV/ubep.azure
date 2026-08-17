# The closed vocabulary of identity verdicts

What the round observed about the person a request names, never what
somebody should do about it. The distinction is the same one `outcome`
makes: a verdict, not an instruction.

## Usage

``` r
identity_vocabulary()
```

## Value

A character vector of the five verdicts.

## Details

Five words, and they are exhaustive over the two questions the
resolution asks — how many accounts match the contact address, and
whether the composed UPN is taken:

- one match — `existing`, or `created` when the account was not there
  when the row was last looked at;

- no match, composed UPN free — `absent`;

- no match, composed UPN taken — `collision`;

- more than one match — `ambiguous`.

`absent` is the one the four approved on 2026-08-07 were missing, and
its absence was not an oversight: they assume resolving and creating are
a single act, so the case became `created` at once. It does not, and a
state that can last needs a name — for a creation that failed, and for
the row a person is still looking at.

Only the first two admit an action: the gate refuses a row whose verdict
is any of the other three, which is why the vocabulary being closed
matters more here than a vocabulary usually does.
