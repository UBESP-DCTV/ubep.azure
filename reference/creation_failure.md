# Say what went wrong creating an account, and hand back no credential

The credential is `NULL` on every failure, and that is the whole reason
this exists rather than a list literal at four call sites: a credential
traveling beside a failure is a secret nobody will ever use, kept for an
account that may not exist.

## Usage

``` r
creation_failure(code, payload = NULL, unconfirmed = FALSE)
```

## Arguments

- code:

  The transport code, one of the `TRASPORTO_CREAZIONE_*` family.

- payload:

  Anything worth keeping for a diagnosis, or `NULL`.

- unconfirmed:

  Whether the account may have been born all the same.

## Value

A list with `ok`, `errors`, `payload`, `credential`, `upn` and
`unconfirmed`.

## Details

A creation that failed after Graph accepted it — a timeout on the way
back — leaves an account whose credential this round has just discarded.
It is the cost of not keeping one: the next round finds the account by
its surname and contact address and writes `created`, and somebody has
to reset the credential once. Keeping a secret for a creation we cannot
confirm is worse in the direction that matters.

What must not happen is that nobody learns of it, and `unconfirmed` is
what prevents it. It is `TRUE` on the failures that do not say whether
the account was born – no answer at all, one that is not Graph's, or a
5xx of Graph's, which fails while doing the work – and `FALSE` on the
ones that do, a refusal or a throttle carrying Graph's own code. The
round counts an unconfirmed creation as a key lost, so the alarm that
sends IT to reset a key fires on it.
