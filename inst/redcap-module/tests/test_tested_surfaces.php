<?php
// inst/redcap-module/tests/test_tested_surfaces.php
require_once __DIR__ . '/../lib/TestedSurfaces.php';

use UbepProvisioning\TestedSurfaces;

ubep_assert_true(
    TestedSurfaces::accepts('16faf46d5ab1', ['16faf46d5ab1']),
    'the only declared fingerprint matches'
);
ubep_assert_true(
    TestedSurfaces::accepts('abc123', ['zzz', 'abc123', 'yyy']),
    'a fingerprint present in a longer list matches'
);
ubep_assert_same(
    false,
    TestedSurfaces::accepts('16faf46d5ab1', ['abc123']),
    'a fingerprint absent from the list is refused'
);
ubep_assert_same(
    false,
    TestedSurfaces::accepts('16faf46d5ab1', []),
    'an empty list declares nothing tested, so nothing is accepted'
);
ubep_assert_same(
    false,
    TestedSurfaces::accepts('16faf46d5ab1', null),
    'an absent field is an empty declaration, never a pass'
);
// The hazard the field run exists to catch: with a single row in the registry
// jsonlite auto_unbox serialises the list as a scalar. in_array() with a
// non-array haystack is a fatal TypeError in PHP 8, which would answer 500
// with no JSON at all -- the client would report the module as absent.
ubep_assert_same(
    false,
    TestedSurfaces::accepts('16faf46d5ab1', '16faf46d5ab1'),
    'a bare string instead of an array is refused, not fatal'
);
ubep_assert_same(
    false,
    TestedSurfaces::accepts('16faf46d5ab1', ['16faf46d5ab1' => true]),
    'a map whose key is the fingerprint does not match: values are compared'
);
ubep_assert_same(
    false,
    TestedSurfaces::accepts('16faf46d5ab1', [16]),
    'a non string entry never matches'
);
ubep_assert_same(
    false,
    TestedSurfaces::accepts('', ['']),
    'an empty fingerprint never matches, even against an empty entry'
);
