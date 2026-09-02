# The closed vocabulary of outcomes

Six words, and the register's `outcome` field offers exactly these. Kept
in one place because two readers already need it — the payload builder,
which refuses anything else, and the run record, which carries one
counter per word. A second copy would let the two drift, and the drift
would show as a counter that silently stops counting a word somebody
added.

## Usage

``` r
outcome_vocabulary()
```

## Value

A character vector of the six outcomes.

## Details

`held` is the one that is neither a state nor a fault. The other five
split in two: three say where the row is (`pending`, `applied`,
`simulated`) and two say what went wrong and therefore who hears about
it — `data_error` to whoever filed the row, `transport_error` to us. A
row modified after it was applied is a third thing: nothing went wrong,
and the round stopped on purpose until somebody approves the change.
Filing it under either `_error` would send an alarm to a person with
nothing to fix, and `pending` would say nobody has looked at it yet.
