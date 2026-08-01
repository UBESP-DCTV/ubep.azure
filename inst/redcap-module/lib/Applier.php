<?php
// inst/redcap-module/lib/Applier.php

namespace UbepProvisioning;

/**
 * The only component that writes.
 *
 * argumentsFor() is pure and separately tested: building the argument array is
 * where the silent failure lives, because an unrecognized key does not raise —
 * it falls to the default branch and becomes 0, denying a permission nobody
 * asked to deny. Keeping it pure is what lets that be tested without REDCap.
 *
 * Every field it carries is asserted on every write, never a delta. That is not
 * a style choice: updatePrivileges skips fields you do not pass, except the DAG,
 * which it includes anyway and sets to NULL when omitted. A delta would revoke
 * DAGs on every renewal and report success.
 *
 * The role does not travel in that array. role_id is not part of the privileges
 * map, so it is asserted by a separate call — UserRights::updateUserRoleMapping,
 * global namespace, same as addPrivileges/updatePrivileges — which wants an
 * identifier, resolved from the role name via
 * \ExternalModules\ExternalModules::getRoleId().
 *
 * Three steps, in this order, and the order matters for two different reasons:
 * the name is resolved *before* either write, so a typo or a renamed role
 * fails the whole entry cleanly instead of half-applying the rights and
 * reporting failure; the rights row is then written *before* the role,
 * because updateUserRoleMapping is an UPDATE and the row a creation writes
 * has to exist first.
 *
 * Measured on the target REDCap instance (see the phase-2 design spec §4 for
 * which one and when): addPrivileges()/updatePrivileges() take the rights of
 * one (project, user) pair as a single associative row — not a list of rows —
 * and both are declared bool|array, returning false on a failed write and an
 * array only when their optional ACG-compliance check is turned on, which this
 * class never does, so a plain `=== false` check is exact.
 * updateUserRoleMapping() is declared bool|array on the same terms, and treats
 * any non-integer role_id, null included, as SQL NULL — so "no role" is
 * asserted, not skipped.
 */
class Applier
{
    /** @return array the rights array: the DAG and the expiration, never the role */
    public static function argumentsFor(array $entry): array
    {
        $after = $entry['after'];

        return [
            'username' => (string) $entry['username'],
            FieldNames::DAG => self::flat($after['dag_name']),
            FieldNames::EXPIRATION => self::flat($after['expiration']),
        ];
    }

    /**
     * Which write an outcome calls for, or none.
     *
     * Pure so the offline suite can hold it: sending a creation to the update
     * function writes nothing, raises nothing and reports success, which is the
     * one failure mode no test that needs an instance would catch in time.
     *
     * @return string|null 'create', 'update', or null when nothing is written
     */
    public static function writeKindFor(string $outcome): ?string
    {
        switch ($outcome) {
            case 'creato':
                return 'create';
            case 'aggiornato':
                return 'update';
            default:
                return null;
        }
    }

    /** Absent is asserted as empty, never omitted. */
    private static function flat($value): string
    {
        return $value === null ? '' : (string) $value;
    }

    /**
     * @param array $plan entries produced by Planner::planApply()
     * @return array the same entries, with errors filled in where a write failed
     */
    public static function apply(array $plan): array
    {
        foreach ($plan as $index => $entry) {
            $kind = self::writeKindFor($entry['outcome']);
            if ($kind === null) {
                continue;
            }

            // Resolved before either write touches REDCap: a bad or ambiguous
            // role name must fail the entry cleanly, not after the rights row
            // has already been created or updated. Once this step has passed,
            // the only failure left possible is a write refusal, which cannot
            // be pre-checked.
            $resolution = self::resolveRole($entry);
            if ($resolution['error'] !== null) {
                $plan[$index] = self::withError(
                    $entry,
                    $resolution['error']['code'],
                    $resolution['error']['message']
                );
                continue;
            }

            $args = self::argumentsFor($entry);
            $written = $kind === 'create'
                ? \UserRights::addPrivileges($entry['project_id'], $args)
                : \UserRights::updatePrivileges($entry['project_id'], $args);

            if ($written === false) {
                $plan[$index] = self::withError(
                    $entry,
                    'INTERNO',
                    'the rights write was refused by REDCap'
                );
                continue;
            }

            // Only after the rights row is known to exist: updateUserRoleMapping
            // is an UPDATE, so on a creation the role would attach to nothing if
            // written first.
            $written = \UserRights::updateUserRoleMapping(
                $entry['project_id'],
                $entry['username'],
                $resolution['roleId']
            );

            if ($written === false) {
                $plan[$index] = self::withError(
                    $entry,
                    'INTERNO',
                    'the role write was refused by REDCap'
                );
            }
        }

        return $plan;
    }

