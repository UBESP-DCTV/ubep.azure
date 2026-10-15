# Whether each of these authors may approve a row

The creator, or one of the IT accounts. The creator is compared as
REDCap logs it, which is the same source on both sides. The IT list is
typed by hand on the machine, so it is compared without regard to case:
a capital letter must not void an approval by IT in silence. A blank
name approves nothing, whatever the list holds.

## Usage

``` r
log_approver(authors, creator, approvers = character())
```

## Arguments

- authors:

  Usernames, as the log carries them.

- creator:

  Who created the row.

- approvers:

  The IT accounts whose approval counts on any row.

## Value

A logical vector, one answer per author.
