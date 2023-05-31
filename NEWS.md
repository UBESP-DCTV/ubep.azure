# ubep.azure (development version)

* Considered `ubep.unipd.it` the default domain, pass it to functions explicitely is no more necessary.
* Removed `here()` from project detecting path systems; now the files are
  created in the correct folder depending on their location and not on the r script project running the procedures.

# ubep.azure 0.2.0

* exported `build_ps1_from_xlsx` that is currently the main interface function to the package utils.
* Setup pkgdown for documentation website

# ubep.azure 0.1.0

* Refactoring functions into dedicated files and coherent naming
* Added (copy-pasted) all the old functions and tests into the project.
* Added standard basic support for package development.
