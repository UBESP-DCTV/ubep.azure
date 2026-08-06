# The assertions the conformance run applies

Every field the contract can write is asserted, not a sample: a field
the cases do not assert is a field the gate is blind to. The
combinations are chosen on failures already observed rather than
invented.

## Usage

``` r
conformance_cases()
```

## Value

A list of cases, each with `name`, `assert` and `why`.

## Details

Two cases clear a field instead of setting it: one clears the DAG, one
clears the expiration. The writer asserts an absent value as an empty
string, never by omitting it, and what the REDCap `date` column turns an
empty string into on write is a fact of the instance under test, not
something this code may assume — so clearing has to be exercised as
deliberately as setting.

What the run does not cover, stated so a green result is read for what
it is: every case reads back only the one pair it just wrote. A major
that changed which rows `state` enumerates, or the field-name map used
on read, would leave all of these green. The run answers "writing one
pair and reading it back still means what it meant", not "the channel is
unharmed" — a distinction that matters at the first ceiling advance,
which is the first time this runs against a major it has never seen.
