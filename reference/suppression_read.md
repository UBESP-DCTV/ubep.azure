# Read the suppression lists of the mail service, whole

**It only reads.** A `GET` on each of the five lists of
[`suppression_lists()`](https://ubesp-dctv.github.io/ubep.azure/reference/suppression_lists.md),
page by page, with a key whose only rights are those reads: no
`/mail/send`, no `DELETE`. Taking an address off a list is a gesture IT
makes by hand in the console, after correcting what made it bounce
(decided on 2026-11-12). A guard in `test-runner-guardie.R` holds this
function to that.

## Usage

``` r
suppression_read(api_key, limit = 500L, max_pages = 200L)
```

## Arguments

- api_key:

  The read-only key, which the runner reads from Key Vault.

- limit:

  Entries per page.

- max_pages:

  Pages per list, the empty one included, past which the list is taken
  as one that never ends. Bounces held a few hundred entries in November
  2026: 200 pages are 100.000 entries at 500 a page, 20.000 at 100.

## Value

A list with `ok`, `errors` and `voci`, a data frame of `lista`, `email`,
`creata` (POSIXct, UTC) and `motivo`, every entry of the five lists when
`ok`, none otherwise.

## Details

The key goes in the `Authorization` header and nowhere else, as in
[`mail_send()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_send.md).
A failure is an outcome and not an exception, with the service's own
words on the standard error, which is the journal of the unit: on
2026-08-27 the same refusal by IP Access Management answered 403 on one
endpoint and 401 on another.

Each request waits thirty seconds at most, and a time out is a failure
like any other: the reading comes before the report, and must not hold
it.

The first failure stops the reading: a list read in part is not a list
read, and nothing that follows would change that. A failure on the first
page of a list is `TRASPORTO_SOPPRESSIONI_NON_LEGGIBILI` (the network, a
key refused or revoked, an address not admitted); a failure on a later
page, or a list that never ends, is `TRASPORTO_SOPPRESSIONI_INCOMPLETE`.
The list ends at the first page that comes back empty, and not at the
first shorter than `limit`: the ceiling per page is the documentation's
and not measured, and a service that hands back fewer entries than asked
would otherwise close the list after its first page with the reading
said whole. One request more per list, five a day. The next page starts
after the entries received, not after `limit`. A list that reaches
`max_pages` without an empty page is a reading that failed, not a list
cut short.

The parameters `limit` and `offset`, the ceiling of 500 entries per page
and the shape of an entry (`email`, `created` in seconds since the
epoch, `reason` where the list has one) are those of SendGrid's
documentation of the v3 API as read on 2026-11-12, not yet measured: the
first reading on the machine says whether the service agrees.
