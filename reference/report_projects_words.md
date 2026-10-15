# Say the projects of a person, instance by instance

Say the projects of a person, instance by instance

## Usage

``` r
report_projects_words(projects)
```

## Arguments

- projects:

  A frame of `server` and `project_id`, as
  [`report_assemble()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_assemble.md)
  builds it.

## Value

A character vector named `it` and `en`, as in
`"edc10, progetti 9301 e 9302; edc12, progetto 9303"`.
