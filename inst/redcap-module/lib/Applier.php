<?php
// inst/redcap-module/lib/Applier.php

namespace UbepProvisioning;

/**
 * The only component that writes.
 *
 * argumentsFor() is pure and separately tested: building the argument array is
 * where the silent failure lives, because an unrecognised key does not raise —
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
 * identifier, resolved from the role name first via
 * \ExternalModules\ExternalModules::getRoleId(). Two writes, in this order: the
 * rights row must exist before the role can be written onto it.
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
            // is an UPDATE, so on a creation the role would silently attach to
            // nothing if tried first.
            $plan[$index] = self::writeRole($entry);
        }

        return $plan;
    }

    /**
     * Resolves after['role_name'] into a role_id and writes it.
     *
     * A role name that does not exist, or that is ambiguous in this project
     * (REDCap does not enforce uniqueness on role_name, only on
     * unique_role_name), must not become an uncaught exception: that would be a
     * PHP fatal at the endpoint, a non-JSON response for the client, and no
     * report for entries already written earlier in the same batch. Both are
     * translated into this entry's own error instead.
     */
    private static function writeRole(array $entry): array
    {
        $roleName = $entry['after']['role_name'];
        $roleId = null;

        if ($roleName !== null) {
            try {
                $roleId = \ExternalModules\ExternalModules::getRoleId(
                    $entry['project_id'],
                    $roleName
                );
            } catch (\Throwable $e) {
                return self::withError(
                    $entry,
                    'INTERNO',
                    "role name '$roleName' is not unique in this project: "
                        . $e->getMessage()
                );
            }

            if ($roleId === null) {
                return self::withError(
                    $entry,
                    'DATO_RUOLO_INESISTENTE',
                    "role '$roleName' is not defined in this project"
                );
            }
        }

        // $roleId stays null here for "no role", and updateUserRoleMapping
        // accepts that: it treats any non-integer role_id as SQL NULL, so the
        // absence is asserted rather than skipped.
        $written = \UserRights::updateUserRoleMapping(
            $entry['project_id'],
            $entry['username'],
            $roleId
        );

        if ($written === false) {
            return self::withError(
                $entry,
                'INTERNO',
                'the role write was refused by REDCap'
            );
        }

        return $entry;
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
            if ($entry['outcome'] === 'noop') {
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
