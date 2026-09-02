# Read who touched the register, and when

The one question the register's own fields cannot answer. `requested_by`
says who filed a row only because `@USERNAME` filled it in on the form,
and an action tag governs the form and not the API: measured on
2026-09-01, an import writes into that field whatever it is handed. The
log says who was **authenticated**, which is not a value anybody can
type.

## Usage

``` r
register_log(url, token, since)
```

## Arguments

- url:

  Hostname of the instance hosting the register, optionally followed by
  the path REDCap is mounted under. A scheme is dropped rather than
  honored, so a base handed over as http is corrected instead of
  silently downgrading the channel.

- token:

  The API token of the service account, sent in the body.

- since:

  Beginning of the window, `"%Y-%m-%d %H:%M"`, in the instance's civil
  time.

## Value

The
[`register_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_call.md)
list plus `log`, a data frame.

## Details

`since` is in the **instance's** civil time and not in UTC, which is the
one thing about this call that is easy to get wrong. REDCap stamps its
log with the server clock: measured on 2026-09-01, a round that ran at
21:03 UTC appears in the log at 23:03. The channel keeps UTC everywhere
else, so a caller that handed its own stamp straight through would ask
for a window shifted by two hours in summer and **one in winter** — a
discrepancy that is not a constant and that would come and go with the
change of hour.

Callers therefore convert, and they are expected to convert generously:
the window is cheap to widen and the filtering that matters is done on
the rows, not on the boundary.
