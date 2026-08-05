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
 * The DAG does travel in that array, but as an id, not the name the plan
 * entry carries. addPrivileges()/updatePrivileges() store data_access_group
 * straight into group_id, an int column with a foreign key to
 * redcap_data_access_groups. Passing a name there does not degrade the DAG
 * alone: non-strict SQL mode coerces the name to 0, no DAG has id 0, and the
 * foreign key refuses the whole INSERT/UPDATE — the role and the expiration
 * are lost with it, and the caller sees a bare write refusal that does not
 * say which field caused it. No framework callable resolves a DAG name to an
 * id the way getRoleId() resolves a role name — Project::getGroups() and
 * Project::getUniqueGroupNames() both go id → name, the wrong direction — so
 * resolveDag() runs its own SELECT against redcap_data_access_groups, same
 * read style as StateReader.
 *
 * Four steps, in this order, and the order matters for two different reasons:
 * both names are resolved *before* either write, so a typo or a renamed role
 * or DAG fails the whole entry cleanly instead of half-applying the rights
 * and reporting failure; the rights row is then written *before* the role,
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
    /**
     * @param int|null $dagId the DAG's id, already resolved by the caller —
     *                        argumentsFor() is pure and cannot look it up
     *                        itself, since resolution touches the database.
     *                        null means "no DAG", asserted the same as any
     *                        other absent field this array carries.
     * @return array the rights array: the DAG and the expiration, never the role
     */
    public static function argumentsFor(array $entry, ?int $dagId): array
    {
        return [
            'username' => (string) $entry['username'],
            FieldNames::DAG => self::flat($dagId),
            FieldNames::EXPIRATION => self::flat($entry['after']['expiration']),
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
            // role name, or a bad or ambiguous DAG name, must fail the entry
            // cleanly, not after the rights row has already been created or
            // updated. Once both have passed, the only failure left possible
            // is a write refusal, which cannot be pre-checked.
            $roleResolution = self::resolveRole($entry);
            if ($roleResolution['error'] !== null) {
                $plan[$index] = self::withError(
                    $entry,
                    $roleResolution['error']['code'],
                    $roleResolution['error']['message']
                );
                continue;
            }

            $dagResolution = self::resolveDag($entry);
            if ($dagResolution['error'] !== null) {
                $plan[$index] = self::withError(
                    $entry,
                    $dagResolution['error']['code'],
                    $dagResolution['error']['message']
                );
                continue;
            }

            $args = self::argumentsFor($entry, $dagResolution['dagId']);
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
                $roleResolution['roleId']
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

    /**
     * Resolves after['dag_name'] into a group_id, without writing anything.
     *
     * No framework callable does this the way ExternalModules::getRoleId()
     * does for roles — measured on the target REDCap instance (see the
     * phase-2 design spec §4) by reading Project::getGroups() and
     * Project::getUniqueGroupNames(), both of which map id → name, the
     * opposite direction. So this runs its own read, same style as
     * StateReader: a direct SELECT against redcap_data_access_groups, not a
     * prepared statement.
     *
     * redcap_data_access_groups carries no uniqueness constraint on
     * group_name (checked against the schema on the target instance) — the
     * same gap already handled for role_name — so a second matching row is
     * treated as ambiguous rather than picked from arbitrarily, the same
     * choice getRoleId() makes for roles.
     *
     * @return array{dagId: int|null, error: array{code: string, message: string}|null}
     */
    private static function resolveDag(array $entry): array
    {
        $dagName = $entry['after']['dag_name'];
        if ($dagName === null) {
            // "No DAG" is asserted later, via an empty string that REDCap
            // stores as NULL — not skipped — so there is nothing to resolve
            // here. That path is already correct on the field and stays
            // untouched.
            return ['dagId' => null, 'error' => null];
        }

        $sql = sprintf(
            "select group_id
             from redcap_data_access_groups
             where project_id = %d
               and group_name = '%s'",
            (int) $entry['project_id'],
            db_escape($dagName)
        );
        $query = db_query($sql);
        $row = $query === false ? null : db_fetch_assoc($query);

        if ($row === null) {
            return [
                'dagId' => null,
                'error' => [
                    'code' => 'DATO_DAG_INESISTENTE',
                    'message' => "DAG '$dagName' is not defined in this project",
                ],
            ];
        }

        if ($query !== false && db_fetch_assoc($query) !== null) {
            return [
                'dagId' => null,
                'error' => [
                    'code' => 'INTERNO',
                    'message' => "DAG name '$dagName' is not unique in this project",
                ],
            ];
        }

        return ['dagId' => (int) $row['group_id'], 'error' => null];
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
