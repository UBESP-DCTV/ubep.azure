<?php
require_once __DIR__ . '/../lib/Surface.php';
require_once __DIR__ . '/SurfaceFixture.php';

use UbepProvisioning\Surface;

$signatures = [
    'addPrivileges($project_id,$rights,$checkAcgCompliance?):bool|array',
    'updatePrivileges($project_id,$rights,$checkAcgCompliance?):bool|array',
];
$fieldMap = [0 => 'username', 1 => 'expiration', 'group_id' => 'data_access_group'];

$first = Surface::fingerprintFrom($signatures, $fieldMap);

// shape: 12 lowercase hex characters
ubep_assert_same(12, strlen($first), 'fingerprint length');
ubep_assert_true(
    (bool) preg_match('/^[0-9a-f]{12}$/', $first),
    'fingerprint is lowercase hex'
);

// deterministic: same input, same output
ubep_assert_same(
    $first,
    Surface::fingerprintFrom($signatures, $fieldMap),
    'fingerprint is deterministic'
);

// a changed signature changes the fingerprint
$changedSignatures = $signatures;
$changedSignatures[0] = 'addPrivileges($project_id,$rights):bool';
ubep_assert_true(
    $first !== Surface::fingerprintFrom($changedSignatures, $fieldMap),
    'a changed signature changes the fingerprint'
);

// a changed field map changes the fingerprint — this is the silent failure the
// whole mechanism exists to catch
$changedMap = $fieldMap;
$changedMap['data_export_tool'] = 'data_export';
ubep_assert_true(
    $first !== Surface::fingerprintFrom($signatures, $changedMap),
    'a changed field map changes the fingerprint'
);

// key order must not matter: PHP array order is not part of the contract, and
// two instances of the same version must agree
$reordered = [
    'group_id' => 'data_access_group',
    1 => 'expiration',
    0 => 'username',
];
ubep_assert_same(
    $first,
    Surface::fingerprintFrom($signatures, $reordered),
    'field map order does not affect the fingerprint'
);

ubep_assert_same(
    $first,
    Surface::fingerprintFrom(array_reverse($signatures), $fieldMap),
    'signature order does not affect the fingerprint'
);

// a renamed field must not collide with a reordering: key and value both count
$renamed = [0 => 'username', 1 => 'expiration', 'group_id' => 'dag'];
ubep_assert_true(
    $first !== Surface::fingerprintFrom($signatures, $renamed),
    'a renamed target changes the fingerprint'
);

// signaturesOf renders parameters, optionality and return type
ubep_assert_same(
    ['fixtureMethod($a,$b?):string'],
    Surface::signaturesOf('UbepProvisioning\\SurfaceFixture', ['fixtureMethod']),
    'signaturesOf renders an untyped signature'
);
// Note the return type: declared as bool|array, reflected as array|bool. PHP
// normalizes the order of union members, which is what we want — the same type
// declared in either order yields the same fingerprint, so the gate does not
// cry wolf over a cosmetic edit in REDCap's source.
ubep_assert_same(
    ['typedMethod(int $n,?string $s?):array|bool'],
    Surface::signaturesOf('UbepProvisioning\\SurfaceFixture', ['typedMethod']),
    'signaturesOf renders types, nullability and union return'
);

// a method REDCap removed must degrade to a different fingerprint, not a fatal:
// the instance has to stay readable so the diagnosis is possible
ubep_assert_same(
    ['goneMethod:<missing>'],
    Surface::signaturesOf('UbepProvisioning\\SurfaceFixture', ['goneMethod']),
    'a missing method is reported, not fatal'
);