    /**
     * Resolves after['role_name'] into a role_id, without writing anything.
     *
     * A role name that does not exist, or that is ambiguous in this project
     * (REDCap does not enforce uniqueness on role_name — measured, not the
     * full schema), must not become an uncaught exception: that would be a PHP
     * fatal at the endpoint, a non-JSON response for the client, and no report
     * for entries already written earlier in the same batch. Both are
     * translated into an error shape the caller can attach to the entry
     * instead, without hardcoding which cause it was: getRoleId() throws for
     * one reason on the instance this was measured against, but the message
     * carries the real cause rather than asserting it.
     *
     * @return array{roleId: int|null, error: array{code: string, message: string}|null}
     */
    private static function resolveRole(array $entry): array
    {
        $roleName = $entry['after']['role_name'];
        if ($roleName === null) {
            // "No role" is itself asserted later, via a null role_id — not
            // skipped — so there is nothing to resolve here.
            return ['roleId' => null, 'error' => null];
        }

        try {
            $roleId = \ExternalModules\ExternalModules::getRoleId(
                $entry['project_id'],
                $roleName
            );
        } catch (\Throwable $e) {
            return [
                'roleId' => null,
                'error' => [
                    'code' => 'INTERNO',
                    'message' => "could not resolve role name '$roleName': "
                        . $e->getMessage(),
                ],
            ];
        }

        if ($roleId === null) {
            return [
                'roleId' => null,
                'error' => [
                    'code' => 'DATO_RUOLO_INESISTENTE',
                    'message' => "role '$roleName' is not defined in this project",
                ],
            ];
        }

        // getRoleId() returns a column value straight out of fetch_assoc(),
        // whose PHP type the driver does not guarantee to be int. Cast here so
        // a numeric string never reaches updateUserRoleMapping(), where
        // isinteger() is strict about type and would silently treat it as "no
        // role" instead of the id it is.
        return ['roleId' => (int) $roleId, 'error' => null];
    }

    private static function withError(array $entry, string $code, string $message): array
    {
        $entry['outcome'] = 'errore';
        $entry['errors'][] = ['code' => $code, 'message' => $message];

        return $entry;
    }

    /**
     * @param array $plan entries produced by Planner::planRevoke()
     * @return array the same entries, with errors filled in where a write failed
     */
    public static function revoke(array $plan): array
    {
        foreach ($plan as $index => $entry) {
            // Filtered on 'revocato', the one outcome that calls for a write
            // -- not on "anything but noop". TestProjects can mark an
            // out-of-scope entry 'errore' before Applier ever sees it (see
            // api.php); a filter on non-noop would let that refusal reach
            // removePrivileges() the same as a real revocation, deleting the
            // rights while reporting a refusal.
            if ($entry['outcome'] !== 'revocato') {
                continue;
            }

            // removePrivileges() takes the username as a single string, fed
            // straight into db_escape(); measured on the target instance (see
            // the phase-2 design spec §4) — a list would fail db_escape()'s
            // string type check before any SQL ran.
            $result = \UserRights::removePrivileges(
                $entry['project_id'],
                $entry['username']
            );

            if ($result === false) {
                $plan[$index] = self::withError(
                    $entry,
                    'INTERNO',
                    'the removal was refused by REDCap'
                );
            }
        }

        return $plan;
    }
}
