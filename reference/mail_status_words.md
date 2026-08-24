# Say what `applied` did, which is not the same thing twice

`applied` is one word for two opposite facts and the module has no
second word: it means "what the row asked for was done", and what it
asked for is in `request_status`. The alert body had to print the
vocabulary and ask the reader to apply it. The mail of record 9 in the
field test is what this exists to prevent – it said `applied` on a
revocation, naming nobody, and whoever read it understood that an access
had been granted.

## Usage

``` r
mail_status_words(request_status)
```

## Arguments

- request_status:

  The row's `request_status`.

## Value

A character vector named `it` and `en`.
