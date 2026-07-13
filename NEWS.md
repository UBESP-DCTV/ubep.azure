# ubep.azure 0.3.0

* Fixed `logImportUsers.csv`: each row now records one user with an intact
  UPN-to-person mapping (previously every row repeated the whole batch and the
  column count varied with batch size).
* `build_ps1_from_xlsx()` now stops on rows with a missing `Nome`/`Cognome`
  instead of silently emitting a `NA.NA@...` account.
* Input is now restricted to Excel files; the (broken) CSV input path was
  removed.
* The generation no longer leaves a dangling `sink()` if an error occurs
  mid-run (which used to mute the R session).
* The initial password is no longer the hardcoded `P@ssw0rd`: a strong random
  password is generated per run by default, and can be set via the new `pwd`
  argument. Accounts are still forced to change it at first sign-in.
* Added tests covering the generated Microsoft Graph scripts (previously the
  `New-MgUser`/`Remove-MgUser` output had no automated coverage) and removed
  real-looking student e-mail addresses from the test fixtures.

# ubep.azure 0.2.1

* Fix verbosity of `read_cvs`
* Considered `ubep.unipd.it` the default domain, pass it to functions explicitly is no more necessary.
* Removed `here()` from project detecting path systems; now the files are
  created in the correct folder depending on their location and not on the r script project running the procedures.

# ubep.azure 0.2.0

* exported `build_ps1_from_xlsx` that is currently the main interface function to the package utils.
* Setup pkgdown for documentation website

# ubep.azure 0.1.0

* Refactoring functions into dedicated files and coherent naming
* Added (copy-pasted) all the old functions and tests into the project.
* Added standard basic support for package development.
