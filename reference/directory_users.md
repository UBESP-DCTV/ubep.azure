# Read the whole directory of the tenant

The only function in the package that speaks to Microsoft Graph, and the
only one that builds its URL. It does one thing: it sweeps, and it
decides nothing — no normalization, no exclusion of guests, no
comparison. Those are pure and live elsewhere.

## Usage

``` r
directory_users(token, base_url)
```

## Arguments

- token:

  A Graph access token, sent as a bearer credential in the
  `Authorization` header and never in the URL. The managed identity
  holds `User.Read.All` and `User.Create`, and neither can modify,
  disable or delete an existing account.

- base_url:

  The Graph endpoint, as in `"host.example.org/v1.0"`. It is an argument
  and not a constant in this file: this repository is public, and an
  endpoint written in is an endpoint published. A scheme is dropped
  rather than honored, so a base handed over as http is corrected
  instead of sending a bearer token in clear.

## Value

A list with `ok`, `errors` and `payload`, shaped like the other adapters
because it answers the same kind of question, plus `users`, the frame.
"I could not ask" stays distinguishable from "nobody is there": the
first is `ok = FALSE` with `users` `NULL`, the second is `ok = TRUE`
with zero rows.

## Details

**It sweeps rather than filters, and that is a measurement and not a
preference.** `officeLocation` — where the historical flow put the
contact address, and where 6.494 accounts still carry it — is not
filterable server-side at all: Graph answers `Request_UnsupportedQuery`.
`mail`, which would be filterable, is `null` on 6.412 accounts out of
7.664, so the obvious attribute is empty on exactly the population to be
found. Measured on 2026-08-15 the whole sweep costs 8 pages and 3,5
seconds, which is less than the round that consumes it. It is also
decision 4 of the channel's design obtained by construction rather than
by discipline: no local copy of the state, the real one is re-read every
round.

Reading in full has a property a server-side filter would not have
given: the comparison is ours, so it can normalize. It has to — 74
accounts carry the address with spaces at the edges, and an `eq` would
have missed them in silence, reporting `absent` for people who exist.
