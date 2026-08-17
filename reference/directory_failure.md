# Say what went wrong, and hand back no directory at all

A half-read sweep is not a small sweep. Every account on a page that did
not arrive is missing, and a missing account resolves to `absent`, which
is the verdict that opens the creation branch — so partial rows escaping
from here would turn a transport failure into duplicate people. `users`
is `NULL` on every failure for that reason, and it is what keeps "I
could not ask" distinguishable from "nobody is there".

## Usage

``` r
directory_failure(code, payload = NULL)
```

## Arguments

- code:

  The transport code, one of the `TRASPORTO_DIRECTORY_*` family.

- payload:

  Anything worth keeping for a diagnosis, or `NULL`.

## Value

A list with `ok`, `errors`, `payload` and `users`.
