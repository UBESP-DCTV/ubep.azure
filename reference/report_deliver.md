# Hand one report to the mailer, redirected when asked

Hand one report to the mailer, redirected when asked

## Usage

``` r
report_deliver(mailer, to, cc, message, redirect_to = NULL)
```

## Arguments

- mailer:

  `function(to, cc, subject, body)` returning `ok` and `errors`.

- to, cc:

  Who the report is for, and who in copy.

- message:

  What
  [`report_message()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_message.md)
  or
  [`report_it_message()`](https://ubesp-dctv.github.io/ubep.azure/reference/report_it_message.md)
  composed.

- redirect_to:

  One address replacing every recipient, or `NULL`.

## Value

A list with `ok` and `errors`.
