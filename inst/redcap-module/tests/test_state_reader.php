<?php
// inst/redcap-module/tests/test_state_reader.php
require_once __DIR__ . '/../lib/StateReader.php';

use UbepProvisioning\StateReader;

// A user with a role inherits the role's permissions, and the columns on their
// own row do not govern. The two values are deliberately opposite in each of
// the next two cases: a resolution that read the wrong table would still return
// something plausible, and only opposite values make it visible.
ubep_assert_same(
    1,
    StateReader::effectiveUserRights([
        'role_id' => 4,
        'role_user_rights' => 1,
        'own_user_rights' => 0,
    ]),
    'with a role, the role decides and the row does not'
);
ubep_assert_same(
    0,
    StateReader::effectiveUserRights([
        'role_id' => 4,
        'role_user_rights' => 0,
        'own_user_rights' => 1,
    ]),
    'with a role, a permission on the row alone does not grant'
);

ubep_assert_same(
    1,
    StateReader::effectiveUserRights([
        'role_id' => null,
        'role_user_rights' => null,
        'own_user_rights' => 1,
    ]),
    'without a role, the row decides'
);
ubep_assert_same(
    0,
    StateReader::effectiveUserRights([
        'role_id' => null,
        'role_user_rights' => 1,
        'own_user_rights' => 0,
    ]),
    'without a role, a role value that leaked into the row is ignored'
);

// REDCap writes an empty string, not null, for a row with no role, so this is
// the shape a live instance produces and not a defensive extra.
ubep_assert_same(
    1,
    StateReader::effectiveUserRights([
        'role_id' => '',
        'role_user_rights' => null,
        'own_user_rights' => 1,
    ]),
    'an empty role_id is no role, not a role numbered zero'
);

// Null is "could not be read" and never "no permission". A role_id that joins
// to nothing is a role deleted underneath the row: reporting zero would tell
// the caller a measurement was taken that never was.
ubep_assert_same(
    null,
    StateReader::effectiveUserRights([
        'role_id' => 4,
        'role_user_rights' => null,
        'own_user_rights' => 1,
    ]),
    'a role that joins to nothing reads as unknown, never as zero'
);
ubep_assert_same(
    null,
    StateReader::effectiveUserRights(['role_id' => null]),
    'an absent column reads as unknown'
);
ubep_assert_same(
    null,
    StateReader::effectiveUserRights([
        'role_id' => null,
        'own_user_rights' => '',
    ]),
    'an empty value reads as unknown, not as zero'
);

// The value travels as the integer REDCap holds, so a policy that one day has
// to tell a third value from the first two still can. A boolean here would
// have thrown that away at the only place it was still available.
ubep_assert_same(
    2,
    StateReader::effectiveUserRights([
        'role_id' => null,
        'own_user_rights' => '2',
    ]),
    'a value REDCap may add travels intact instead of collapsing to true'
);
