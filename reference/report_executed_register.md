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
  answers.

- approvers:

  The IT accounts whose approval counts on any row, or `NULL` when the
  caller does not know them.

- channel_account:

  The REDCap usernames that hold the register's token, or `NULL` when
  they are not configured.

## Value

The register, with `server`, `project_id` and `username` the ones
executed, and four columns more: `username_registro`, the name the
register holds; `nome_eseguito`, `registro` or `log`, where the name
executed was read, `""` when it is not known; `nome_motivo`, why not:
`log` or `approvatori`, `""` when it is known; `revoca_eseguita`, `TRUE`
on a revoked row whose state executed,
[`log_executed_values()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executed_values.md)
on `request_status`, is `revoked`: carried out, then touched, so that
[`report_scope()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_scope.md)
leaves it out of `ferma`. A log that does not say leaves it `FALSE`.

## Details

- **the seal did not move**: the register is what was executed. The seal
  is the channel's last one in the row's log,
  [`log_channel_seal()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_channel_seal.md),
  when the channel's account is configured, as the round reads it;
  otherwise the field;

- **the seal moved**: the values the round last carried out, read from
  the log by
  [`log_executed_values()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executed_values.md),
  which needs the IT approvers to know which writes an approval covered.
  A seal moves on a row `held` on its role, and on a row the identity
  door rewrote after an account changed on Entra, which stops on
  `TRASPORTO_IDENTITA_CAMBIATA` with the new name in the register and
  the old one on the instance.

Where the log does not say, or the caller gave no approvers (`NULL`, a
runner older than this function: without them a change IT approved would
be passed over and the name read would be the one before it), the name
executed is not known: `username` is emptied, so that no server is asked
about a name that may not be the one executed, and the row is not judged
on its access. `server` and `project_id` stay the register's then.

Applied rows, and every row outside `conta` and `ferma` of
[`report_scope()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_scope.md),
keep the register's values.
