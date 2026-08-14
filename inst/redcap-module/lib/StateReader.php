<?php

namespace UbepProvisioning;

/**
 * Reads the real state of project rights.
 *
 * The DAG assignment is read from redcap_user_rights.group_id, not from
 * redcap_data_access_groups_users. The spike established that the modern path
 * writes the first while the second stays empty; the historical mechanism wrote
 * both. Reading the wrong one reports every user as having no DAG, silently.
 *
 * The user_rights permission has the same shape of trap and it is worth naming
 * separately, because the two tables are not two paths to the same value: a
 * user with a role inherits the role's permissions and the columns on their own
 * row do not govern, while a user without a role carries their own. Reading
 * only one table reports the wrong answer for everybody in the other half, and
 * does it silently. Both are read here and the resolution is a pure method, so
 * it can be tested without a REDCap instance.
 *
 * This class reports the raw REDCap value and never a verdict. What counts as
 * "may manage users" is policy, it lives with the caller, and a module that
 * decided it here would be answering a question nobody asked it.
 */
class StateReader
{
    /**
     * @param array $pairs list of ['username' => string, 'project_id' => int];
     *                     an empty list means "the whole instance", which is
     *                     what the audit needs
     * @return array one entry per (user, project) row
     */
    public static function read(array $pairs): array
    {
        $where = '';
        if ($pairs !== []) {
            $clauses = [];
            foreach ($pairs as $pair) {
                $clauses[] = sprintf(
                    "(ur.project_id = %d and ur.username = '%s')",
                    (int) $pair['project_id'],
                    db_escape((string) $pair['username'])
                );
            }
            $where = 'where ' . implode(' or ', $clauses);
        }

        $sql = "select ur.username, ur.project_id, ur.expiration,
                       ur.group_id, ur.role_id,
                       dag.group_name, role.role_name,
                       ur.user_rights as own_user_rights,
                       role.user_rights as role_user_rights
                from redcap_user_rights ur
                left join redcap_data_access_groups dag
                       on dag.group_id = ur.group_id
                left join redcap_user_roles role
                       on role.role_id = ur.role_id
                $where
                order by ur.project_id, ur.username";

        $query = db_query($sql);
        if ($query === false) {
            return [];
        }

        $rows = [];
        while ($row = db_fetch_assoc($query)) {
            $rows[] = [
                'username' => $row['username'],
                'project_id' => (int) $row['project_id'],
                'role_name' => self::orNull($row['role_name']),
                'dag_name' => self::orNull($row['group_name']),
                'expiration' => self::orNull($row['expiration']),
                'user_rights' => self::effectiveUserRights($row),
            ];
        }

        return $rows;
    }

    /**
     * The user_rights permission that governs this row, role first.
     *
     * Null means "could not be read", never "no permission": a role_id that
     * joins to nothing is a role deleted underneath the row, and a caller that
     * read that as a zero would refuse a person whose rights were never
     * measured. The two answers ask for different actions, so they stay
     * distinguishable here and the caller decides which way to fail.
     *
     * @param array $row one fetched row
     * @return int|null the raw REDCap value, or null when it cannot be read
     */
    public static function effectiveUserRights(array $row): ?int
    {
        $roleId = $row['role_id'] ?? null;
        $hasRole = !($roleId === null || $roleId === '');

        $value = $hasRole
            ? ($row['role_user_rights'] ?? null)
            : ($row['own_user_rights'] ?? null);

        // An empty string is what a missing column reads as through some
        // drivers, and it is not a zero: treated as unread, like null.
        if ($value === null || $value === '') {
            return null;
        }

        return (int) $value;
    }

    /** Empty string and null are the same absence to the client. */
    private static function orNull(?string $value): ?string
    {
        return ($value === null || $value === '') ? null : $value;
    }
}
