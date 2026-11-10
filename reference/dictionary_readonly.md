# The fields a dictionary makes read-only on every row

The fields whose annotation carries `@READONLY` outside any `@IF(...)`.
A tag inside an `@IF` holds only on the rows its condition picks, and
the field can be written on the others: `server` and `project_id` are
locked that way once a row carries a seal (decided on 2026-11-09), and
they are intent fields, not fields of the channel. Counted with the
rest, they would read as read-only fields the live register lost, on a
register that has not imported the tag yet, and the round would stop.

## Usage

``` r
dictionary_readonly(dictionary)
```

## Arguments

- dictionary:

  A data dictionary, with `Variable / Field Name` and
  `Field Annotation`.

## Value

The names of those fields, in dictionary order.

## Details

The `@IF` is cut with its parentheses balanced, skipping what stands
inside quotes, since a condition can hold a parenthesis of its own; an
`@IF` nested in another goes with it. A tag after the `@IF` still
counts.
