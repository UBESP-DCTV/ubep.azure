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
