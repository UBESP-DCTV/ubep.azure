<?php

namespace UbepProvisioning;

/**
 * Reads the real state of project rights.
 *
 * The DAG assignment is read from redcap_user_rights.group_id, not from
 * redcap_data_access_groups_users. The spike established that the modern path
 * writes the first while the second stays empty; the historical mechanism wrote
 * both. Reading the wrong one reports every user as having no DAG, silently.
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
                       dag.group_name, role.role_name
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
            ];
        }

        return $rows;
    }

    /** Empty string and null are the same absence to the client. */
    private static function orNull(?string $value): ?string
    {
        return ($value === null || $value === '') ? null : $value;
    }
}
