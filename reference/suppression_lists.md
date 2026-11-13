# The suppression lists of the mail service

SendGrid keeps five lists of addresses per user. Four of them
**suppress**: a send to an address on them answers 202 and does not
leave, so the channel counts as delivered a message nobody receives. The
fifth, *Blocks*, does not: measured on 2026-11-10, a block does not stop
the next send, which may get through. So the four are judged as a state
(the address is on the list today) and *Blocks* only as an event (an
entry created in the last hours).

## Usage

``` r
suppression_lists()
```

## Value

A data frame with `lista`, the path under `/v3/suppression/` and the
name the code uses; `nome`, the name the console shows; and `sopprime`,
whether a send to an address on it is dropped.

## Details

One list for the reader, the matcher and the mail to IT, so the path the
API is asked on and the name the console shows cannot drift apart.
