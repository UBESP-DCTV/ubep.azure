# Tell a person an account now exists for them, and what stands in the way

It carries no way in, and that is the decision rather than an omission:
`contact_email` is chosen by whoever fills the form and verified by
nobody, so a secret sent there would let anyone who can file a request
have an account born in the tenant and its key delivered to an address
of their own choosing. The referent who asked for the account hands it
over instead; this message says so, and names them.

## Usage

``` r
mail_welcome_message(row, upn)
```

## Arguments

- row:

  One register row as a list.

- upn:

  The account's user principal name, as created.

## Value

A list with `subject` and `body`.
