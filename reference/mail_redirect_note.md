# Put a redirected message's real recipient into the message

A field test runs on real data with every recipient replaced by one
address. The line saying who it would have gone to is what makes the run
readable; the counter saying the round was redirected is what keeps a
forgotten redirect from being silent.

## Usage

``` r
mail_redirect_note(body, to, cc)
```

## Arguments

- body:

  The composed body.

- to, cc:

  Who the message was addressed to before the redirect.

## Value

The body, with the declaration on top.
