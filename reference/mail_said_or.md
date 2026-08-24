# Say a value, or say why it is not there

REDCap has no conditional piping, so the alert bodies gave every field a
line of its own and explained in prose that an empty one meant
something. Composing here, the empty case can change the sentence
instead, which is a large part of why the text moved out of REDCap at
all.

## Usage

``` r
mail_said_or(value, absent)
```

## Arguments

- value:

  The field as the register carries it.

- absent:

  What to say when it carries nothing.

## Value

One string, never empty.
