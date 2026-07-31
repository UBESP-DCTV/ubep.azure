<?php

namespace UbepProvisioning;

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

        $entries = preg_split(
            '/[\s,]+/',
            trim($allowList),
            -1,
            PREG_SPLIT_NO_EMPTY
        );
        if ($entries === false || $entries === []) {
            return false;
        }

        // Exact match only. A substring check would accept 10.0.0.70 from an
        // allow list holding 10.0.0.7.
        return in_array($remote, $entries, true);
    }
}
