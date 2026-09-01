# Send this round's messages, and say which rows may now be written

The order is the decision: send first, write after. A row whose message
did not leave stays as the register has it, so the next round finds it
changed again and retries – the queue is the register, and no second
state exists to keep aligned. The cost accepted in exchange is a
duplicate, never a loss.

## Usage

``` r
mail_round(
  changed,
  register,
  born,
  mailer,
  dry_run,
  redirect_to = NULL,
  copy_to = NULL,
  reply_to = NULL,
  identified = NULL
)
```

## Arguments

- changed:

  The rows this round would write, from
  [`round_changed()`](https://ubesp-dctv.github.io/ubep.azure/reference/round_changed.md).

- register:

  The register as read, carrying every field the messages name.

- born:

  The accounts created this round: lists with `record_id`, `upn` and
  `credential`.

- mailer:

  `function(to, cc, subject, body)` returning `ok` and `errors`.

- dry_run:

  When `TRUE` nothing is sent and every row comes back writable – the
  round behaves as it did before this file existed.

- redirect_to:

  One address replacing every recipient, for a field test.

- copy_to:

  Address in copy, on the outcome message only.

- reply_to:

  Kept for the caller's symmetry with
  [`mail_send()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_send.md);
  the mailer closure is what carries it to the transport.

- identified:

  The identity this round settled, as a frame with `record_id` and the
  fields it settled. `register` is the register as read, on purpose;
  this is how the message names what the round has just established
  rather than what the referent typed.

## Value

A list with `recapitate`, `errori` and `contatori`.

## Details

The credential message is the asymmetry. The account is already born,
the round does not create it twice, and the managed identity cannot
repair it. So its failure is not a retry: it is a person's job, and it
goes out under its own code so an alarm can tell the two apart.
