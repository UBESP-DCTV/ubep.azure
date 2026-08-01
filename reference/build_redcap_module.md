# Build the distributable REDCap module archive

Packs `inst/redcap-module/` into the archive REDCap expects, naming the
top level directory `ubep_provisioning_v<version>`. REDCap derives both
the module prefix and its version from that directory name, so the name
is part of the contract rather than a convention.

## Usage

``` r
build_redcap_module(out_dir = ".")
```

## Arguments

- out_dir:

  Directory the archive is written to.

## Value

The path of the archive, invisibly.

## Details

The module and its R client share a single version number, the one in
`DESCRIPTION`: the endpoint contract has two ends, and keeping them in
one repository with one version is what stops their compatibility from
becoming a matrix to remember. The `VERSION` file is rewritten from
`DESCRIPTION` while staging rather than copied, so the two cannot drift
unnoticed.

The `tests/` directory is left out. It is the module's own test suite,
run in CI and never needed on a server.
