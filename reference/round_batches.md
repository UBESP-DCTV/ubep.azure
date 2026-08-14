# Split what has to be written into batches of one project each

`api.php` refuses a write that touches more than one `project_id`, and
refuses it outright before touching anything: `PROJECT_ID` is an
immutable per-process `define()`, and it is what makes every write land
in its own project's log. A job that grouped by instance would take that
refusal on its first mixed batch, and the diagnosis would start from the
wrong place.

## Usage

``` r
round_batches(entries)
```

## Arguments

- entries:

  Validated requests, each carrying `record_id`, `server` and
  `project_id`.

## Value

A list of batches, each
`list(server, project_id, record_ids, requests)`, where `requests` carry
only the five fields the module reads.

## Details

Simulations are batched the same way, although the module lets them span
projects. One rule instead of two, and a simulation that exercises
exactly the batching the write will use: a rehearsal shaped differently
from the performance cannot warn about it.
