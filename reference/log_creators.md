# Who was authenticated when each of these rows was created

The answer the register's own fields cannot give. `requested_by` is
filled in by `@USERNAME`, and an action tag governs the form REDCap
draws: an import draws no form, so it writes into that field whatever it
is handed. Measured on 2026-09-02 on a live instance, an import creation
logs `username` as the account that was authenticated and carries the
forged name only inside `details`, where it is a string somebody chose
rather than a fact REDCap established.

## Usage

``` r
log_creators(events, records)
```

## Arguments

- events:

  The creation events, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns them when asked with `logtype = "record_add"`. Handing it a
  wider log would answer with whoever last touched the row instead of
  whoever made it.

- records:

  The record ids to answer about.

## Value

A character vector as long as `records`, holding the username or `""`
where no creation event names that row. `""` is not "nobody made it": it
is "the log did not say", and the caller decides what that means.

## Details

It answers from `record` and `username`, which is what keeps it apart
from
[`log_last_author()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_last_author.md).
That one searches `details` for a field pattern because it asks "who
wrote this field"; this one asks "who made this row", and the caller has
already had REDCap answer only with creations.

`action` is then read as a **guard and not as the mechanism**, and the
distinction is the whole of it. REDCap ignores a parameter it does not
know rather than refusing it, so a `logtype` it silently dropped would
come back as a complete log that looks exactly like a valid answer – and
the newest event for a row would be whoever last edited it, not whoever
opened it. Reading the prose is a bad primary mechanism, because the
same act reads `Create record 7` from the form and
`Create record (import) 20` from an import. It is a sound guard because
it fails **closed**: reword the string and nothing matches, the answer
is empty, and the caller holds the row instead of judging it against the
wrong person.

The most recent event wins, and which one that is comes from the order
of the answer rather than from the timestamp – REDCap's own, newest
first, the same rule
[`log_last_author()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_last_author.md)
follows. A record id normally carries one creation; it can carry two
when an id was deleted and made again, and then the row that exists now
is the one made last.
