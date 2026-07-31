<?php

namespace UbepProvisioning;

/**
 * The version gate: the only place in the codebase that compares versions.
 *
 * The window is expressed in majors rather than full versions. Comparing majors
 * as integers also removes the lexicographic trap entirely, because 17.0.10 and
 * 17.0.6 share a major and the gate never has to order them.
 *
 * The major is a statement of policy — which versions we choose to support and
 * test on. It is not a guarantee of compatibility: measured across the fleet,
 * the surface this channel depends on changes within major 14 and stays
 * identical across 14.7.5, 15.8.x and 17.0.6. Compatibility is checked
 * separately, by the fingerprint in Surface.
 */
class VersionGate
{
    public const BELOW = 'sotto_minimo';
    public const TESTED = 'collaudata';
    public const UNTESTED = 'non_collaudata';

    public static function majorOf(string $version): int
    {
        return (int) explode('.', trim($version))[0];
    }

    public static function classify(
        string $version,
        int $floorMajor,
        int $ceilingMajor
    ): string {
        $major = self::majorOf($version);

        if ($major < $floorMajor) {
            return self::BELOW;
        }
        if ($major > $ceilingMajor) {
            return self::UNTESTED;
        }

        return self::TESTED;
    }
}
