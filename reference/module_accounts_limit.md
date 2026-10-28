# Largest number of names one `accounts` call may carry

The module caps the operation at this many names and answers a longer
request with `400` and `INTERNO`, so
[`module_accounts()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_accounts.md)
splits by it.

## Usage

``` r
module_accounts_limit()
```

## Value

`500L`.
