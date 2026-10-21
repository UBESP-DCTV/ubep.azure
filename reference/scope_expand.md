# Put one line in the register for each person the gate must judge

The gate asks of a requester "could you have done this by hand". What
the channel executes can have been written by more than one person, and
the rule is the same for all of them: **whoever wrote what is executed
must be able to do it by hand.** The rights of whoever approves are not
checked, because approving is not writing: it adds no power to the
change.

## Usage

``` r
scope_expand(register, subjects)
```

## Arguments

- register:

  The register as a data frame, carrying at least `record_id`, `server`
  and `project_id`.

- subjects:

  A list as long as the rows of `register`, each element the usernames
  to judge for that row.

## Value

`register` with one line per row and subject, in the order of the rows
and then of the subjects, and `requested_by` equal to the subject.

## Details

This turns a register and the people to judge for each of its rows into
a register
[`scope_errors()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_errors.md)
can read: one line per row and subject, with `requested_by` set to the
subject. A row with nobody to judge stays once, with an empty
`requested_by`, so that
[`scope_errors()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_errors.md)
refuses it as not attributed and it does not slip through for lack of a
name.
