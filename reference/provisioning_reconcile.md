# Run one round of the channel

The only function that holds the register and the instances at the same
time, and the only place a write can start from. Everything it decides
is decided by the pure layer; what lives here is the order of the
questions, and the order is the design:

## Usage

``` r
provisioning_reconcile(
  register_url,
  register_token,
  hosts,
  secrets,
  instances = NULL,
  dry_run = TRUE,
  at = format(Sys.time(), "%Y-%m-%d %H:%M", tz = "UTC")
)
```

## Arguments

- register_url, register_token:

  The register's host and API token.

- hosts:

  Named character vector, instance name to hostname, optionally carrying
  the path REDCap is mounted under. The register names instances
  (`edc10`); only this map knows where they are.

- secrets:

  Named character vector, instance name to shared secret. An instance
  whose secret could not be read is named here with `NA` rather than
  left out, so the two failures stay distinguishable.

- instances:

  The fleet, in the order the register's `server` field carries it, for
  the dictionary comparison. `NULL` compares the other fields and
  declares the substitution.

- dry_run:

  Whether to simulate. Defaults to `TRUE`.

- at:

  When the round ran, as `YYYY-MM-DD HH:MM`.

## Value

A list with `at`, `fermato`, `schema`, `istanze`, `esiti`, `scritte` and
`errori`.

## Details

1.  compare the register's dictionary and stop if the drift changes what
    a round reads;

2.  read the register;

3.  turn it into the desired state, keeping the form errors;

4.  per instance, read the state **once** for the grantees and the
    requesters together;

5.  ask the scope gate about the instances that answered, and only
    those;

6.  diff against the real rows somebody asked about;

7.  batch by `(server, project_id)`, never across two projects;

8.  read back what a real write did, before calling it applied;

9.  write back the outcome, and only what changed.

Idempotent by construction: a round interrupted between applying and
writing the outcome leaves the row as still to do, and the next round
applies it again. That is harmless because the diff finds it already
conforming and classifies it `noop` — and it is the reason the job can
be killed at any moment without repair.

A `project_id` the register accepted but that is not a number is named
here with `DATO_PROGETTO_INESISTENTE` right after the pure layer runs,
and before the scope gate ever sees the row. The row may not be a pair
yet — `username` stays blank until the identity is resolved, which is
the ordinary state in this version — so
[`register_to_desired()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_to_desired.md)
never validated it, while
[`scope_pairs()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_pairs.md)
admits it on `requested_by` alone. Left to the gate it would come back
as a scope refusal, "you may not ask for that project", when the truth
is "that is not a project number" — a data error the referent can act
on, not a permission they are sent to go ask for when they already hold
it.
