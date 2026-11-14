# Put a time limit on a request

One limit for the whole request and one for connecting, the connection
taking in name resolution and the TLS handshake as libcurl counts it.
The order is the point of having it written once:
[`httr2::req_timeout()`](https://httr2.r-lib.org/reference/req_timeout.html)
sets `connecttimeout` back to `0`, which is libcurl's default of 300
seconds, so the connection limit has to come after it. Found on 0.26.0,
with the module.

## Usage

``` r
req_limits(req, limits)
```

## Arguments

- req:

  An `httr2` request.

- limits:

  A list with `total` and `connect`, in seconds.

## Value

The request, with `timeout_ms` and `connecttimeout` set.

## Details

Every door of the package to a service goes through it: the module
([`module_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_call.md)),
the register
([`register_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_call.md)),
Graph
([`directory_page()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_page.md),
[`directory_create_user()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_create_user.md))
and the mail service
([`mail_send()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_send.md)).
The values are each door's own, next to it. The one request left out is
the reading of the suppressions
([`suppression_read()`](https://ubesp-dctv.github.io/ubep.azure/reference/suppression_read.md)),
which has had thirty seconds in all since 0.26.0; a total covers the
connection too.
