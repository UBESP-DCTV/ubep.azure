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
  graph_token,
  graph_url,
  instances = NULL,
  dry_run = TRUE,
  mailer = NULL,
  redirect_to = NULL,
  copy_to = NULL,
  reply_to = NULL,
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

- graph_token, graph_url:

  The Microsoft Graph access token and endpoint the sweep of step 3 is
  made with. Both are arguments and neither has a default: this
  repository is public, and an endpoint written in is an endpoint
  published. An empty endpoint is not an error here but a sweep that
  could not start, which is what the parameters sheet says a missing
  `UBEP_GRAPH` does — every row takes a transport error instead of a
  verdict, rather than the round dying with a message nobody reads.

- instances:

  The fleet, in the order the register's `server` field carries it, for
  the dictionary comparison. `NULL` compares the other fields and
  declares the substitution.

- dry_run:

  Whether to simulate. Defaults to `TRUE`.

- at:

  When the round ran, as `YYYY-MM-DD HH:MM`.

## Value

A list with `at`, `fermato`, `schema`, `istanze`, `esiti`,
`credenziali`, `scritte` and `errori`. `scritte` counts the outcomes
REDCap took and not the identities: they are two writes into two field
families, and one counter for both would be a number nobody could read
back into either. `credenziali` carries what the accounts created this
round were born with, and it is the only road those take.

## Details

1.  compare the register's dictionary and stop if the drift changes what
    a round reads;

2.  read the register;

3.  resolve **who each row is talking about**, against the tenant read
    whole, and write the verdict back;

4.  turn what the gate admits into the desired state, keeping the form
    errors;

5.  per instance, read the state **once** for the grantees and the
    requesters together;

6.  ask the scope gate about the instances that answered, and only
    those;

7.  diff against the real rows somebody asked about;

8.  batch by `(server, project_id)`, never across two projects;

9.  read back what a real write did, before calling it applied;

10. **create the accounts the gate allowed and the tenant does not
    hold**;

11. write back the outcome, and only what changed.

**The gate's subject is read from the log, not from the row.**
`requested_by` says who filed a request only because `@USERNAME` filled
it in, and an action tag governs the form REDCap draws rather than the
layer that writes: measured on 2026-09-02, an import writes that field
verbatim, so anyone holding the Data Import Tool could name a colleague
who manages the project and have the gate check that colleague's rights.
So between step 3 and step 4 the round asks REDCap who was authenticated
when each row was created and puts that name in the column the gate
reads. One call, `logtype = "record_add"` and no window: a record is
created once, so the answer holds one row per record that ever existed
rather than one per event, and it is asked only when a row is still
standing to be judged.

A row the log cannot name is **held and not refused**, which is the same
distinction step 6 already makes between a permission that does not
grant and one that could not be read. "I could not establish who filed
this" is our failure and not the referent's, and the code that carries
it is a `TRASPORTO_` one so the row comes back next round and the mail
comes to us.

**Step 3 is a step of this round and not a job of its own** — decision 2
of the design — and the reason is latency: resolving and acting have the
same cadence and the second consumes the first, so a resolver on a timer
of its own would make every new row wait one more cycle to be looked at.
It follows that the gate has no window at all: it asks after the verdict
it has just computed, never after the one the register carries, and
writing `identity` back is the minutes of the verdict rather than the
input to the next step.

**Step 10 is last because it needs step 6's answer**, and that is the
whole shape of it. A row whose verdict is `absent` is not a pair — there
is nobody to grant a right to — so it never enters the desired state;
but it does travel as far as the scope question, because whoever could
not have granted that project by hand must not be able to make the
person to grant it to either. An instance that did not answer has
neither allowed nor refused, and the row waits.

**The row it creates stays `absent` for this pass** and becomes
`created` at the next one, which is decision 4 working as written rather
than a delay being tolerated: `created` is the row whose previous
verdict was `absent` and that now matches, and that memory lives in the
register. A round that wrote `created` on the strength of having just
made the account would be keeping a second source of truth beside the
sweep, which is the thing decision 4 of the channel's design forbids.

Idempotent by construction: a round interrupted between applying and
writing the outcome leaves the row as still to do, and the next round
applies it again. That is harmless because the diff finds it already
conforming and classifies it `noop` — and it is the reason the job can
be killed at any moment without repair.

A `project_id` the register accepted but that is not a number is named
here with `DATO_PROGETTO_INESISTENTE` right after the pure layer runs,
and before the scope gate ever sees the row.
[`validate_request()`](https://ubesp-dctv.github.io/ubep.azure/reference/validate_request.md)
catches the ones that will not coerce; this catches the ones that coerce
to something else, since `as.integer("9003.7")` is `9003L` and not `NA`,
while
[`scope_pairs()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_pairs.md)
admits the row on `requested_by` alone. Left to the gate it would come
back as a scope refusal, "you may not ask for that project", when the
truth is "that is not a project number" — a data error the referent can
act on, not a permission they are sent to go ask for when they already
hold it.
