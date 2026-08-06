# Read the real authorization state from one REDCap instance

Everything it returns is re-read state: the channel keeps no local copy,
because a copy would only be authoritative if nobody could edit REDCap
outside the job, which is neither true nor desirable.

## Usage

``` r
module_state(
  server,
  secret,
  pairs = list(),
  registry = tested_fingerprints(),
  declare = certified_fingerprints(registry)
)
```

## Arguments

- server:

  Hostname of the instance, optionally followed by the path REDCap is
  mounted under, as in `"host.example.org/redcap"`. The fleet is not
  uniform on this point, so the mount cannot be assumed.

- secret:

  Shared secret, sent as the `X-UBEP-Secret` header.

- pairs:

  List of (username, project_id) pairs; empty reads the whole instance,
  which is what the audit needs.

- registry:

  Tested fingerprints, see
  [`check_fingerprint()`](https://ubesp-dctv.github.io/ubep.azure/reference/check_fingerprint.md).

- declare:

  Fingerprints the caller states it has been tested against. The module
  refuses to write when its own is not among them, so an empty
  declaration writes nothing. Reads and dry runs ignore it.

## Value

A list with `ok`, `errors`, `payload` and `gate`.

## Details

The request travels as a JSON body, not in the query string. Two
reasons: the assertions of the write operations would not fit in a URL,
and in a GET every UPN would land in the access log of each instance on
every run. The module declares its page in `no-csrf-pages` so the POST
is not rejected — see the spec for why CSRF protection does not apply to
this endpoint.
