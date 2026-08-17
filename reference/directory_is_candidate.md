# The rows the resolution is allowed to match against

Guests are excluded, and by invariant rather than by measurement:
whoever is on the REDCap of UBEP has a `ubep.unipd.it` account, or is
given one. The tenant holds 760 guests and they carry their external
address in `otherMails`, which is one of the two fields searched, so a
guest matching alongside a member would produce an `ambiguous` that is
not an ambiguity.

## Usage

``` r
directory_is_candidate(directory)
```

## Arguments

- directory:

  A directory frame as
  [`directory_users()`](https://ubesp-dctv.github.io/ubep.azure/reference/directory_users.md)
  returns.

## Value

A logical vector, one per row.

## Details

A row whose `userType` could not be read stays a candidate, which is not
the same as trusting it: it is kept so that it cannot silently become
"nobody matched", and
[`resolve_identity()`](https://ubesp-dctv.github.io/ubep.azure/reference/resolve_identity.md)
then refuses to grant on it. Dropping it here would turn an unreadable
field into a second account for a person who already has one, and that
is the failure this design fears most.
