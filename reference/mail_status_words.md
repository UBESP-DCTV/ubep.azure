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
mail_status_words(request_status, applied_as = "")
```

## Arguments

- request_status:

  The row's `request_status`.

- applied_as:

  The row's read-back, `"absent"` when the pair is not on the instance.
  Empty when the caller does not say.

## Value

A character vector named `it` and `en`.

## Details

A third fact has the same word: an active row whose last day has passed,
carried out and unchanged, and whose person somebody removed from the
project. The round writes nothing and reads the pair back as absent,
which is the row's own wish, and the message says that instead of a
grant.
