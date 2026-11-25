# The text a referent copies into a new e-mail to the person, with the key

Proposed by the coordinator of the referents on 2026-11-19 and decided
the same day: with written steps for the first sign-in many people get
in who would not with the welcome alone, so the message with the key
brings them ready, one text per language, for the referent to copy. It
carries the person's first name, the key, the date of the first sign-in
and the steps, and nothing of the context: no instance address, no
project, no user name. Those reach the person in the welcome and, for
the project, in My Projects when the access e-mail arrives; the text
says where to find them. Key and context do not travel together.

## Usage

``` r
mail_credential_ready_text(first_name, credential, deadline)
```

## Arguments

- first_name:

  The person's first name, from the row; missing or empty leaves the
  greeting without it. The referent fills the field, so white space
  inside it, a line break included, becomes one space: the greeting
  stays one line.

- credential:

  What the account was born with.

- deadline:

  The date of the first sign-in, from
  [`mail_first_signin_deadline()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_first_signin_deadline.md);
  `NULL`, `NA` or empty leaves the sentence on the date out.

## Value

A list with `it` and `en`, each a character vector of lines, the
delimiters included.

## Details

The steps are those of the work instruction on the first sign-in, cut to
what a person needs on the day, with three choices made there: a private
window always, the second factor only with `Microsoft Authenticator`,
through `Verified IDs` and `Scan QR code`, and `Yes` to
`Stay signed in?`. A step more, decided on 2026-11-24 with the
configuration of Entra: the self-service reset asks for two methods,
Authenticator and an e-mail address confirmed with a code, and no longer
accepts a phone, so after Authenticator the person gives an address of
their own.

The two methods close as Entra closes them, seen on a test account on
2026-11-24: Authenticator, method 1 of 2, with `Done`, then method 2 of
2, the recovery address, with `Next`. The Italian text gives the Italian
label with the English one in brackets where that test or the work
instruction 00.06 shows it (`Avanti`, `Fine`, `Metodo 2 di 2`), and the
English label alone elsewhere.

The sentence that says where the welcome is also says what to do if it
is not there, whether it was lost, went to the junk folder or never
arrived: write to the referent (decided on 2026-11-25). It is said once,
where the welcome is named in full.

The ban on `Skip for now` opens step 4, before the instructions of the
step (decided on 2026-11-25): the first page of the step is the one that
offers it, and the ban comes before the person reads on.

Each text sits between two delimiter lines, because the line with the
user name stands above it in the same message, and a referent copying by
hand should know where to stop. The delimiters are not a bare `---`, the
line that separates the two languages of every message.
