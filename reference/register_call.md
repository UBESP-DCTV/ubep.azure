# Call the register's REDCap API once

The only function in the package that speaks to the request register,
and the only one that builds its URL. The register is read and written
with a token rather than with the module, which is the mechanism the
channel's first design set aside: the argument against it was that the
friction grows with the number of projects, and here the project is one,
and one forever.

## Usage

``` r
register_call(url, token, params)
```

## Arguments

- url:

  Hostname of the instance hosting the register, optionally followed by
  the path REDCap is mounted under. A scheme is dropped rather than
  honored, so a base handed over as http is corrected instead of
  silently downgrading the channel.

- token:

  The API token of the service account, sent in the body.

- params:

  Named list of REDCap API parameters, without `token`, `format` and
  `returnFormat`, which are set here.

## Value

A list with `ok`, `errors` and `payload`, shaped like the module
client's answer because it answers the same kind of question.

## Details

The answer is recognized by its shape and never by its status code. An
instance whose API is switched off answers 200 with an HTML page,
exactly as a disabled module answers 200 with a sentence, and a client
that inferred success from the status would fail inside the JSON parser
reporting an error that does not name the cause.
