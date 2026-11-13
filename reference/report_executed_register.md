# The register with the pair each stopped row executed

A row that stopped after the channel executed it keeps on the instance
the access executed, and the servers are asked about that one, not about
the one the register holds now. Two ways of knowing it, as in the round:

## Usage

``` r
report_executed_register(
  register,
  logs,
  creators,
  approvers = NULL,
  channel_account = NULL
)
```

## Arguments

- register:

  The register as read.

- logs:

  One element per row, in the register's order: the row's log, or `NULL`
  where it was not read.

- creators:

  Who created each row, as
  [`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
  answers. Not read any more: the reconstruction does not need it. Kept
  for the runners that pass it.

- approvers:

  The IT accounts whose approval counts on any row, or `NULL` when the
  caller does not know them. Not read any more, for the same reason: a
  runner that does not pass them no longer loses the name executed.

- channel_account:

  The REDCap usernames that hold the register's token, or `NULL` when
  they are not configured.

## Value

The register, with `server`, `project_id` and `username` the ones
executed, and four columns more: `username_registro`, the name the
register holds; `nome_eseguito`, `registro` or `log`, where the name
executed was read, `""` when it is not known; `nome_motivo`, why not:
`log`, `""` when it is known; `revoca_eseguita`, `TRUE` on a revoked row
whose state executed, in the verified version, is `revoked`: carried
out, then touched, so that
[`report_scope()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_scope.md)
leaves it out of `ferma`. A version not verified leaves it `FALSE`, the
side that shows more.

## Details

- **the seal did not move**: the register is what was executed. The seal
  is the channel's last one in the row's log,
  [`log_channel_seal()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_seal.md),
  when the channel's account is configured, as the round reads it;
  otherwise the field;

- **the seal moved**: the version the round last carried out, rebuilt
  from the log and verified by the channel's seal,
  [`log_executed_row()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executed_row.md)
  (decided on 2026-11-12). A seal moves on a row `held` on its role, and
  on a row the identity door rewrote after an account changed on Entra,
  which stops on `TRASPORTO_IDENTITA_CAMBIATA` with the new name in the
  register and the old one on the instance. A name written by somebody
  else and carried out with no approval is the name executed, and the
  one the servers are asked about; a revocation written while a round
  ran was not carried out, and the row stays among the stopped ones.

Where the version is not verified, no cut of the log giving the
channel's seal, or the log was not read, the name executed is not known:
`username` is emptied, so that no server is asked about a name that may
not be the one executed, and the row is not judged on its access.
`server` and `project_id` stay the register's then. The reading of the
0.25.0, which the round keeps for the rule of the pair, is not used here
(decided on 2026-11-12): it names the wrong person in the cases the
reconstruction does not verify, and the report would ask a server about
them.

Applied rows, and every row outside `conta` and `ferma` of
[`report_scope()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_scope.md),
keep the register's values.
