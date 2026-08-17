# The rows that carry this person's name

The surname is the criterion and the given name confirms it **only when
the account carries one**. An account with a surname and no given name
stays in play: it is not a different person, it is a person we know less
about, and dropping it would let a homonym through unseen.

## Usage

``` r
directory_named(directory, first_name, last_name)
```

## Arguments

- directory:

  A directory frame as
  [`directory_users()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_users.md)
  returns.

- first_name, last_name:

  The names the register row declares.

## Value

A logical vector, one per row.

## Details

An account with no surname at all matches nobody. The name is what this
question is asked with, and an account that does not answer it cannot be
the one — which is why the sweep asks Graph for `givenName` and
`surname`.

Folded with `clean_string()`, the same way
[`compose_upn()`](https://ubesp-dctv.github.io/ubep.azure/reference/compose_upn.md)
folds a name, so what counts as the same name here and what a composed
UPN looks like cannot drift apart.
