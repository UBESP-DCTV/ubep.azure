# Ask the production instances which names REDCap knows

Decided on 2026-11-10 and 2026-11-12 (item 4 (b') of the 0.26.0): before
a verdict that can make an account, the round asks every production
instance which of the names it could create REDCap already knows. Known
means a row in `redcap_user_information`, which `accounts` reads
([`module_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_accounts.md),
through
[`report_server_reads()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_server_reads.md)),
or a row in `redcap_user_rights`, which the whole-instance read of
`state` carries: measured on 2026-11-12, seven productions out of eight
hold names with rights and no account, people added to a project before
their first sign-in.

## Usage

``` r
round_known_names(usernames, productions, hosts, secrets)
```

## Arguments

- usernames:

  The names to ask, as the round would create them.

- productions:

  The names of the production instances, keys of `hosts`.

- hosts, secrets:

  As
  [`provisioning_reconcile()`](https://ubesp-dctv.github.io/ubep.azure/reference/provisioning_reconcile.md)
  receives them.

## Value

A list with `asked`, the names asked of every production (empty when one
was not read), `known`, the names REDCap knows on any of them, folded as
[`identity_normalize()`](https://ubesp-dctv.github.io/ubep.azure/reference/identity_normalize.md)
folds them, and `errors`, the reason of each production not read, once
per code.

## Details

An instance is read only when both answer. `StateReader::read()` answers
an empty list when its query fails, so a production with no pair at all
is an instance not read, `TRASPORTO_STATO_VUOTO`, and not one where
nobody has rights. With any production not read the round has asked
nothing: `asked` is empty and no name is verified, the direction that
does not create. The `state` read is skipped on an instance whose
`accounts` failed, so a machine switched off costs one wait and not two.

The benches are not asked, switched on or off (they hold no real
people); the caller leaves them out of `productions`. With no production
at all there is nobody to ask and every name is verified.
