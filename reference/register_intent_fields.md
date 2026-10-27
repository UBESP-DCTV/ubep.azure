# The fields a row carries because somebody asked for them

Derived and not listed: everything in the dictionary the seal has to
cover. A field added to the dictionary joins this set on its own, which
is the property that keeps the seal honest — a hand-picked list would
silently stop covering the column somebody added last week.

## Usage

``` r
register_intent_fields()
```

## Value

A character vector of field names, in dictionary order.

## Details

It joins the intent fields on its own, and the seal only by a rule of
its own: a field added after the first seals were written is one of
[`register_late_seal_fields()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_late_seal_fields.md),
and enters the seal only when it holds a value
([`request_seal()`](https://ubesp-dctv.github.io/ubep.azure/reference/request_seal.md)).
Entered empty, it would move every seal already written. Its writes
count as a change of the row all the same, from the day it exists.
