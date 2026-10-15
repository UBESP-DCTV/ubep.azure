# Say where an instance opens, from the host the inventory names

The host is the one
[`provisioning_reconcile()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_reconcile.md)
already holds, read from the inventory on the machine: the address is
not composed from `server` and is not written anywhere in this
repository. The scheme and the trailing slashes are dropped first, as
[`module_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_call.md)
drops them, so a host the instances answer on cannot turn into an
address nobody can open.

## Usage

``` r
mail_instance_url(host)
```

## Arguments

- host:

  The instance's host, optionally followed by the path REDCap is mounted
  under.

## Value

The address as a person opens it, or `NULL` when there is no host.
