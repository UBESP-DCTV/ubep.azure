# Say whom to write to first, in each language

The same sentence closes the welcome and the access message, with one
word changed: what the referent asked for, the account or the access. It
is written once so the two cannot drift apart. With an address it names
the referent; without one it describes them in a form that does not
repeat itself, "the referent who requested your account, who is
responsible for your first sign-in", so that a missing owner does not
turn the sentence into a stutter in either language.

## Usage

``` r
mail_first_contact(referente, cosa)
```

## Arguments

- referente:

  The referent's address, as
  [`mail_referent()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_referent.md)
  gives it; empty when the log settled no owner.

- cosa:

  What was asked for: `"account"` or `"accesso"`.

## Value

A list with `it` and `en`, one string each.
