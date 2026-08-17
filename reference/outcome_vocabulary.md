# The closed vocabulary of outcomes

Five words, and the register's `outcome` field offers exactly these.
Kept in one place because two readers already need it — the payload
builder, which refuses anything else, and the run record, which carries
one counter per word. A second copy would let the two drift, and the
drift would show as a counter that silently stops counting a word
somebody added.

## Usage

``` r
outcome_vocabulary()
```

## Value

A character vector of the five outcomes.
