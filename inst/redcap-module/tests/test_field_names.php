<?php
require_once __DIR__ . '/../lib/FieldNames.php';

use UbepProvisioning\FieldNames;

// shape: three distinct non-empty names
$governed = FieldNames::governed();
ubep_assert_same(3, count($governed), 'three governed fields');
ubep_assert_same(3, count(array_unique($governed)), 'names are distinct');
foreach ($governed as $name) {
    ubep_assert_true($name !== '', "governed name '$name' is not empty");
    ubep_assert_true(
        (bool) preg_match('/^[a-z][a-z0-9_]*$/', $name),
        "governed name '$name' looks like an API name"
    );
}

// the live check runs only where REDCap exists; offline it is skipped rather
// than failed, so the suite stays runnable in CI without an instance
if (class_exists('\UserRights')) {
    $map = \UserRights::getApiUserPrivilegesAttr(false, null);

    // getApiUserPrivilegesAttr() mixes identity entries (positional integer
    // key, API name as value) with remapped entries (column name as key, API
    // name as value — e.g. 'group_id' => 'data_access_group'). Either way,
    // addPrivileges()/updatePrivileges() read the caller's $rights array
    // using the array *value* as the lookup key, so membership of an API name
    // is in_array() over the values — never array_key_exists(), which checks
    // the wrong half of the pair for every remapped entry and would fail
    // this very assertion for DAG, which does work.
    foreach ([FieldNames::DAG, FieldNames::EXPIRATION] as $name) {
        ubep_assert_true(
            in_array($name, $map, true),
            "'$name' is an API name accepted by the live privileges map"
        );
    }

    // ROLE does not travel through this map at all: it is asserted by a
    // separate call, UserRights::updateUserRoleMapping(), not through the
    // $rights array addPrivileges()/updatePrivileges() read. This guards that
    // fact — if a future REDCap version starts routing role through this map,
    // the test goes red instead of staying silently wrong.
    ubep_assert_true(
        !in_array(FieldNames::ROLE, $map, true)
            && !array_key_exists(FieldNames::ROLE, $map),
        "'" . FieldNames::ROLE . "' is not part of the live privileges map "
            . '(role is asserted via a separate call)'
    );
}
