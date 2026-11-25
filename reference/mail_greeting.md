# Greet a person by first name, or without one

A greeting that prints the field as it comes writes "Ciao NA," for a
missing name and breaks the line when the name carries a newline.
Whitespace inside the name collapses to one space, and a name that is
missing, empty or only whitespace leaves the bare greeting, without a
stray space before the comma.

## Usage

``` r
mail_greeting(word, first_name)
```

## Arguments

- word:

  The greeting word, in the language of the message.

- first_name:

  The person's first name, from the row.

## Value

One string: the word, the cleaned name when there is one, a comma.
