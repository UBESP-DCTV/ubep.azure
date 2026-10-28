# Read the accounts of the people of each server

Asks every server in `asks` for the names it was given and says, for
each, whether it was read. A server that was not read is not an error:
the report goes on and the pairs of that server fall back on what the
directory says. The reason is a code, one of
`TRASPORTO_ISTANZA_SENZA_MODULO` (the server has no host),
`TRASPORTO_SEGRETO_NON_LEGGIBILE` (no secret, or an `NA`), the first
code of the failed
[`module_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_accounts.md),
or `INTERNO` when the answer is not a reading (see
[`report_accounts_frame()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_accounts_frame.md)).

## Usage

``` r
report_server_reads(asks, hosts, secrets)
```

## Arguments

- asks:

  Named list: server name to the user names to ask it.

- hosts:

  Named character vector: server name to host.

- secrets:

  Named character vector: server name to secret.

## Value

A named list with one element per server of `asks`:
`list(letto = TRUE, conti = <frame>)` or
`list(letto = FALSE, motivo = <code>)`.

## Details

Blank and missing names are not asked:
[`module_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_accounts.md)
lets them pass. A call that raises an error is a server not read, with
reason `INTERNO`.
