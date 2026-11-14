# Time limits of a call to Graph

One minute for a page of the sweep and for a creation, and ten seconds
to connect, the connection as for the module
([`module_timeouts()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_timeouts.md)).

## Usage

``` r
directory_timeouts()
```

## Value

A list with `total` and `connect`, in seconds.

## Details

A page of the sweep takes a fraction of a second; a creation was never
timed on its own. A page that runs out of time fails the whole sweep,
`TRASPORTO_DIRECTORY_NON_RAGGIUNGIBILE`, and the round asks no instance.
A creation that runs out of time may have made the account: it is
`TRASPORTO_CREAZIONE_NON_RAGGIUNGIBILE` and unconfirmed, and the key and
the welcome are counted lost, as for every creation without an answer.
Without a limit the same creation held the round until systemd stopped
it, with the key in the memory of the process and nothing counted.
