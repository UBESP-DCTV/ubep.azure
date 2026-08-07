<?php
require_once __DIR__ . '/../lib/Allowlist.php';
require_once __DIR__ . '/AllowlistModuleDouble.php';

use UbepProvisioning\Allowlist;
use UbepProvisioning\AllowlistModuleDouble;

$one = Allowlist::fingerprintFrom("1.2.3.4\n5.6.7.8");

// shape: twelve lowercase hex, the same as the surface fingerprint, so the two
// read alike in a report
ubep_assert_same(12, strlen($one), 'allowlist fingerprint length');
ubep_assert_true(
    (bool) preg_match('/^[0-9a-f]{12}$/', $one),
    'allowlist fingerprint is lowercase hex'
);

ubep_assert_same(
    $one,
    Allowlist::fingerprintFrom("1.2.3.4\n5.6.7.8"),
    'allowlist fingerprint is deterministic'
);

// Order, blank lines and stray whitespace must not move it: two instances
// configured with the same addresses have to agree, or every run would report
// a change that is only formatting.
ubep_assert_same(
    $one,
    Allowlist::fingerprintFrom("  5.6.7.8 \n\n1.2.3.4\n"),
    'order and whitespace do not affect the allowlist fingerprint'
);

// An added address must move it. This is what makes a hand on the perimeter
// visible.
ubep_assert_true(
    $one !== Allowlist::fingerprintFrom("1.2.3.4\n5.6.7.8\n9.9.9.9"),
    'an added address changes the allowlist fingerprint'
);

// A removed one must move it too: the falling of the development entry is the
// event this mechanism exists to record.
ubep_assert_true(
    $one !== Allowlist::fingerprintFrom("1.2.3.4"),
    'a removed address changes the allowlist fingerprint'
);

// An empty setting must not collapse onto a configured one. A reader that
// returned nothing would otherwise look healthy.
ubep_assert_true(
    Allowlist::fingerprintFrom('') !== $one,
    'an empty allowlist is distinguishable from a populated one'
);

// The digest never carries the addresses. Asserted rather than assumed,
// because the value travels to a client and into a log.
ubep_assert_true(
    strpos($one, '1.2.3.4') === false && strlen($one) === 12,
    'the fingerprint does not carry the addresses'
);

// --- and now the part test_surface.php is missing --------------------------
// Everything above collaudates the digest. These exercise the *reading*: the
// key name is part of the contract, and a typo in it would silently produce
// the empty-list fingerprint on every instance while all the assertions above
// stayed green.

$module = new AllowlistModuleDouble(['ip-allow-list' => "1.2.3.4\n5.6.7.8"]);

ubep_assert_same(
    $one,
    Allowlist::fingerprintOf($module),
    'fingerprintOf reads the setting and matches the direct digest'
);

ubep_assert_same(
    ['ip-allow-list'],
    $module->asked,
    'fingerprintOf asks for exactly the configured key name'
);

// A module whose setting is absent must not throw: an unconfigured instance
// has to stay diagnosable, the same way a missing method degrades to a
// different fingerprint instead of a fatal.
$unset = new AllowlistModuleDouble([]);
ubep_assert_same(
    Allowlist::fingerprintFrom(''),
    Allowlist::fingerprintOf($unset),
    'an unset allowlist yields the empty fingerprint rather than an error'
);

// --- one parser, one truth -------------------------------------------------
// The fingerprint and the check must agree on what an entry is. Two parsers
// would drift: either a formatting-only edit raises a standing false alarm, or
// a real change to the enforced list goes unreported.

require_once __DIR__ . '/../lib/Auth.php';

$spaziato = "1.2.3.4 5.6.7.8";
$aCapo = "1.2.3.4\n5.6.7.8";

ubep_assert_same(
    Allowlist::fingerprintFrom($spaziato),
    Allowlist::fingerprintFrom($aCapo),
    'separators do not change the fingerprint'
);

ubep_assert_true(
    \UbepProvisioning\Auth::checkIp('5.6.7.8', $spaziato)
        && \UbepProvisioning\Auth::checkIp('5.6.7.8', $aCapo),
    'the check accepts the same address from either separator'
);

// And the converse, which is the one that matters: an address the check
// refuses must not be in the entries the fingerprint covered.
ubep_assert_same(false, 
    \UbepProvisioning\Auth::checkIp('9.9.9.9', $aCapo),
    'the check refuses an address outside the list'
);
ubep_assert_true(
    !in_array('9.9.9.9', Allowlist::entriesOf($aCapo), true),
    'and that address is absent from the entries the fingerprint covers'
);
