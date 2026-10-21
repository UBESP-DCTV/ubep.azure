# Build ps1 files (defunct)

Calling this function always fails. It used to generate, from an Excel
file of users, the Microsoft Graph PowerShell scripts
(`New-MgUser`/`Remove-MgUser`) that created and deleted accounts in bulk
on Microsoft Entra ID, carrying each user's project authorization in the
`jobTitle` field of the account.

## Usage

``` r
build_ps1_from_xlsx(...)
```

## Arguments

- ...:

  Ignored.

## Value

Never returns: it always signals an error.

## Details

It is retired because every instance is now linked to the authorization
channel, and the `jobTitle` field is no longer a channel: a script that
wrote it would put a second transport back on the same authorization.
Accounts and rights are requested through the register, and the channel
carries them out.

The function stays exported so that a call from an old script stops with
this explanation, instead of failing on a missing function.

## Examples

``` r
try(build_ps1_from_xlsx())
#> Error in build_ps1_from_xlsx() : 
#>   `build_ps1_from_xlsx()` is defunct. Every instance is now linked to the authorization channel, and the `jobTitle` field is no longer a channel: request accounts and rights through the register of requests.
```
