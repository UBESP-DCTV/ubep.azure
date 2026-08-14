# What the instance showed for one written pair

The one place that decides what a write's `applied_as` is allowed to
come from. A `NULL` re-read means there was nothing to read back — a
simulation, where the module's own `after` is the whole story, because
nothing happened to look at. A re-read that ran carries the only thing
that can settle whether the write landed: what the instance shows now,
not what the write claimed a moment ago.

## Usage

``` r
round_observed(reread, entry)
```

## Arguments

- reread:

  The `results` of the post-write `state` call, or `NULL` when this was
  a simulation and there is nothing to read back.

- entry:

  One entry of a write response's `results`, carrying `username`,
  `project_id` and the response's own `after`.

## Value

The matching row from `reread`, the entry's own `after` when `reread` is
`NULL`, or `NULL` when a real re-read ran and did not find the pair.
