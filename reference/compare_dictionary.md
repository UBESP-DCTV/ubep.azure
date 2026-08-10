# Compare a project's dictionary against the packaged one

The packaged CSV is the schema and REDCap imports it as it is, so the
two start identical. What this reads is whether they still are: an
import that dropped a field, a hand edit on the form, a field type
loosened to get past a validation complaint.

## Usage

``` r
compare_dictionary(actual, instances = NULL)
```

## Arguments

- actual:

  The dictionary read back from the live project, in the same
  eighteen-column shape
  [`register_dictionary()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_dictionary.md)
  returns.

- instances:

  Character vector of instance names, passed through to
  [`register_dictionary()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_dictionary.md).
  With it, the choices of `server` are compared by content as every
  other field is. Without it, they are compared by shape and the
  substitution is declared.

## Value

A list with `conforms` and `differences`, the latter a character vector
of `CODE:field` strings. Shaped like
[`compare_readback()`](https://ubesp-dctv.github.io/ubep.azure/reference/compare_readback.md)
because it answers the same kind of question.

## Details

None of those raise anywhere else.
[`request_from_row()`](https://ubesp-dctv.github.io/ubep.azure/reference/request_from_row.md)
reads a missing column as "not set" rather than as an error, and the
channel ignores fields it does not know — which is correct behavior and
also the reason drift here is silent. The comparison is the only thing
that looks.

The codes it can report, and why each is not cosmetic:

- `DIZIONARIO_CAMPO_ASSENTE` — the request loses that field without
  saying so;

- `DIZIONARIO_CAMPO_IN_PIU` — breaks nothing, and is direct evidence
  that somebody edited the form by hand;

- `DIZIONARIO_TIPO_DIVERSO` — a `request_status` gone free-text turns a
  typo into a request to grant what somebody asked to revoke;

- `DIZIONARIO_SCELTE_DIVERSE` — same type, and the value that revokes is
  gone;

- `DIZIONARIO_READONLY_CADUTO` — a requester can type `applied` into the
  outcome, and the register carries a success nobody produced;

- `DIZIONARIO_COLONNA_ASSENTE` — the dictionary is malformed, and
  without this code it would read as conforming rather than as
  unreadable;

- `DIZIONARIO_SCELTE_NON_CONFRONTATE` — reported for `server` when no
  instance list was given: its choices are the fleet, so without the
  list only their shape can be judged. It makes `conforms` false on an
  otherwise sound dictionary, deliberately — a comparison that could not
  look at a field must not be able to return a green, which is the same
  reason `DIZIONARIO_COLONNA_ASSENTE` exists.
