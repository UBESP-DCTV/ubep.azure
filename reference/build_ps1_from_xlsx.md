# Build ps1 files

From a correctly formatted Excel file, generate the Microsoft Graph
PowerShell (`New-MgUser`/`Remove-MgUser`) scripts to create and delete
the users in bulk on Microsoft Entra ID, plus the CSV to add them to a
group from the Azure portal.

## Usage

``` r
build_ps1_from_xlsx(file = file.choose(), pwd)
```

## Arguments

- file:

  (chr, default interactive selection windows) file path to the Excel
  file reporting the users to create (see details).

- pwd:

  (chr, optional) initial password shared by every account in the batch.
  When omitted a strong random password is generated for the run. It is
  embedded in the generated `.ps1`; users are always forced to change it
  at first sign-in.

## Details

The Excel file must have 9 column, named exactly (case sensitive) as:
`Nome, Cognome, Email, Prj1_ID, Prj1_role, Prj1_DAG, Prj2_ID, Prj2_role, Prj2_DAG`.

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
