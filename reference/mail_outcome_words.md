# Say an outcome in both languages

The vocabulary of outcomes is closed and counts five words. This
function names all five, and a test walks
[`outcome_vocabulary()`](https://ubesp-dctv.github.io/ubep.azure/reference/outcome_vocabulary.md)
to say so: adding a sixth outcome without a translation stops the suite
instead of shipping a message with an English gap in the middle of an
Italian sentence.

## Usage

``` r
mail_outcome_words(outcome)
```

## Arguments

- outcome:

  One word of
  [`outcome_vocabulary()`](https://ubesp-dctv.github.io/ubep.azure/reference/outcome_vocabulary.md).

## Value

A character vector named `it` and `en`.
