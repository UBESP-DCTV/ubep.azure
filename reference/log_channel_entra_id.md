# The Entra account the channel last wrote on a row, from the log

Item 11 of the 0.27.0 (decided on 2026-11-12): `applied_entra_id` is
believed from the log only, as `owned_by` is
([`log_owner()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_owner.md)).
The value is the newest write of the field signed by an account of
`channel_account` in the row's current life
([`log_of_record()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_of_record.md)),
in the form of its door,
[`register_entra_id_import()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_entra_id_import.md):
`details` holding `applied_entra_id = '<value>'` and nothing else. The
field is `@READONLY` on the form and written by an import as any other,
so a value a referent imported is not the channel's and is passed over.

## Usage

``` r
log_channel_entra_id(events, record, channel_account)
```

## Arguments

- events:

  The owners' log, as
  [`register_log()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_log.md)
  returns it.

- record:

  The record id to look at.

- channel_account:

  The REDCap usernames that hold the round's token, one or more. Not
  `NULL`: without them no value is believed.

## Value

One identifier; `""` when the channel never wrote one in the row's
current life; `NA_character_` when the log cannot say.

## Details

Two writes make the answer unknown, the direction that neither checks
nor writes anything for the row: a write of the field whose author is
blank or missing, which could be the channel's, above the one believed;
and a write of the channel's in another form, beside other fields, whose
value cannot be told apart from theirs. A write of the channel's that
leaves the field empty names nobody, and the one below it is read: it is
the first half of a write the door makes twice, when the field already
showed the value.
