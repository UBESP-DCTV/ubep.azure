# The events of the row that stands now, without those of an earlier one

A record id can be used twice: deleted, and made again by somebody else
for another request. The log keeps both lives under the same `record`,
and everything below the newest creation belongs to a row that no longer
exists. The creation itself is the first event of the row that stands
now, and stays: a row with one life is answered whole, as before the
cut.

## Usage

``` r
log_current_life(events)
```

## Arguments

- events:

  The events of one record, newest first.

## Value

The events from the newest creation on, or all of them when there is
none.

## Details

Which event is newest comes from the order of the answer, REDCap's own,
newest first, as for
[`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md),
which names as the creator the author of this same event; the stamps are
to the minute, and two lives can share one. The creation is read as
[`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
reads it, from the start of `action`, whose wording was measured on
2026-09-02. Read as a guard, a wording that does not match cuts nothing,
and the log is read whole as before;
[`log_creators()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_creators.md)
then names nobody, and the round holds the row.

Only the creation cuts, and not the deletion, whose wording was never
measured. Nothing is lost by it, since the deletion of an earlier life
stands below the creation of the current one. And an event that only
reads like a deletion, inside the current life, would cut that life's
own changes in the direction that grants: below it may stand a change by
somebody else, which the round would then carry out with nobody asked.

Read by
[`log_of_record()`](https://ubesp-dctv.github.io/ubep.azure/reference/log_of_record.md),
so by every reader of a row's log.
