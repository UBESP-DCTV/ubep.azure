# Write the resolved identity back into the register

The twin of
[`register_import()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_import.md),
and separate from it at the door for the same reason that one exists:
the register holds three families of field — what a person asked for,
what the round resolved about who they mean, and what happened — and no
body may carry two of them. Neither door accepts the other's body, which
makes the separation structural rather than a promise kept by whoever
assembles it.

## Usage

``` r
register_identity_import(url, token, payload)
```

## Arguments

- url:

  Hostname of the instance hosting the register, optionally followed by
  the path REDCap is mounted under. A scheme is dropped rather than
  honored, so a base handed over as http is corrected instead of
  silently downgrading the channel.

- token:

  The API token of the service account, sent in the body.

- payload:

  A data frame as
  [`identity_payload()`](https://ubesp-dctv.github.io/ubep.azure/reference/identity_payload.md)
  returns, one row per record to update. Zero rows is the ordinary quiet
  round and calls nobody.

## Value

The
[`register_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_call.md)
list plus `scritte`, the number of records REDCap reports having taken.

## Details

`overwriteBehavior` is `overwrite`, and the reason here is **not** the
one it is right for the outcomes. The body carries the totality of what
the round owns on this axis, so overwriting can only blank the round's
own two fields — and the blanking is the point: a row that was
`existing` and becomes `ambiguous`, which is the renamed-login case, has
to lose the username that became false rather than keep it beside a
verdict that no longer supports it.
