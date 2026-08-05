# Build one write request from a case's assertion

`updatePrivileges` reads whatever keys are present and skips the rest,
so an absent key is different from an asserted absence. Every case in
[`conformance_cases()`](https://ubesp-dctv.github.io/ubep.azure/reference/conformance_cases.md)
encodes "clear this field" as an R `NULL`, which is correct on the
expectation side that
[`compare_readback()`](https://ubesp-dctv.github.io/ubep.azure/reference/compare_readback.md)
reads, but wrong on the wire:
[`utils::modifyList()`](https://rdrr.io/r/utils/modifyList.html) drops a
`NULL`-valued key instead of setting it, and even a key that did survive
with a `NULL` value would serialize through
`httr2::req_body_json(auto_unbox = TRUE)` as `null`, not `""`. So this
is the one place a `NULL` in `assert` becomes the explicit empty string
the channel elsewhere asserts an absence as.

## Usage

``` r
request_for(username, project_id, assert)
```

## Arguments

- username:

  Test account.

- project_id:

  Test project.

- assert:

  Named list of fields to assert, as in one case's `assert`.

## Value

A named list, one element of the `requests` argument
[`module_apply()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_apply.md)
expects.
