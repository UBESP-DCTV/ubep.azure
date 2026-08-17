# Send a body REDCap will overwrite, and check it took all of it

The transport both writers share, and one copy of it rather than two.
What keeps the field families apart is the door each writer fixes — its
own column list, refused at the threshold — and not the mechanics of the
call, which are the same question asked of the same API. Two copies of
the partial-write check would be a place to fix a defect once and leave
it standing in the other.

## Usage

``` r
register_field_import(url, token, payload, expected, caller, reason)
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

  The body, already shaped by its builder.

- expected:

  The exact column names this writer accepts, in order.

- caller:

  The writer's name, so a refusal names the door that refused.

- reason:

  The sentence that says why this body may carry nothing else.

## Value

The
[`register_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_call.md)
list plus `scritte`.
