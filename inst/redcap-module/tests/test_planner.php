<?php
// inst/redcap-module/tests/test_planner.php
require_once __DIR__ . '/../lib/Planner.php';

use UbepProvisioning\Planner;

$current = [
    [
        'username' => 'a@example.org', 'project_id' => 27,
        'role_name' => 'data entry', 'dag_name' => 'centro-01',
        'expiration' => '2027-01-01',
    ],
];

// unchanged assertion -> noop
$same = Planner::planApply([[
    'username' => 'a@example.org', 'project_id' => 27,
    'role_name' => 'data entry', 'dag_name' => 'centro-01',
    'expiration' => '2027-01-01',
]], $current);
ubep_assert_same(1, count($same), 'one entry per request');
ubep_assert_same('noop', $same[0]['outcome'], 'identical assertion is a noop');

// absent pair -> creato
$new = Planner::planApply([[
    'username' => 'b@example.org', 'project_id' => 27,
    'role_name' => 'read only', 'dag_name' => null, 'expiration' => null,
]], $current);
ubep_assert_same('creato', $new[0]['outcome'], 'absent pair is a creation');
ubep_assert_same(null, $new[0]['before']['role_name'], 'before is empty');
ubep_assert_same('read only', $new[0]['after']['role_name'], 'after is asserted');

// any differing field -> aggiornato
$changed = Planner::planApply([[
    'username' => 'a@example.org', 'project_id' => 27,
    'role_name' => 'data entry', 'dag_name' => 'centro-01',
    'expiration' => '2027-06-30',
]], $current);
ubep_assert_same('aggiornato', $changed[0]['outcome'], 'changed expiration');

// a DAG present but not asserted must show as a change, never a noop
$dropDag = Planner::planApply([[
    'username' => 'a@example.org', 'project_id' => 27,
    'role_name' => 'data entry', 'dag_name' => null,
    'expiration' => '2027-01-01',
]], $current);
ubep_assert_same(
    'aggiornato',
    $dropDag[0]['outcome'],
    'asserting no DAG against an existing one is a change'
);
ubep_assert_same(
    'centro-01',
    $dropDag[0]['before']['dag_name'],
    'before keeps the DAG that is about to go'
);

// the pair is the unit: same user, another project
$otherProject = Planner::planApply([[
    'username' => 'a@example.org', 'project_id' => 99,
    'role_name' => 'data entry', 'dag_name' => null, 'expiration' => null,
]], $current);
ubep_assert_same(
    'creato',
    $otherProject[0]['outcome'],
    'same user in another project is a creation'
);

// revoke
$revoke = Planner::planRevoke([[
    'username' => 'a@example.org', 'project_id' => 27,
]], $current);
ubep_assert_same('revocato', $revoke[0]['outcome'], 'present pair is revoked');
ubep_assert_same(
    'centro-01',
    $revoke[0]['before']['dag_name'],
    'before records what is about to be removed'
);
ubep_assert_same(null, $revoke[0]['after']['role_name'], 'after is empty');

$revokeAbsent = Planner::planRevoke([[
    'username' => 'nobody@example.org', 'project_id' => 27,
]], $current);
ubep_assert_same(
    'noop',
    $revokeAbsent[0]['outcome'],
    'revoking what is not there is a noop, not an error'
);

// The structural guarantee behind dry_run, made checkable. A text scan is
// crude, but this is the check that turns red the day someone "simplifies" by
// moving the write back into the planner — which is how the guarantee dies.
$source = file_get_contents(__DIR__ . '/../lib/Planner.php');
foreach (['addPrivileges', 'updatePrivileges', 'removePrivileges'] as $writer) {
    ubep_assert_same(
        false,
        strpos($source, $writer),
        "Planner must not name $writer"
    );
}
