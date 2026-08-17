# Say what went wrong creating an account, and hand back no credential

The credential is `NULL` on every failure, and that is the whole reason
this exists rather than a list literal at four call sites: a credential
traveling beside a failure is a secret nobody will ever use, kept for an
account that may not exist.

## Usage

``` r
creation_failure(code, payload = NULL)
```

## Arguments

- code:

  The transport code, one of the `TRASPORTO_CREAZIONE_*` family.

- payload:

  Anything worth keeping for a diagnosis, or `NULL`.

## Value

A list with `ok`, `errors`, `payload`, `credential` and `upn`.

## Details

A creation that failed after Graph accepted it — a timeout on the way
back — leaves an account whose credential this round has just discarded.
It is the honest cost of not keeping one: the next round finds the
account by its surname and contact address and writes `created`, and
whoever needs to let that person in resets it once. Keeping a secret for
a creation we cannot confirm is worse in the direction that matters.
