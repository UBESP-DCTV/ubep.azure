# Did this instance answer the question the scope gate asks

An instance whose module is too old to report the permission answers
normally and carries no permission anywhere. That is an absence of the
answer, not a verdict, and the gate interrogates answers and never
absences: refusing those rows as out of scope would tell a referent "you
are not authorized" when the truth is "our module is behind", which is a
sentence they can do nothing with.

## Usage

``` r
round_scope_readable(state)
```

## Arguments

- state:

  What
  [`module_state()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_state.md)
  returned.

## Value

`TRUE` when the reply can be used to answer the scope question.

## Details

Zero rows is a different fact and must not be folded into this one. The
instance answered, and what it said is "there is nothing there" — a
requester with no rights row is out of scope, which belongs to whoever
filed the request.
