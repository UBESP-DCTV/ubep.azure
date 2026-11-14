# Time limits of a call to the register

One minute for a call and ten seconds to connect, the connection as for
the module
([`module_timeouts()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_timeouts.md)).

## Usage

``` r
register_timeouts()
```

## Value

A list with `total` and `connect`, in seconds.

## Details

The register lives on a REDCap instance like the others, and an update
of the fleet, a table change that holds the readings, is the typical
case of a connection taken and no answer. Its calls are short: a read of
the event log takes a fraction of a second, and the whole report, which
reads the rows and the log, a few seconds. A minute is far more than the
read of the log.

Not the five minutes of the module, because the register is asked many
times in a round and every question costs its own wait. A register that
hangs after the round has read the rows makes it wait at most nine times
(the log of the creations, the log of the owners, the identities, the
outcome, the owner twice, the Entra account twice, the seals), plus one
for every row whose log is read on its own, and the report twice plus
one per row: with five minutes the round would reach the three hours of
its unit with 27 such rows, and the report its hour with 10; with one
minute the report reaches it with 58.

A write that runs out of time may have been carried out, and the answer
be what was lost. The round writes to the register after the mail ("send
first, write after", see
[`provisioning_reconcile()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_reconcile.md)),
and the next round computes again what the register is told from the
instances' state, so nothing is granted twice. What it costs: the code
goes into `errori` and the alarm on outcomes not written sounds, whether
or not the write had arrived; when it had not, the next round sends the
outcome message again.
