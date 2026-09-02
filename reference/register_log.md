# Read who touched the register, and when

The one question the register's own fields cannot answer. `requested_by`
says who filed a row only because `@USERNAME` filled it in on the form,
and an action tag governs the form and not the API: measured on
2026-09-01, an import writes into that field whatever it is handed. The
log says who was **authenticated**, which is not a value anybody can
type.

## Usage

``` r
register_log(url, token, since = NULL, logtype = NULL)
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
  time. `NULL` asks without one, which REDCap reads as "no begin time"
  and answers with the whole log.

- logtype:

  REDCap's own classification of the event, or `NULL` for every kind.
  `"record_add"` is the creations and nothing else. It is asked of
  REDCap rather than filtered here because the alternative is reading
  the prose of `action`, which is not stable: measured on 2026-09-02,
  one act reads `Create record 7` from the form and
  `Create record (import) 20` from an import, and a reader matching that
  string would have to keep up with REDCap's wording for ever.

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
