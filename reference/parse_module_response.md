# Interpret a response from the provisioning module

Recognizes the response by its shape, never by its status code. A module
that is installed but disabled answers HTTP 200 with a plain sentence,
so a client that inferred success from the status would fail inside the
JSON parser, reporting an error that does not name the cause.

## Usage

``` r
parse_module_response(body, status, accepted = c(1L, 2L))
```

## Arguments

- body:

  Raw response body.

- status:

  HTTP status code.

- accepted:

  Integer vector of contract versions this call tolerates. Reads pass
  both, a write passes only the one that can enforce the surface
  handshake — a module that predates it would accept the write and
  simply ignore the declaration.

## Value

A list with `ok`, `errors` and `payload`.

## Details

Shape checking does not stop at "did it parse": a bare literal is valid
JSON and `jsonlite` turns it into a scalar, so the payload must also be
an object.
