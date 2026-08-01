# Compose the user principal name used as REDCap username

The UPN is not a mailbox: it is the identity the person authenticates
with, and it doubles as the REDCap username because the instances are
configured with
`oauth2_azure_ad_username_attribute = userPrincipalName`. The address
someone can actually be reached at travels separately, as
`contact_email`.

## Usage

``` r
compose_upn(first_name, last_name, domain = "ubep.unipd.it")
```

## Arguments

- first_name, last_name:

  Person's names, in any casing or accenting.

- domain:

  Tenant domain.

## Value

A single string.

## Details

Normalization is delegated to `clean_string()`, which already
lowercases, squishes, turns spaces into dots and transliterates accents
to ASCII.
