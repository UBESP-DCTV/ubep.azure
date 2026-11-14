# Time limits of a message to the mail service

One minute for a message and ten seconds to connect, the connection as
for the module
([`module_timeouts()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_timeouts.md)).

## Usage

``` r
mail_timeouts()
```

## Value

A list with `total` and `connect`, in seconds.

## Details

The service answers as soon as it has queued the message. The sending
was never timed on its own; the readings of the suppressions, on the
same service, fit in a short report. Every message costs its own wait,
so a service that hangs costs a round a minute a message: as many
minutes as rows changed together, plus the keys, the welcomes and the
access messages.

A message that runs out of time may have been accepted. It is
`TRASPORTO_POSTA_NON_RAGGIUNGIBILE`, like a service that cannot be
reached, and is never sent a second time in the same round, since a
transport that failed may have failed after the service took the
message: an outcome is not written and goes again next round, and a key,
a welcome or an access message is counted lost even if it left.
