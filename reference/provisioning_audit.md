# Audit the whole fleet against the desired state

Re-reads reality on every run rather than keeping a copy of it, then
diffs. Surfaces the three drifts nobody sees today: accesses present in
REDCap that no request asked for, assignments requested and since
vanished, and expirations that passed without effect.

## Usage

``` r
provisioning_audit(servers, secrets, desired)
```

## Arguments

- servers:

  Character vector of hostnames, each optionally carrying the path
  REDCap is mounted under, as in `"host.example.org/redcap"`. Keeping
  the mount inside the same string is what avoids a second vector to
  hold parallel to `secrets` and keep aligned by hand.

- secrets:

  Named character vector of per-server secrets.

- desired:

  List of validated requests, each carrying the `server` it belongs to.

## Value

A data frame, one row per (server, user, project).

## Details

A server that cannot be reached becomes a row, not an exception: one
instance being down must not hide the state of the others.

Because `state` reports `redcap_major` and `surface_fingerprint`, the
audit learns the set of majors in the fleet for free. That set is what
the two clauses on retiring compatibility branches rest on.
