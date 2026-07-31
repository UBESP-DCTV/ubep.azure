<?php

namespace UbepProvisioning;

/**
 * Stand-in for a REDCap class, so signaturesOf() can be tested without REDCap.
 *
 * Not named test_*.php on purpose: the runner globs that pattern, and this file
 * holds no assertions.
 */
class SurfaceFixture
{
    public static function fixtureMethod($a, $b = null): string
    {
        return '';
    }

    public static function typedMethod(int $n, ?string $s = null): bool|array
    {
        return true;
    }
}
