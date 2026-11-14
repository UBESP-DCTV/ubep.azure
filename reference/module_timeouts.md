# Time limits of a call to the module

Five minutes for the whole call and ten seconds to connect, the
connection taking in name resolution and the TLS handshake as libcurl
counts it.

## Usage

``` r
module_timeouts()
```

## Value

A list with `total` and `connect`, in seconds.

## Details

The whole call is the longest thing the module is asked: the read of
`state` of a whole instance, which step 3b of the round makes on every
production, and a write of many rows. The observer reads the whole of
every instance it reaches, Key Vault included, well within five minutes,
so only a call that has stopped answering reaches the limit. A write
that runs out of time may have been carried out, so the limit errs long
rather than short: a write too slow for it is a row that converges one
round later, and its access message is lost (see
[`mail_round()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_round.md)),
while an instance that never answers costs at most two waits per round.
One that answers reads and hangs on writes costs a wait for every batch
it is sent, one per project.

Connecting does nothing on the instance, so a short limit costs no
write. Ten seconds holds for every instance, benches and productions
alike. A bench that is switched off does not answer the connection, and
the observer, which reads every instance one after the other, waits the
whole limit for each: the thirty seconds of 0.26.0 made it last several
times as long as up to 0.25.0, when nobody set the limit and libcurl's R
package put in ten seconds of its own. Ten seconds brings that back. A
whole call to a production that is on, the connection and the handshake
included, takes a fraction of a second, well under the limit; a limit
too short would read a production that is on as
`TRASPORTO_NON_RAGGIUNGIBILE`, which is why it does not go lower. Only
the connection is shorter: what PHP does keeps the five minutes, benches
included.
