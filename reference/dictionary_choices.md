# Split a REDCap choice string into codes and labels

Choices travel as `"code, label | code, label"`, and only the **first**
comma separates the two: a label may carry commas of its own.

## Usage

``` r
dictionary_choices(text)
```

## Arguments

- text:

  One cell of the dictionary's choices column.

## Value

A data frame with `code` and `label`.
