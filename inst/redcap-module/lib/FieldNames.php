<?php

namespace UbepProvisioning;

/**
 * API names of the three fields this channel governs.
 *
 * Measured, not assumed, on REDCap 17.0.6 (2026-08-01) by reading
 * UserRights::getApiUserPrivilegesAttr() and tracing how the ExternalModules
 * framework's Project::addUser()/setRights()/setRoleForUser() feed
 * UserRights::addPrivileges()/updatePrivileges()/updateUserRoleMapping().
 * Hard-coding a guess here would be the exact failure the conformance test
 * exists to catch, moved one layer earlier where nothing looks at it.
 *
 * getApiUserPrivilegesAttr() returns one array that mixes two shapes: entries
 * with no explicit key (identity fields, where the API name equals the
 * column name) get a positional integer key; the remapped entries carry the
 * API name as the array *key* and the column name as the array *value*.
 * addPrivileges()/updatePrivileges() always read the caller's $rights array
 * using the array *value* as the lookup key, identity or not — so membership
 * of an API name in this map is in_array($name, $map, true), never
 * array_key_exists($name, $map). Getting that backwards is exactly the sort
 * of thing that would have made the conformance test pass against the wrong
 * assumption.
 *
 * DAG and EXPIRATION are asserted this way, inside the one $rights array
 * passed to updatePrivileges(). ROLE is not: 'role_id' does not appear
 * anywhere in getApiUserPrivilegesAttr() — neither as key nor as value — so
 * it never reaches updatePrivileges() through $rights at all. Role
 * assignment is a separate write: UserRights::updateUserRoleMapping(
 * $project_id, $username, $role_id) (wrapped by the framework as
 * Project::setRoleForUser($roleName, $username)), which takes $role_id as a
 * positional int argument resolved from a role *name* via
 * ExternalModules::getRoleId($project_id, $roleName). Task 4's Applier has to
 * be built around two calls, not one array with three keys.
 */
class FieldNames
{
    public const DAG = 'data_access_group';
    public const EXPIRATION = 'expiration';
    public const ROLE = 'role_id';

    /** @return string[] the API names of the three fields this channel governs */
    public static function governed(): array
    {
        return [self::ROLE, self::DAG, self::EXPIRATION];
    }
}
