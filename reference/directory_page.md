# Fetch one page of the directory

The answer is recognized by its shape and by its status, the way the
register's client does it and for the same reason: an endpoint that is
not the one meant can answer 200 with something that is not JSON, and a
client that inferred success from the status would fail inside the
parser reporting a cause that is not the cause.

## Usage

``` r
directory_page(token, url)
```

## Arguments

- token:

  A Graph access token, sent as a bearer credential in the
  `Authorization` header and never in the URL. The managed identity
  holds `User.Read.All` and `User.Create`, and neither can modify,
  disable or delete an existing account.

- url:

  The page to read: the first one this package builds, every one after
  it a continuation Graph handed back.

## Value

A list with `ok`, `errors` and `payload`, the last being the parsed body
on success.
