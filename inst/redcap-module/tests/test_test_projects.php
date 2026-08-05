<?php
// inst/redcap-module/tests/test_test_projects.php
require_once __DIR__ . '/../lib/TestProjects.php';

use UbepProvisioning\TestProjects;

ubep_assert_true(TestProjects::allows(27, '27'), 'single exact id');
ubep_assert_true(
    TestProjects::allows(27, "16\n27\n31"),
    'id present in a newline separated list'
);
ubep_assert_true(
    TestProjects::allows(27, '16, 27 ,31'),
    'commas and stray spaces are tolerated'
);
ubep_assert_same(false, TestProjects::allows(28, '27'), 'id absent');
ubep_assert_same(
    false,
    TestProjects::allows(27, ''),
    'an empty list denies everything'
);
ubep_assert_same(
    false,
    TestProjects::allows(27, '   '),
    'a blank list denies everything'
);
ubep_assert_same(
    false,
    TestProjects::allows(2, '27'),
    'no substring matching: 2 is not part of 27'
);
ubep_assert_same(
    false,
    TestProjects::allows(27, '27abc'),
    'a non numeric entry never matches'
);
ubep_assert_same(
    false,
    TestProjects::allows(0, 'all'),
    'no wildcard: the list holds ids and nothing else'
);
