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
    /**
     * The one refusal. Whoever fails either check, or both, gets exactly this:
     * a refusal that says which check failed is an oracle, and from any
     * address outside the allow list it would tell whether a secret is right.
     *
     * @return array{status:int,code:string,message:string}
     */
    public static function refusal(): array
    {
        return [
            'status' => 403,
            'code' => 'TRASPORTO_SEGRETO_RIFIUTATO',
            'message' => 'not authorised',
        ];
    }

    /**
     * Both checks, as one decision. They are both evaluated, with no
     * short-circuit, and the caller learns only the conjunction: the order of
     * the two must not show in the answer.
     */
    public static function authorise(
        ?string $providedSecret,
        ?string $expectedSecret,
        ?string $remote,
        string $allowList
    ): bool {
        $secretOk = self::checkSecret($providedSecret, $expectedSecret);
        $ipOk = self::checkIp($remote, $allowList);

        return $secretOk && $ipOk;
    }

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
