# Tell a person they now have access to a project

The second message of a creation, and the one that carries the context
the welcome leaves out on purpose: which project, on which instance,
with which role and group, until when. It carries no secret and no way
in, so it can say all of it. The key travels in
[`mail_credential_message()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_credential_message.md),
which says none of this.

## Usage

``` r
mail_access_message(row, url = NULL, relay = NULL)
```

## Arguments

- row:

  One register row as a list.

- url:

  The address the row's instance opens at, from
  [`mail_instance_url()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_instance_url.md);
  `NULL`, `NA` or empty leaves the line out.

- relay:

  `NULL` for the message to the person; `"referent"` or `"it"` for the
  one that goes to whoever has to tell them.

## Value

A list with `subject` and `body`.

## Details

The last day is the register's `expiration`, the day the request wrote,
and not the day REDCap stores. REDCap's expiration is the first day
without access, one day later than the last day the person has it
([`to_redcap_expiration()`](https://ubesp-dctv.github.io/ubep.azure/reference/to_redcap_expiration.md)),
and the value in `applied_as` is that stored one: printed as "last day"
it would promise a day more than the person gets.

The project is named by its number and not by its title. The title is
written by whoever builds the project, the register does not hold it,
and fetching it would add a call to REDCap to a message whose job is to
leave.

The owner, when there is one, is named as the project's contact; without
one the line is left out and the closing sentence describes the referent
instead
([`mail_first_contact()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_first_contact.md)),
so a missing owner costs no message.

A person whose account has neither a mailbox nor an external address
([`mail_access_recipients()`](https://ubesp-dctv.github.io/ubep.azure/reference/mail_access_recipients.md))
cannot be written to, and the message goes to somebody who can tell
them: the referent, or IT when the row has no owner. `relay` says which,
and puts on top of each language a line naming the person and asking the
reader to tell them; the message below it is the one the person would
have received.
