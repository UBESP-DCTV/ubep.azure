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

$args = Applier::argumentsFor($entry);

// the username always travels
ubep_assert_same('a@example.org', $args['username'], 'username is carried');

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

// an absent value is asserted as empty, not omitted
$noDag = $entry;
$noDag['after']['dag_name'] = null;
$argsNoDag = Applier::argumentsFor($noDag);
ubep_assert_true(
    array_key_exists(FieldNames::DAG, $argsNoDag),
    'an absent DAG is still asserted'
);
ubep_assert_same(
    '',
    $argsNoDag[FieldNames::DAG],
    'an absent DAG is asserted as empty'
);

// the same absent-is-empty rule applies to the other field this array
// carries, not just the DAG
$noExpiration = $entry;
$noExpiration['after']['expiration'] = null;
$argsNoExpiration = Applier::argumentsFor($noExpiration);
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
