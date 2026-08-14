# Turn a REDCap record export into a frame of character columns

Every column stays character, `project_id` included. The pure layer
already reads it as text and compares it as text, and a type guessed
here would be a second opinion about the same value — which is the shape
of bug this package keeps finding: two paths to one answer that disagree
in silence.

## Usage

``` r
records_frame(records)
```

## Arguments

- records:

  The parsed export, a list of one list per record.

## Value

A data frame with one row per record.
