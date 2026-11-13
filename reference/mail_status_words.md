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
mail_status_words(request_status, applied_as = "", at = "")
```

## Arguments

- request_status:

  The row's `request_status`.

- applied_as:

  The row's read-back, `"absent"` when the pair is not on the instance.
  Empty when the caller does not say.

- at:

  The time of the round, UTC, `"%Y-%m-%d %H:%M"`: the day against which
  the stored expiration of `applied_as` is read. Empty or not a date,
  and the fourth fact is not told.

## Value

A character vector named `it` and `en`.

## Details

A third fact has the same word: an active row whose last day has passed,
carried out and unchanged, and whose person somebody removed from the
project. The round writes nothing and reads the pair back as absent,
which is the row's own wish, and the message says that instead of a
grant.

A fourth fact has the same word again: an active row whose last day has
passed on the day of the round and whose person is on the project all
the same, because somebody put them back by hand, with the day the row
says or with another that the round brought back to it. REDCap stores
the day after the last, and on it does not let the person in. Whether
the channel wrote is no part of the sentence, which is the same for
both.
