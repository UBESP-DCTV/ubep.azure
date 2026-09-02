# Say an outcome in both languages

The vocabulary of outcomes is closed and counts six words. This function
names all six, and a test walks
[`outcome_vocabulary()`](https://ubesp-dctv.github.io/ubep.azure/reference/outcome_vocabulary.md)
to say so: adding a seventh outcome without a translation stops the
suite instead of shipping a message with an English gap in the middle of
an Italian sentence. That gate fired when `held` was added, which is
what it is for.

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
