# Bring the refusals of the several subjects of a row back to one

The other half of
[`scope_expand()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_expand.md):
[`scope_errors()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_errors.md)
answers per line, so a row judged on several people comes back once for
each of them who is refused. The row is one, and so is its answer. A
permission nobody could read decides it, because that refusal is not a
verdict about anybody and keeps the row queued; otherwise the row is
refused as not authorized.

## Usage

``` r
scope_merge(refused)
```

## Arguments

- refused:

  What
  [`scope_errors()`](https://ubesp-dctv.github.io/ubep.azure/reference/scope_errors.md)
  returned for an expanded register: a named list, names repeated.

## Value

A named list, one entry per `record_id`, in the order each first
appears, holding `"TRASPORTO_PERMESSO_NON_LEGGIBILE"` when any of its
codes is that and `"DATO_AMBITO_NON_AUTORIZZATO"` otherwise.
