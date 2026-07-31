<?php
require_once __DIR__ . '/../lib/Auth.php';

use UbepProvisioning\Auth;

// --- shared secret ---------------------------------------------------------
ubep_assert_true(Auth::checkSecret('s3cret', 's3cret'), 'matching secret');
ubep_assert_same(false, Auth::checkSecret('wrong', 's3cret'), 'wrong secret');
ubep_assert_same(false, Auth::checkSecret(null, 's3cret'), 'missing secret');
ubep_assert_same(false, Auth::checkSecret('s3cret', null), 'unconfigured secret');
ubep_assert_same(false, Auth::checkSecret('', ''), 'empty secret never passes');
ubep_assert_same(false, Auth::checkSecret(null, null), 'both absent never passes');

// An unconfigured module must not become an open door: empty expected secret
// denies, it does not match an empty header.
ubep_assert_same(
    false,
    Auth::checkSecret('', 's3cret'),
    'empty provided secret is refused'
);
ubep_assert_same(
    false,
    Auth::checkSecret('s3cret ', 's3cret'),
    'no trimming: a trailing space makes it a different secret'
);
ubep_assert_same(
    false,
    Auth::checkSecret('S3CRET', 's3cret'),
    'comparison is case sensitive'
);
ubep_assert_same(
    false,
    Auth::checkSecret('s3cre', 's3cret'),
    'a prefix of the secret is refused'
);

// --- ip allow list ---------------------------------------------------------
ubep_assert_true(Auth::checkIp('10.0.0.7', '10.0.0.7'), 'single exact ip');
ubep_assert_true(
    Auth::checkIp('10.0.0.7', "192.0.2.1\n10.0.0.7\n198.51.100.4"),
    'ip present in a newline separated list'
);
ubep_assert_true(
    Auth::checkIp('10.0.0.7', '192.0.2.1, 10.0.0.7 ,198.51.100.4'),
    'commas and stray spaces are tolerated'
);
ubep_assert_true(
    Auth::checkIp('10.0.0.7', "  10.0.0.7  \n\n"),
    'blank lines and padding are tolerated'
);
ubep_assert_same(
    false,
    Auth::checkIp('10.0.0.8', '10.0.0.7'),
    'ip absent from the list'
);
ubep_assert_same(false, Auth::checkIp(null, '10.0.0.7'), 'missing remote ip');
ubep_assert_same(false, Auth::checkIp('', '10.0.0.7'), 'empty remote ip');
ubep_assert_same(
    false,
    Auth::checkIp('10.0.0.7', ''),
    'empty allow list denies everything'
);
ubep_assert_same(
    false,
    Auth::checkIp('10.0.0.7', "  \n  "),
    'blank allow list denies everything'
);

// No prefix matching: the easy mistake is a substring check, and 10.0.0.70
// would then be accepted by an allow list containing 10.0.0.7.
ubep_assert_same(
    false,
    Auth::checkIp('10.0.0.70', '10.0.0.7'),
    'no prefix matching on the right'
);
ubep_assert_same(
    false,
    Auth::checkIp('110.0.0.7', '10.0.0.7'),
    'no prefix matching on the left'
);
