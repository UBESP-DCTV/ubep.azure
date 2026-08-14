# Refuse the rows whose requester does not manage the project they ask about

The channel applies a request without anyone reading it, so what bounds
a request is not review but the requester's own rights. The rule this
enforces is worth stating as one sentence, because it is the reason the
gate is this one and not a table somebody keeps: **the channel must not
let anyone do something they could not already do by hand.** Holding
REDCap's user_rights permission on a project is exactly "could have
granted this access themselves", so the channel automates a power
instead of adding one.

## Usage

``` r
scope_errors(register, rights)
```

## Arguments

- register:

  The register as a data frame, carrying at least `record_id`, `server`,
  `project_id` and `requested_by`.

- rights:

  The rights read from the instances, as a data frame with `server`,
  `project_id`, `username` and `user_rights`. The caller assembles it
  from each instance's answer, because a `state` reply names its server
  once at the top and not on every row.

## Value

A named list, one entry per refused row, named by `record_id` and
holding `"DATO_AMBITO_NON_AUTORIZZATO"`. Empty when every row is in
scope. The shape matches `register_to_desired()$errors` so the two
merge.

## Details

Four ways a row is refused, and they are one rule and not four special
cases — every one of them is "the permission was not read as granting":

- the row carries no requester, so nothing can be attributed to anybody;

- the requester holds no rights at all on that project, so there is no
  row;

- the permission was read and does not grant;

- the permission could not be read, which is the case that decides the
  direction of the whole function. An instance answered by a module too
  old to report the permission, a role deleted underneath a row, a
  column that read as empty: none of these is a permission, and treating
  them as one would widen access exactly when the channel has stopped
  being able to see.
