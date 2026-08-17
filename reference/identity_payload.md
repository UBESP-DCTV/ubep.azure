# Build the body that writes a resolved identity back into the register

The twin of
[`outcome_payload()`](https://ubesp-dctv.github.io/ubep.azure/reference/outcome_payload.md),
for the second family of fields the round owns, and separate from it for
the reason
[`register_import()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_import.md)
states in its own refusal: the register's intent and what the round
decided must not travel together. The columns are fixed here rather than
assembled by the caller, so that a bug cannot rewrite what a person
asked for.

## Usage

``` r
identity_payload(record_id, username, identity)
```

## Arguments

- record_id:

  The register record to write to.

- username:

  The confirmed UPN, the proposal of a collision, or `""`.

- identity:

  One of the five verdicts, or `""` for a row the resolution stopped.
  The empty string is not a missing value here: it is the verdict "not
  resolved", and it has to be writable, or a row that stops would keep
  the username it earned when it still resolved — which is precisely the
  value that has become false.

## Value

A one-row data frame with exactly the identity columns.

## Details

**Neither field is ever written without the other.** A username written
without the verdict that authorizes it is exactly the state this
sub-project exists to close: the channel today decides by looking at
whether `username` is non-empty, and nothing has ever put a verdict
beside it.

The invariant this establishes is **conditional**, and it is the same
condition the gate checks: *a username is authoritative if and only if
`identity` is `existing` or `created`*.

It is conditional rather than absolute because a collision carries the
proposal of decision 11 — there is a determined value to show, and it is
the one a person has to act on, so keeping it out of the register would
leave it living only inside an e-mail. On `absent` and `ambiguous` there
is nothing to propose and the username is empty. What the referent had
typed does not survive the resolution either way; REDCap's Logging keeps
it.
