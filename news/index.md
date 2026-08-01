# Changelog

## ubep.azure 0.4.0

- Added the REDCap authorization channel, read only in this release. A
  REDCap External Module lives in `inst/redcap-module/` and answers with
  the real state of project rights, the instance version, the version
  gate and a fingerprint of the REDCap surface it depends on. No write
  path exists yet.
- Added
  [`build_redcap_module()`](https://ubesp-dctv.github.io/ubep.azure/reference/build_redcap_module.md),
  the only exported addition: it packs the module into the archive
  REDCap expects. The module and this package share a single version
  number, so the two ends of the endpoint contract cannot drift.
- The client reads a response by its shape rather than by its status
  code. A module that is installed but disabled answers HTTP 200 with
  plain text, so inferring success from the status fails inside the JSON
  parser with an error that does not name the cause.
- The surface fingerprint downgrades an instance to untested when it
  does not match a measured one, even if the version says otherwise. An
  instance can be in the right major and have a changed surface, which
  no version comparison can see.
- Requires R (\>= 4.4).

## ubep.azure 0.3.0

- Fixed `logImportUsers.csv`: each row now records one user with an
  intact UPN-to-person mapping (previously every row repeated the whole
  batch and the column count varied with batch size).
- [`build_ps1_from_xlsx()`](https://ubesp-dctv.github.io/ubep.azure/reference/build_ps1_from_xlsx.md)
  now stops on rows with a missing `Nome`/`Cognome` instead of silently
  emitting a `NA.NA@...` account.
- Input is now restricted to Excel files; the (broken) CSV input path
  was removed.
- The generation no longer leaves a dangling
  [`sink()`](https://rdrr.io/r/base/sink.html) if an error occurs
  mid-run (which used to mute the R session).
- The initial password is no longer the hardcoded `P@ssw0rd`: a strong
  random password is generated per run by default, and can be set via
  the new `pwd` argument. Accounts are still forced to change it at
  first sign-in.
- Added tests covering the generated Microsoft Graph scripts (previously
  the `New-MgUser`/`Remove-MgUser` output had no automated coverage) and
  removed real-looking student e-mail addresses from the test fixtures.

## ubep.azure 0.2.1

- Fix verbosity of `read_cvs`
- Considered `ubep.unipd.it` the default domain, pass it to functions
  explicitly is no more necessary.
- Removed `here()` from project detecting path systems; now the files
  are created in the correct folder depending on their location and not
  on the r script project running the procedures.

## ubep.azure 0.2.0

- exported `build_ps1_from_xlsx` that is currently the main interface
  function to the package utils.
- Setup pkgdown for documentation website

## ubep.azure 0.1.0

- Refactoring functions into dedicated files and coherent naming
- Added (copy-pasted) all the old functions and tests into the project.
- Added standard basic support for package development.
