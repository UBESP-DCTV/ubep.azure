<?php
// inst/redcap-module/tests/test_applier.php
require_once __DIR__ . '/../lib/FieldNames.php';
require_once __DIR__ . '/../lib/Applier.php';

use UbepProvisioning\Applier;
use UbepProvisioning\FieldNames;

$entry = [
    'username' => 'a@example.org',
    'project_id' => 27,
    'outcome' => 'aggiornato',
    'before' => ['role_name' => 'read only', 'dag_name' => null,
                 'expiration' => null],
    'after' => ['role_name' => 'data entry', 'dag_name' => 'centro-01',
                'expiration' => '2027-01-01'],
];

$args = Applier::argumentsFor($entry, 5);

// the username always travels
ubep_assert_same('a@example.org', $args['username'], 'username is carried');

// the DAG travels as the id argumentsFor() is given, never as the plan
// entry's dag_name: REDCap stores data_access_group in an int column with a
// foreign key to redcap_data_access_groups, and a name there coerces to 0
// under non-strict SQL mode, which the foreign key then refuses -- taking
// the role and the expiration down with it (see Applier's class docblock).
// argumentsFor() cannot resolve the name itself -- resolution touches the
// database -- so the caller passes the id in already. A weaker assertion
// here (e.g. "!== the plan entry's dag_name", or "is numeric") would be
// subsumed by this one and unable to fail independently of it, so the
// discriminating check carries the intent in its own message instead of
// splitting it across assertions that cannot disagree with each other.
ubep_assert_same(
    '5',
    $args[FieldNames::DAG],
    "the resolved DAG id ('5'), not the plan entry's dag_name ('centro-01'), travels under FieldNames::DAG"
);

// both fields that travel inside the rights array are present, always:
// updatePrivileges skips what you do not pass, except data_access_group, which
// it includes anyway and sets to NULL when you omit it. A delta would therefore
// drop DAGs on every renewal.
foreach ([FieldNames::DAG, FieldNames::EXPIRATION] as $name) {
    ubep_assert_true(
        array_key_exists($name, $args),
        "field '$name' is always asserted"
    );
}

// the role is NOT one of them, and this is the measurement made into a test:
// role_id is not a key of the live privileges map, so it reaches REDCap through
// a separate call. Putting it back into this array would deny a permission in
// silence, which is the failure this whole task is shaped around.
ubep_assert_same(
    false,
    array_key_exists(FieldNames::ROLE, $args),
    'the role does not travel inside the rights array'
);

// an absent DAG id (null, meaning resolution found no name to resolve) is
// asserted as empty, not omitted -- the path that is already correct on the
// field (cases 3 and 4 of the conformance run) and must not be disturbed by
// this change. $entry['after']['dag_name'] is irrelevant here: argumentsFor()
// no longer reads it, the resolved id is the only input that matters.
$argsNoDag = Applier::argumentsFor($entry, null);
ubep_assert_true(
    array_key_exists(FieldNames::DAG, $argsNoDag),
    'an absent DAG is still asserted'
);
ubep_assert_same(
    '',
    $argsNoDag[FieldNames::DAG],
    'an absent DAG is asserted as empty'
);

// argumentsFor() above pins only the downstream half of that path: the id
// resolveDag() would hand it, once resolved. The other half -- that a null
// dag_name makes resolveDag() return immediately, without ever building the
// SELECT -- has no coverage yet, and it is the guard that keeps the two
// DAG-absent cases green on the field without a database call. resolveDag()
// is private, reached in production only through apply(), which this
// offline suite cannot exercise (no \UserRights class to receive the write).
// Reflection is the only way to call it directly: if the null branch were
// ever removed, this would not fail an assertion, it would fatal on the
// undefined db_query() -- this offline suite defines none of REDCap's DB
// functions -- the same fail-loud shape already relied on for revoke()
// below.
$resolveDag = new ReflectionMethod(Applier::class, 'resolveDag');
$resolveDag->setAccessible(true);
$noDagName = $entry;
$noDagName['after']['dag_name'] = null;
ubep_assert_same(
    ['dagId' => null, 'error' => null],
    $resolveDag->invoke(null, $noDagName),
    'resolveDag() short-circuits a null name without touching the database'
);

// the same absent-is-empty rule applies to the other field this array
// carries, not just the DAG
$noExpiration = $entry;
$noExpiration['after']['expiration'] = null;
$argsNoExpiration = Applier::argumentsFor($noExpiration, 5);
ubep_assert_true(
    array_key_exists(FieldNames::EXPIRATION, $argsNoExpiration),
    'an absent expiration is still asserted'
);
ubep_assert_same(
    '',
    $argsNoExpiration[FieldNames::EXPIRATION],
    'an absent expiration is asserted as empty'
);

// nothing beyond those two fields and the username is ever sent
$extra = array_diff(
    array_keys($args),
    [FieldNames::DAG, FieldNames::EXPIRATION, 'username']
);
ubep_assert_same(
    [],
    array_values($extra),
    'no field outside the two carried ones is sent'
);

// which write function an outcome selects. A creation reaching updatePrivileges
// would update a row that is not there: no write, no error, and a report of
// success.
ubep_assert_same('create', Applier::writeKindFor('creato'), 'creation adds');
ubep_assert_same('update', Applier::writeKindFor('aggiornato'), 'change updates');
ubep_assert_same(null, Applier::writeKindFor('noop'), 'a noop writes nothing');
ubep_assert_same(
    null,
    Applier::writeKindFor('errore'),
    'an entry already in error writes nothing'
);
ubep_assert_same(
    null,
    Applier::writeKindFor('revocato'),
    'a revocation never selects a rights write'
);

// revoke() must filter on 'revocato', not on "anything but noop". The
// test-project brake marks an out-of-scope entry 'errore' before revoke()
// ever sees it (see api.php); with the old "!== noop" filter that entry
// would reach removePrivileges() the same as a real revocation, deleting the
// rights while the caller is told the write was refused. No \UserRights
// class exists in this offline suite, so if either entry below were not
// skipped, this call would fatal here instead of merely failing an
// assertion.
$refused = [
    'username' => 'a@example.org',
    'project_id' => 27,
    'outcome' => 'errore',
    'before' => ['role_name' => 'data entry', 'dag_name' => null,
                 'expiration' => null],
    'after' => ['role_name' => null, 'dag_name' => null, 'expiration' => null],
    'errors' => [['code' => 'INTERNO', 'message' => 'out of scope']],
];
$untouched = [
    'username' => 'b@example.org',
    'project_id' => 27,
    'outcome' => 'noop',
    'before' => ['role_name' => null, 'dag_name' => null, 'expiration' => null],
    'after' => ['role_name' => null, 'dag_name' => null, 'expiration' => null],
    'errors' => [],
];
$revoked = Applier::revoke([$refused, $untouched]);
ubep_assert_same(
    $refused,
    $revoked[0],
    'an entry already in error is left untouched by revoke(), not written'
);
ubep_assert_same(
    $untouched,
    $revoked[1],
    'a noop entry is left untouched by revoke()'
);

// This guard is one-sided on purpose: both fixtures above are non-'revocato'
// ('errore', 'noop'), so an unconditional `continue` -- or the pre-fix
// `!== 'noop'` filter with the branches swapped -- would pass these two
// assertions identically. Nothing here pins that a 'revocato' entry still
// reaches removePrivileges(): that positive case needs a real write call,
// and this offline suite has no \UserRights double to receive it, only the
// live conformance test (phase-2 design spec, §8) exercises that path.
