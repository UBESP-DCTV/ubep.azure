<?php
// Minimal test runner for the module: no external dependencies.
//
// PHPUnit is deliberately not used. The module must stay installable by
// copying a directory into REDCap's modules/, and a development dependency
// inside an R package would be weight without a return. Exit code is 1 on
// failure, so CI needs nothing else.

$GLOBALS['ubep_failures'] = 0;
$GLOBALS['ubep_assertions'] = 0;

function ubep_assert_same($expected, $actual, string $message): void
{
    $GLOBALS['ubep_assertions']++;
    if ($expected === $actual) {
        return;
    }
    $GLOBALS['ubep_failures']++;
    fwrite(STDERR, sprintf(
        "FAIL %s\n  expected: %s\n  actual:   %s\n",
        $message,
        var_export($expected, true),
        var_export($actual, true)
    ));
}

function ubep_assert_true(bool $condition, string $message): void
{
    ubep_assert_same(true, $condition, $message);
}

$files = glob(__DIR__ . '/test_*.php');
sort($files, SORT_STRING);
foreach ($files as $file) {
    require $file;
}

printf(
    "\n%d assertions, %d failures\n",
    $GLOBALS['ubep_assertions'],
    $GLOBALS['ubep_failures']
);
exit($GLOBALS['ubep_failures'] > 0 ? 1 : 0);
