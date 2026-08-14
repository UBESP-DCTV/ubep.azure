<?php
// inst/redcap-module/tests/test_dry_run.php
//
// The guard that keeps a simulation able to refuse.
//
// Measured on the field on 2026-08-14: a request naming a role that does not
// exist came back from a dry run as `creato`, with the role echoed into
// `after` as if it were feasible. The cause was structural rather than a bug:
// the plan is the echo of the request, and the code that resolves names --
// and so the code that can refuse them -- lived inside the branch a dry run
// skips. The whole point of the simulated phase is that referents read what
// would happen, and what they read was a plan a real write would reject.
//
// api.php is the one file of the module no test loads, because loading it
// would ask for REDCap. So this is checked by reading it, like test_api.php,
// and it is coarse on purpose: a false red costs a minute, a false green
// costs a rollout phase that cannot warn about anything.

$ubepDryRunSource = file_get_contents(__DIR__ . '/../api.php');

$ubepResolveAt = strpos($ubepDryRunSource, 'Applier::resolveNames(');
$ubepWriteBranchAt = strrpos($ubepDryRunSource, 'if (!$dryRun)');

ubep_assert_true(
    $ubepResolveAt !== false,
    'api.php resolves the names a write would need'
);

ubep_assert_true(
    $ubepWriteBranchAt !== false,
    'api.php still guards its writes behind a dry-run branch'
);

// The one that matters, and it is a statement about position because the
// property is about position: the resolution has to happen before the branch
// that a simulation does not enter. Moving the call one line down, inside the
// branch, restores exactly the defect this test was written for -- and that
// move leaves no other trace.
ubep_assert_true(
    $ubepResolveAt !== false
        && $ubepWriteBranchAt !== false
        && $ubepResolveAt < $ubepWriteBranchAt,
    'the names are resolved before the branch that writes, so a dry run refuses what a write would refuse'
);
