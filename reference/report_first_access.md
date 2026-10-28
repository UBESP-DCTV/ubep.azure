# Whether a person has signed in to Entra, from the two dates of their key

Entra says it with the permission the round already holds, and the
report uses it where the server cannot say it better: for the pairs of a
server that was not read, and for the deadline of a key that is still
the one of the creation. `lastPasswordChangeDateTime` is, in the words
of Learn, "the time when this Microsoft Entra user last changed their
password or when their password was created", and the round creates
every account with `forceChangePasswordNextSignIn`: an account whose key
is as old as the account itself is an account nobody has entered.

## Usage

``` r
report_first_access(directory, upn, tolerance = report_tolerance())
```

## Arguments

- directory:

  A directory frame, as
  [`directory_users()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_users.md)
  returns it.

- upn:

  The person's user principal name.

- tolerance:

  Seconds,
  [`report_tolerance()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_tolerance.md)
  unless a test says otherwise.

## Value

One of `mai_entrata` and `entrata`, the two a referent is told about; or
one of the four that go to IT: `disabilitato`, `non_trovato`,
`senza_creazione` (no `createdDateTime`, which Learn says happens to
some accounts created before June 2018) and `non_giudicabile`.

## Details

What it cannot see, said where it is decided. A key reset by IT moves
the date without anybody signing in, and the person drops out of the
verdict. An account that existed long before the request has dates that
diverge, and the person never shows, even if they never opened the
instance asked for: the signal says "has used the UBEP account", not
"has used REDCap". That is why a server that was read decides in its
place
([`report_server_access()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_server_access.md)),
and
[`report_assemble()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_assemble.md)
asks Entra only when the server did not answer.
