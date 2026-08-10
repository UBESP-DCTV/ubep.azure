# Read the request register's data dictionary

The dictionary is the schema, and it lives as a file rather than as R
code because REDCap imports it as it is: one artifact, two consumers.

## Usage

``` r
register_dictionary(instances = NULL)
```

## Arguments

- instances:

  Character vector of instance names, or `NULL` for the template. A
  zero-length vector is refused rather than treated as `NULL`: `NULL`
  means "I am not passing it", while `character(0)` asserts that the
  fleet is empty, and the two must not reach the same result by opposite
  routes. Empty or missing names are refused for the same reason — they
  would become the choice `", "` inside a dictionary that looks sound.

## Value

A data frame with the eighteen columns of a REDCap data dictionary.

## Details

Sixteen of its seventeen fields are exactly that. The seventeenth is
not: the choices of `server` are the fleet, a piece of operating data
that changes when the machines change rather than when the contract
does. Kept in the file, it coupled a release of this package to every
movement of the fleet, and published the list in a public repository. So
the packaged file is a **template** with that one cell empty, and the
caller supplies the list.

The template is deliberately not importable: REDCap refuses a `radio`
with no choices, so the template cannot be imported by mistake in place
of the real dictionary. A recognizable placeholder would have been
importable, and would have produced a project carrying one invented
choice — a file that looks like it worked costs more than one that
refuses to.
