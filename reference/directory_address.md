# Read an address out of a field a person typed

`officeLocation` is free text, and the historical flow wrote it as the
spreadsheet had it: an address with a comma or a semicolon after it, a
full stop, angle brackets, parentheses, quotes, a `mailto:` in front.
Handed to the mail service as it is, such a value is refused, and with
it every other recipient of the same message. So what wraps the address
is taken off: spaces, no-break spaces included, an opening bracket or
parenthesis and `mailto:` on the left; spaces, a closing bracket or
parenthesis and a trailing `,`, `;` or `.` on the right; quotes only as
a pair around the whole value; as often as they nest. A full stop, comma
or semicolon on the left stays: taken off, `.mario@example.org` would
become `mario@example.org`, an address that may be somebody else's,
where the value as written reaches nobody. So does a quote without its
partner, which is a character of the local part: `'mario'@example.org`
is what was written, and `mario'@example.org` would be another address.
What is left is folded to lower case and has to have the strict form of
an address: a local part of dot-separated atoms, one `@`, a domain of
labels that start and end with a letter or a digit, the last one
alphabetic, nothing else. A value that does not is not an address, which
is not the same as a wrong one: it is a room, a note, two addresses in
one field.

## Usage

``` r
directory_address(values)
```

## Arguments

- values:

  A character vector.

## Value

A character vector of the same length: the address, cleaned and in lower
case, or `""`.
