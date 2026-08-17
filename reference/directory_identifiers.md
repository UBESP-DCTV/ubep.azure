# The addresses an account carries as its own identifiers

Wider than the matching set by one field, `mail`, and the distinction is
deliberate: the criterion is the contact address and the design names
the two carriers it lives in, while this answers a different question —
does this account already carry the thing the referent declared?

## Usage

``` r
directory_identifiers(account)
```

## Arguments

- account:

  One row of a directory frame.

## Value

A normalized character vector, empties dropped.

## Details

`officeLocation` is in here as the legacy carrier and not as an
identifier of its own. It has to be: on the accounts the historical flow
created `mail` is `null` and `otherMails` is empty, so without it a
referent who declared the right person's alias would be told the row
contradicts itself. It retires with the fallback of decision 9.
