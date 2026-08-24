# Compose the message that tells whoever filed a row how it went

Both languages in one message, Italian above and English below: the
channel does not know which one the recipient reads – `requested_by` is
a UPN and says nothing about it – so sending two would double the post
without knowing which of them could be dropped.

## Usage

``` r
mail_outcome_message(row)
```

## Arguments

- row:

  One register row as a list, carrying the dictionary's fields.

## Value

A list with `subject` and `body`, both length one.
