# Whether a row the round carried out now asks for another pair

Decided on 2026-11-09: **a row the channel has sealed does not change
its pair**, the instance, the project and the person it was carried out
for. Carried out on the new pair, it would leave the old one on the
instance with no row to govern it, since the round revokes only what a
row asks to revoke; a revoked row moved to another pair would take away
an access it never governed. Whoever wrote the change, the owner
included, and with an approval or not: the row stops before the plan,
nothing is written on the instance, nobody is created, and the row keeps
its seal and its owner.

## Usage

``` r
pair_change(
  executed,
  current,
  target,
  creating,
  rewritten,
  revoked = FALSE,
  account = ""
)
```

## Arguments

- executed:

  The `server`, `project_id` and `username` carried out: the row as read
  when its seal did not move, otherwise what
  [`log_executed_row()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executed_row.md)
  or
  [`log_executed_unverified()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_executed_unverified.md)
  answered.

- current:

  The row as the register holds it, a list or a one-row data frame with
  `server` and `project_id`.

- target:

  The username the round would now serve, `""` when the resolution names
  nobody or would create somebody.

- creating:

  Whether the round would create a person for the row.

- rewritten:

  Whether a write of the person fields by somebody other than the
  channel stands in the row since its last execution; `NA` when the log
  does not say who wrote it, which counts as a write.

- revoked:

  Whether the row asks for `revoked`.

- account:

  What the identifier on Entra says, `""` when it says nothing:
  `TRASPORTO_NOME_RIASSEGNATO` or `TRASPORTO_ACCOUNT_RINOMINATO`; or
  `TRASPORTO_IDENTITA_CAMBIATA` for a row closed on a person gone from
  Entra and set back to active, whose account the round cannot judge
  (item 14 of the limits, 0.29.0).

## Value

A list with `code`, one of the four codes or `""`, and `changed`, which
of `"server"`, `"project_id"` and `"person"` moved, or `"account"` for
the other three.

## Details

Two codes, for the two causes, so that whoever reads the message knows
at once what to do:

- `DATO_COPPIA_CAMBIATA`, the referent's: `server` or `project_id`
  differ from the values carried out, or somebody wrote the person
  (first name, last name, contact address) and the round would now serve
  somebody else, another account or a person to create. Setting the
  fields back to the values carried out brings the row back as it was;
  another person or another project is a new request, and this one is
  revoked, its fields back first;

- `TRASPORTO_IDENTITA_CAMBIATA`, for IT, decided on 2026-11-09 as well:
  the round would serve another account or create one while nobody wrote
  the person in the row, so the account changed on Entra (renamed, on a
  row with no identifier; deleted; its name corrected). Nothing in the
  row explains it, and the referent has nothing to undo.

The pair comes first: it is a change the referent made and can undo, and
the account is looked at once it is back.

**The account carried out is the identifier on Entra too**, decided on
2026-11-12 (item 11 of the 0.27.0). Two codes more, for IT, read from
`applied_entra_id` and handed in as `account`
([`entra_account_change()`](https://ubesp-dctv.github.io/ubep.azure/reference/entra_account_change.md),
[`entra_fill()`](https://ubesp-dctv.github.io/ubep.azure/reference/entra_fill.md)),
after `DATO_COPPIA_CAMBIATA` and before `TRASPORTO_IDENTITA_CAMBIATA`,
with `changed = "account"`:

- `TRASPORTO_NOME_RIASSEGNATO`: the username carried out names now
  another account, deleted and given again, or made again by hand under
  the same name. The resolution may see nothing, since the name and the
  contact are the same;

- `TRASPORTO_ACCOUNT_RINOMINATO`: nobody carries the username carried
  out, and the account carried out is on Entra under another one.

The identifier only adds stops: one that matches lets nothing through
that the rest of this function stops.

Who the round would serve is the resolution's to say. A verdict that
names nobody, `ambiguous` or a collision nobody answered, is left to the
code of the identity, which concedes nothing either; a person to create
is somebody else on a row carried out, whatever name the round would
give them. A username carried out the log does not say decides nothing,
except against a creation, and nor does an empty one: a revocation
closed before anybody was resolved was carried out for nobody.

**A revoked row whose person the tenant no longer holds is no change**,
decided on 2026-11-10, when nobody wrote the person in it: there is
nobody to take the access from and nobody to create, and the round
closes the row before any instance is asked, as it did before the rule.
Stopped for IT, the rows long closed that way would bring an outcome and
a copy each on the first round. A revoked row that resolves to another
account that exists still stops here: revoking that account would take
away an access the row never gave. Since 2026-11-12 the round does not
ask this function about a revoked row whose version carried out is
certain and whose instance and project did not move,
[`revocation_exits()`](https://ubesp-dctv.github.io/ubep.azure/reference/revocation_exits.md):
it revokes the username carried out instead.
