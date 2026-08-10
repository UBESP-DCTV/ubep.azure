# Build the record a run leaves behind

The channel keeps no copy of the state it reconciles, so a run leaves no
other trace: this record is it. That is not in tension with "no local
store of the state" — what that forbids is a copy of what can be
re-read, and a run log is the only evidence of an event that leaves
none.

## Usage

``` r
run_record(observations, at, non_osservate = character())
```

## Arguments

- observations:

  Rows from
  [`observe_instance()`](https://ubesp-dctv.github.io/ubep.azure/reference/observe_instance.md),
  bound together.

- at:

  When the run finished, as `YYYY-MM-DD HH:MM`. Passed in rather than
  read here so the record stays a pure function of what was observed.

- non_osservate:

  Names of instances the run did not even attempt — those without the
  module. Passed in so the record can state its own scope instead of
  leaving the reader to assume it covered everything.

## Value

A named list, ready to be serialized as one JSON object.

## Details

It carries `letture_riuscite` because the alarm on absence fires on the
lack of a record with at least one successful read. Were it to say only
"the process started", a job that started, failed against every instance
and exited would satisfy the alarm — a detector the fault can meet,
which is the shape of defect this project has already found twice.

`flotta_a_una_major` is the condition the two clauses on retiring
compatibility branches rest on, and it is deliberately conservative: it
is true only when the run covered every instance. A flag computed over
whichever instances happened to answer would report a singleton while
instances on an older major sat unread, and would retire a branch still
in use. A flag that authorizes a destructive decision must be false when
it cannot know.

Found by running rather than by reading: with the module on three
instances of fourteen, a field named for the fleet reported the fleet
was a singleton while two instances on major 11 were never contacted.
