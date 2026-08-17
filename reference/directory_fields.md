# The directory fields the sweep asks for, and the columns it hands back

One list, read twice: it builds the `$select` and it names the columns
of the frame. Two copies would be a map between two sets of names, which
is where this package keeps finding its worst bugs — and here the drift
would be silent in the worst direction, because a field asked for and
not read looks exactly like an account that does not carry it.

## Usage

``` r
directory_fields()
```

## Value

A character vector of Graph field names, in the order the frame's
columns take.

## Details

`User.ReadBasic.All` would have been the narrower permission and is not
enough for this list: it carries neither `officeLocation`, `otherMails`,
`createdDateTime` nor `userType`, which are the four the resolution
decides on. The select list is therefore also the reason `User.Read.All`
is the permission asked for.

`givenName` and `surname` are here because the resolution refuses a
match whose name diverges from the one the request declares, and it
cannot refuse on a field the sweep never asked for. They were missing
from the plan's select, which was written before that confirmation was
traced through; the historical flow populates both, through `-GivenName`
and `-Surname` in `ps1_creators.R`.
