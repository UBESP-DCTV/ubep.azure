# Hand one message to the mail service

REDCap on the register's instance does not send over SMTP: it sends
through its mail provider's HTTP API. So does this, which is why no new
dependency appears – the call is a JSON POST, the same shape
[`module_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_call.md)
already uses.

## Usage

``` r
mail_send(api_key, from, to, subject, body, cc = NULL, reply_to = NULL)
```

## Arguments

- api_key:

  The service key, which the runner reads from Key Vault.

- from:

  The verified sender identity.

- to:

  Recipient address.

- subject, body:

  The composed message.

- cc:

  Optional address in copy.

- reply_to:

  Optional address replies should reach.

## Value

A list with `ok` and `errors`.

## Details

`202` is what success looks like, and it means "accepted", not
"delivered". A bounce happens afterwards and asynchronously, and never
comes back into the round. What the round can promise is that it did not
lose the message through a fault of its own; it cannot promise the
referent read it.

`from` is not a choice: the account has one verified sender identity and
any other address is refused. It arrives as an argument all the same,
because a resource name written into a public repository is a resource
name published.
