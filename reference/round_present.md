# Whether the instance holds a pair, whatever the capitals of the username

REDCap compares usernames without regard to case: its tables use a `_ci`
collation, so the module's state read asked about `Mario.Rossi@` answers
with the row it stores, `mario.rossi@`, and the person is on the project
under either.
[`round_actual()`](https://ubesp-dctv.github.io/ubep.azure/reference/round_actual.md)
matches the names as written, and asked "is the person still there" it
would answer no on a difference of capitals alone: a revocation settled
on that answer leaves the person on the project, with the row closed and
nobody told.

## Usage

``` r
round_present(results, request)
```

## Arguments

- results:

  The `results` of a `state` reply.

- request:

  One request, carrying `username` and `project_id`.

## Value

`TRUE` when `results` holds the pair in any case.
