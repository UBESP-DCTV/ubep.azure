# Whether a revocation is all that changed since the channel's seal

`request_status` is an intent field, so a revocation always moves the
seal, and a row whose seal moved has its pair read from the log. This
asks the narrower question the seal can answer by itself: is the row as
read the version carried out, with at most its revocation added. It is,
when the seal of the row with `request_status` back to `active` is the
channel's, or when the seal has not moved at all, the revocation having
been carried out or settled already. Either way the instance, the
project and the username the register holds are the ones carried out,
since the seal covers them.

## Usage

``` r
seal_holds_but_revocation(register, sealed, seals)
```

## Arguments

- register:

  The register as read, one row per request.

- sealed:

  The seal the round believes for each row, the channel's own, `""`
  where there is none.

- seals:

  A list as long as the rows of `register`, each element the seals the
  channel wrote on that row in its current life,
  [`log_channel_seals()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_seals.md).

## Value

A logical vector, one per row: `TRUE` only for a row that asks for
`revoked` and that the channel sealed as above.

## Details

And only when the channel carried that version out while it was active:
the seal of the row back to `active` is among the seals the channel
wrote in the row's current life. The round seals a revocation it closes
without asking any instance too, the request withdrawn before its person
was created; that row never granted anything, and its seal unmoved says
nothing about an access.
