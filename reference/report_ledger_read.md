# Read a month's ledger of sent reports

The ledger is the trace of an event that otherwise leaves none: for each
report of the month, when it left and which people it named as having no
first sign-in. It is what keeps a report from leaving twice when the
daily run tries again, and what the next months read to say a person was
reported before. It is not a copy of the state the channel re-reads,
which decision 4 of the channel forbids: nothing of the register or of
Entra is kept in it.

## Usage

``` r
report_ledger_read(dir, month, collaudo = FALSE)
```

## Arguments

- dir:

  The job's state directory.

- month:

  The month covered, `"AAAA-MM"`.

- collaudo:

  Whether to read a redirected run's ledger.

## Value

A list with `ok`, `errors` and `invii`, one list per report sent:
`destinatario`, `at`, and `senza_primo_accesso` and `senza_accessi`, the
people it named, each a data frame of `upn` and `server`; and
`collaudo`, so that whoever adds to it writes it back where it was read.

## Details

A file that does not read is not read as empty. Read as empty, it would
send every report of the month a second time; read as an error, the run
sends nothing and says why.
