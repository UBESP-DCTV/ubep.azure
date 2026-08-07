<?php

namespace UbepProvisioning;

/**
 * The module's own IP allow list: how it is parsed, and its fingerprint.
 *
 * Reports that the perimeter changed without reporting what it is. The digest
 * travels to the caller and into a log; the addresses never do. The client
 * keeps no expected value and alarms on the change between two runs, which is
 * what turns the falling of the development entry into an observed event
 * instead of one taken on trust — and which also avoids storing an expected
 * digest anywhere, since a digest of IPv4 addresses is small enough to
 * enumerate.
 *
 * Parsing lives here and `Auth::checkIp()` uses it, deliberately: if the
 * fingerprint normalised entries one way and the check split them another,
 * two settings that behave identically could report different fingerprints —
 * a standing false alarm — or two that behave differently could report the
 * same one, which is the alarm that matters going missing. One parser, one
 * truth.
 */
class Allowlist
{
    /** The setting key, part of the contract with `config.json`. */
    public const SETTING_KEY = 'ip-allow-list';

    /**
     * The entries the check will actually compare against, sorted.
     *
     * @return string[]
     */
    public static function entriesOf(string $rawSetting): array
    {
        $entries = preg_split(
            '/[\s,]+/',
            trim($rawSetting),
            -1,
            PREG_SPLIT_NO_EMPTY
        );

        if ($entries === false) {
            return [];
        }

        sort($entries, SORT_STRING);

        return $entries;
    }

    public static function fingerprintFrom(string $rawSetting): string
    {
        return substr(md5(implode('|', self::entriesOf($rawSetting))), 0, 12);
    }

    /**
     * Read the setting off the module and fingerprint it.
     *
     * The key name is read from one constant rather than typed at each call:
     * a typo would silently yield the empty-list fingerprint on every
     * instance, and every digest assertion would stay green.
     *
     * @param object $module The REDCap module object, or any object exposing
     *   `getSystemSetting()`. Typed loosely so the reading can be exercised
     *   without REDCap.
     */
    public static function fingerprintOf(object $module): string
    {
        return self::fingerprintFrom(
            (string) $module->getSystemSetting(self::SETTING_KEY)
        );
    }
}
