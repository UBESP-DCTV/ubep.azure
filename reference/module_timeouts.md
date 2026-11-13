# Time limits of a call to the module

Five minutes for the whole call and thirty seconds to connect, the
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
production, and a write of many rows. Measured on 2026-11-10 and
2026-11-11, the observer read all nine instances it reaches whole, about
18,450 pairs, Key Vault included, in about 75 seconds; the largest
instance alone took less. Five minutes is four times the whole fleet. A
write that runs out of time may have been carried out, so the limit errs
long rather than short: a write too slow for it is a row that converges
one round later, and its access message is lost (see
[`mail_round()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_round.md)),
while an instance that never answers costs at most two waits per round.
One that answers reads and hangs on writes costs a wait for every batch
it is sent, one per project.

Connecting does nothing on the instance, so a short limit costs no
write. Thirty seconds is far above a connection inside the network and
well below libcurl's default of 300 seconds.
