# Is this row's identity confirmed enough to act on

The gate the whole sub-project exists to install. The channel today
decides by looking at whether `username` is filled, and nothing has ever
put a verdict beside it — so a name somebody typed into a form is, as
things stand, sufficient to be granted rights under.

## Usage

``` r
identity_actionable(identity)
```

## Arguments

- identity:

  A register `identity` column, or one value.

## Value

A logical vector, one per value.

## Details

It admits two of the five words and refuses everything else, **including
the empty one**. That fourth case is the one that gets forgotten
precisely because it is the current one: `identity` is empty on every
row of the live register, so a gate that admitted it would admit
everything on the day it is switched on.

The round asks this of the verdict it has **just computed**, never of
the one it read from the register. Writing `identity` back is the
minutes of the verdict, not the input to the next step: a round that
gated on the stored value would be looking at something up to four hours
old, and on a sweep that failed it would be looking at a value nothing
has confirmed this round at all.
