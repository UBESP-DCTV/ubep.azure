# Build ps1 files

From a correctly formatted file, `ps1` files for create the user and to
assign them to a group in bulk operation o AAD directly.

## Usage

``` r
build_ps1_from_xlsx(file = file.choose())
```

## Arguments

- file:

  (chr, default interactive selection windows) file path to the Excel
  file reporting the users to create (see details).

## Details

The Excel file must have 9 column, named exactly (case sensitive) as:
`Nome, Cognome, Email, Prj1_ID, Prj1_role, Prj1_DAG, Prj1_ID, Prj1_role, Prj1_DAG`.

Moreover:

- no more than 2 projects can be added at the creation time using this
  script.

- At least information (all the three!) for one project must be provided
  for EDCxx servers

- For students on MSTxx servers no information should be provided about
  projects (i.e. the first three column should contain data only!)

- For template including a projects all the role and DAG for each of
  them must be provided!

## Examples

``` r
if (FALSE) { # \dontrun{
  build_ps1_from_xlsx()
} # }
```
