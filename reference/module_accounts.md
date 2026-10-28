# Read the local REDCap accounts of a set of people from one instance

Asks the module only for the names it is given and returns one entry per
name, present or not: `accounts` answers on the names asked, never on
the whole instance, so a person who is missing is an entry that says so
and not an absence the caller has to interpret.

## Usage

``` r
module_accounts(
  server,
  secret,
  usernames,
  registry = tested_fingerprints(),
  declare = certified_fingerprints(registry)
)
```

## Arguments

- server:

  Hostname of the instance, optionally followed by the path REDCap is
  mounted under, as in `"host.example.org/redcap"`. The fleet is not
  uniform on this point, so the mount cannot be assumed.

- secret:

  Shared secret, sent as the `X-UBEP-Secret` header.

- usernames:

  Character vector of user names.

- registry:

  Tested fingerprints, see
  [`check_fingerprint()`](https://ubesp-dctv.github.io/ubep.azure/reference/check_fingerprint.md).

- declare:

  Fingerprints the caller states it has been tested against. The module
  refuses to write when its own is not among them, so an empty
  declaration writes nothing. Reads and dry runs ignore it.

## Value

A list with `ok`, `errors`, `payload` and `gate`; `payload$accounts`
holds the entries of every call, in the order of the names.

## Details

It accepts contract 4 and nothing else, unlike the other operations. A
module still at 3 does not know `accounts` and answers `501` with
`contract_version: 3`; with the lists the other operations use that
would come out as `INTERNO`, a failure of the module, when it is a
module that has not been updated yet. Accepting only 4 makes the parser
look at the contract before the status, and the answer is
`TRASPORTO_CONTRATTO_DISALLINEATO`.

The names go in chunks of
[`module_accounts_limit()`](https://ubesp-dctv.github.io/ubep.azure/reference/module_accounts_limit.md),
because a longer request is refused by the module. The first chunk that
fails is the answer for the whole call: a partial list would read as
people who have never logged in. A name repeated is asked once, ignoring
case and surrounding blanks, the same comparison the module makes. An
empty set of names makes no call at all: there is nothing to ask, and a
request with no names is not a read of the instance.
