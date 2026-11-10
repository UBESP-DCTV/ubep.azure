# Which rows of the register the report speaks about, and where

Three sets, the one place that says them:

## Usage

``` r
report_scope(register)
```

## Arguments

- register:

  The register as read.

## Value

A list of three logical vectors as long as the register, `conta`,
`ferma` and `disattivata`.

## Details

- `conta`, the rows of the referents' reports: `request_status` is
  `active` and the row is an access, `outcome` `applied` or a seal in
  `applied_seal`, whatever the outcome (decided on 2026-11-10). A row
  the channel executed and that then stopped, `held`, a `data_error` or
  a `transport_error`, still has on the instance the access executed:
  the round takes nothing away unless a row asks it to. The field is
  enough to say the row was executed: the report grants nothing, and a
  seal somebody imported is at most a row more. The rows stopped on a
  disabled account are not in it: the person cannot sign in, and IT has
  them in a section of its own, `disattivata`;

- `ferma`, the rows the mail to IT lists as stopped with an access
  executed: sealed, not `applied`, active or revoked. A revocation of an
  executed row that the round did not carry out, stopped at the gate on
  `DATO_AMBITO_NON_AUTORIZZATO`, waiting for its owner as `held`, or on
  `DATO_COPPIA_CAMBIATA` or `TRASPORTO_IDENTITA_CAMBIATA`, is an access
  that should be gone and is not, and it is no longer in any referent's
  report. Not the rows with `TRASPORTO_ACCOUNT_DISATTIVATO` among their
  codes, active or revoked: the active ones are `disattivata`, and none
  is listed twice. Not a revocation the log says was carried out and
  that somebody touched afterwards, `revoca_eseguita` of
  [`report_executed_register()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_executed_register.md):
  its seal moved, but the access is gone;

- `disattivata`, the active rows stopped on a disabled account:
  `transport_error` with `TRASPORTO_ACCOUNT_DISATTIVATO` among the codes
  of `outcome_detail`, sealed or not.
