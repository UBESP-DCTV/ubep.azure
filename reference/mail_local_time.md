# Turn the register's UTC stamp into the hour a person in Rome reads

The register keeps UTC, which is the machine's truth and the one value
the comparison in
[`round_changed()`](https://ubesp-dctv.github.io/ubep.azure/reference/round_changed.md)
ignores by design. A person reading a mail does not hold that
convention, and the field test measured the cost: two hours counted
three times as latency before somebody read the code.

## Usage

``` r
mail_local_time(at)
```

## Arguments

- at:

  The register's `outcome_at`, `"%Y-%m-%d %H:%M"` in UTC.

## Value

The same moment in Italian civil time, or `NA_character_` if `at` does
not parse – a wrong hour is worse than a missing one.

## Details

The conversion belongs here, in the text a person reads, and not in the
field the code compares.
