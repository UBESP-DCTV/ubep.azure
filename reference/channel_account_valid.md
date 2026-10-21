# Whether a value can name the channel's accounts

`NULL`, not configured, or one or more REDCap usernames, none of them
blank or missing: a blank name would make the channel nobody, which is a
configuration that is missing and not one that says something. More than
one for the day the account that holds the token changes. The check
every function taking `channel_account` makes on entry.

## Usage

``` r
channel_account_valid(channel_account)
```

## Arguments

- channel_account:

  The value a caller was handed.

## Value

`TRUE` or `FALSE`.
