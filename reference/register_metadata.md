# Read the register's data dictionary as the live project holds it

This is the caller
[`compare_dictionary()`](https://ubesp-dctv.github.io/ubep.azure/reference/compare_dictionary.md)
has been waiting for: until now the comparison existed and nothing ever
handed it a live dictionary, so a drift on the form — a field dropped, a
type loosened, a `@READONLY` annotation removed — could not be seen by
anything.

## Usage

``` r
register_metadata(url, token)
```

## Arguments

- url:

  Hostname of the instance hosting the register, optionally followed by
  the path REDCap is mounted under. A scheme is dropped rather than
  honored, so a base handed over as http is corrected instead of
  silently downgrading the channel.

- token:

  The API token of the service account, sent in the body.

## Value

The
[`register_call()`](https://ubesp-dctv.github.io/ubep.azure/reference/register_call.md)
list plus `dictionary`, a data frame.
