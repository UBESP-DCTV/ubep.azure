# Whether a revoked row takes the access away from the name carried out

Decided on 2026-11-12 (item 12, widened): a revoked row the channel
carried out revokes the username carried out on the pair carried out,
whatever the resolution says now, when the version carried out is
**certain** and the row still names the instance and the project carried
out. The account renamed on Entra stays the way it is (option (a) of the
2026-11-10): the owner revokes the old row, which takes the old login
off the project, and files a new one, which finds the new name; IT does
not touch the instance. Widened to every verdict that names nobody,
because a renamed account with an internal contact does not reach
`TRASPORTO_IDENTITA_CAMBIATA`: its contact is the old UPN, which the
tenant no longer holds, and the resolution stops on
`DATO_RECAPITO_INTERNO_INESISTENTE`. The same for `ambiguous` and for a
collision nobody answered.

## Usage

``` r
revocation_exits(executed, current, certain, creating, granted = character())
```

## Arguments

- executed:

  The `server`, `project_id` and `username` carried out, as for
  [`pair_change()`](https://ubesp-dctv.github.io/ubep.azure/reference/pair_change.md),
  or `NULL` when the row was never carried out.

- current:

  The row as the register holds it, a list or a one-row data frame with
  `server`, `project_id` and `request_status`.

- certain:

  Whether `executed` is the version carried out for certain.

- creating:

  Whether the round would create a person for the row.

- granted:

  The usernames the channel carried out on the row while it was active,
  [`log_granted_names()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_granted_names.md).

## Value

`TRUE` when the row revokes the username carried out.

## Details

Certain means the seal of the channel did not move and the register as
read is the version carried out, or
[`log_executed_row()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executed_row.md)
rebuilt it and the seal verified it. On a version the log does not
verify the row stays where the rule of the pair puts it, as before.

Outside, decided on 2026-11-12:

- an instance or a project moved: the gate would judge the rights on the
  wrong project, and the row stays on `DATO_COPPIA_CAMBIATA` until the
  referent brings them back;

- a person the tenant no longer holds, a row to create: its revocation
  closes before any instance is asked
  ([`pair_change()`](https://ubesp-dctv.github.io/ubep.azure/reference/pair_change.md)),
  and the old login stays for IT to take off by hand, as before;

- a row carried out for nobody, closed before anybody was resolved;

- a name the channel never carried out on the row while it was active,
  [`log_granted_names()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_granted_names.md):
  a request withdrawn before its person was created is sealed under the
  name the round would have created, a collision's proposal among them,
  and that name may be somebody else's later (RC1 of the review of unit
  G, 2026-11-12).
