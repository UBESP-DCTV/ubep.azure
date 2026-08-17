# Is this continuation still the endpoint the caller named?

A continuation is a URL the other end chooses, and following it blindly
means handing an application credential to whatever host it names. The
comparison is on the parsed host and not on a prefix of the string,
because `https://graph.example.org@elsewhere.example.net/` starts with
the right text and resolves to the wrong machine. The scheme is checked
too: a continuation offered over plain HTTP would put the bearer token
on the wire in clear.

## Usage

``` r
same_endpoint(continuation, endpoint)
```

## Arguments

- continuation:

  The `@odata.nextLink` Graph handed back.

- endpoint:

  The base this package built its first URL from.

## Value

`TRUE` only when the continuation is https and on the same host.

## Details

Fails closed on anything it cannot parse, which is the only safe
direction for a question whose wrong answer is a leaked credential.
