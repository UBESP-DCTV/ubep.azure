# Decide whether the single match really is the person the row means

A match on the contact address is where the confirmation starts, not
where it ends. Three things can stop it, and the prefix on each is a
delivery address rather than a label: `DATO_` closes the row against
whoever filed it and mails them, `TRASPORTO_` keeps it queued and mails
us.

## Usage

``` r
confirm_identity(account, declared, previous)
```

## Arguments

- account:

  The single matching row of the directory frame.

- declared:

  The declared UPN, normalized and possibly filled in from an internal
  contact address. Empty once a verdict exists on the row, because then
  the register's `username` is this round's own earlier answer and not a
  declaration to confirm.

- previous:

  The previous verdict, normalized.

## Value

A list with `identity`, `username` and `errors`.

## Details

The two `TRASPORTO_` ones are fields the account does not carry, and
neither is the filer's to fix. Telling the one person who cannot reach a
directory attribute that they are not authorized sends them to go and
argue — which is the same reasoning
[`scope_errors()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_errors.md)
gives for its fourth case.
