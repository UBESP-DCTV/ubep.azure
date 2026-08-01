<?php
// inst/redcap-module/lib/Planner.php

namespace UbepProvisioning;

/**
 * Computes what an operation would do, without being able to do it.
 *
 * This class deliberately does not name the three write functions of
 * UserRights. That is the whole guarantee behind dry_run: the simulation
 * does not write because the code that computes it cannot write, rather than
 * because a branch decided not to. A test scans this file for those three
 * names and fails if one appears.
 *
 * Like Surface, it receives what it needs already read instead of reading it,
 * so it is testable without a REDCap instance.
 */
class Planner
{
    private const FIELDS = ['role_name', 'dag_name', 'expiration'];

    public static function planApply(array $requests, array $current): array
    {
        $index = self::indexOf($current);
        $out = [];

        foreach ($requests as $request) {
            $key = self::keyOf($request);
            $have = $index[$key] ?? null;
            $before = $have === null ? self::absent() : self::shape($have);
            $after = self::shape($request);

            if ($have === null) {
                $outcome = 'creato';
            } elseif ($before === $after) {
                $outcome = 'noop';
            } else {
                $outcome = 'aggiornato';
            }

            $out[] = self::entry($request, $outcome, $before, $after);
        }

        return $out;
    }

    public static function planRevoke(array $requests, array $current): array
    {
        $index = self::indexOf($current);
        $out = [];

        foreach ($requests as $request) {
            $have = $index[self::keyOf($request)] ?? null;
            $before = $have === null ? self::absent() : self::shape($have);

            $out[] = self::entry(
                $request,
                $have === null ? 'noop' : 'revocato',
                $before,
                self::absent()
            );
        }

        return $out;
    }

    private static function entry(
        array $request,
        string $outcome,
        array $before,
        array $after
    ): array {
        return [
            'username' => (string) $request['username'],
            'project_id' => (int) $request['project_id'],
            'outcome' => $outcome,
            'before' => $before,
            'after' => $after,
            'errors' => [],
        ];
    }

    private static function keyOf(array $row): string
    {
        // a control character cannot occur in a UPN or in an id, so two
        // different pairs cannot collide on the same key
        return $row['username'] . "\r" . (int) $row['project_id'];
    }

    private static function indexOf(array $rows): array
    {
        $index = [];
        foreach ($rows as $row) {
            $index[self::keyOf($row)] = $row;
        }

        return $index;
    }

    /** An absent value, an unset field and null all mean "not set". */
    private static function shape(array $row): array
    {
        $out = [];
        foreach (self::FIELDS as $field) {
            $value = $row[$field] ?? null;
            $out[$field] = ($value === null || $value === '')
                ? null
                : (string) $value;
        }

        return $out;
    }

    private static function absent(): array
    {
        return array_fill_keys(self::FIELDS, null);
    }
}
