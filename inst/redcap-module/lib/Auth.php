<?php

namespace UbepProvisioning;

require_once __DIR__ . '/Allowlist.php';

/**
 * The channel's authorisation.
 *
 * Not a layer on top of REDCap's own checks: the functions this module calls —
 * addPrivileges, updatePrivileges, removePrivileges and their read
 * counterparts — perform no authorisation of their own, as the spike verified.
 * These two checks, plus TLS, are the whole of it. Treat them accordingly.
 */
class Auth
{
    public static function checkSecret(
        ?string $provided,
        ?string $expected
    ): bool {
        if ($provided === null || $expected === null) {
            return false;
        }

        // An unconfigured module must not become an open door, so an empty
        // expected secret denies rather than matching an empty header.
        if ($provided === '' || $expected === '') {
            return false;
        }

        // Constant time: a timing oracle on a shared secret costs nothing to
        // avoid, and the endpoint is reachable without authentication.
        return hash_equals($expected, $provided);
    }

    public static function checkIp(?string $remote, string $allowList): bool
    {
        if ($remote === null || $remote === '') {
            return false;
        }

        // Parsed by Allowlist, which also fingerprints it. Two parsers would
        // let the reported fingerprint and the enforced list drift apart, and
        // the drift would show up as either a standing false alarm or a real
        // change going unreported.
        $entries = Allowlist::entriesOf($allowList);
        if ($entries === []) {
            return false;
        }

        // Exact match only. A substring check would accept 10.0.0.70 from an
        // allow list holding 10.0.0.7.
        return in_array($remote, $entries, true);
    }
}
