# The fields only the channel writes

Every read-only field but `requested_by`, which `@USERNAME` fills in
with the account that creates the row: it is the one read-only field a
person writes. The rest are `@READONLY` on the form, and the import
right that would let a person write them anyway is granted to nobody, so
an event that wrote one of them was written by the account that holds
the round's token. That is how the round tells its own writes apart in
the event log without anybody configuring the name of that account.

## Usage

``` r
register_channel_fields()
```

## Value

A character vector of field names.
