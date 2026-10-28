<?php

namespace UbepProvisioning;

/**
 * Reads the access dates of local REDCap accounts.
 *
 * The values are raw: the dates come back as REDCap stored them, converted only
 * to UTC, and no verdict is given here. Whether an account counts as "never
 * entered" is policy and lives with the caller.
 *
 * A failed read is null and never an empty list, unlike StateReader::read().
 * An empty list here would mean "none of these accounts exist", which the
 * caller would report as people who never logged in; a database that did not
 * answer says nothing about anybody.
 *
 * Names are compared trimmed and lowercased (strtolower, byte-wise: usernames
 * are ASCII UPNs), the same comparison the R client makes with trimws() and
 * tolower() when it drops duplicates.
 */
class AccountReader
{
    /** Names accepted per call; the caller splits longer lists. */
    const LIMIT = 500;

    /** The date columns read, and returned under the same names. */
    private const DATE_COLUMNS = [
        'user_creation',
        'user_firstvisit',
        'user_lastlogin',
        'user_firstactivity',
        'user_lastactivity',
    ];

    /**
     * @param array $usernames names to look up, as the caller wrote them
     * @return array|null one entry per name (see shape()), or null when the
     *                    query failed
     */
    public static function read(array $usernames): ?array
    {
        // `in ()` is a syntax error in MySQL, and zero names have zero rows.
        if ($usernames === []) {
            return [];
        }

        $query = db_query(self::selectSql($usernames, 'db_escape'));
        if ($query === false) {
            return null;
        }

        $rows = [];
        while ($row = db_fetch_assoc($query)) {
            $rows[] = $row;
        }

        return self::shape($usernames, $rows, date_default_timezone_get());
    }

    /**
     * The select for these names, normalized and without repeats.
     *
     * @param array    $usernames names as the caller wrote them
     * @param callable $escape    string escaper (db_escape() in production)
     */
    public static function selectSql(array $usernames, callable $escape): string
    {
        $quoted = [];
        foreach (array_keys(self::firstSpellings($usernames)) as $name) {
            $quoted[] = "'" . $escape($name) . "'";
        }

        return 'select username, ' . implode(', ', self::DATE_COLUMNS)
            . ' from redcap_user_information where username in ('
            . implode(', ', $quoted) . ')';
    }

    /**
     * Pairs each requested name with its row, in the order asked.
     *
     * @param array  $usernames names as the caller wrote them
     * @param array  $rows      fetched rows of redcap_user_information
     * @param string $timezone  zone the server wrote the dates in
     * @return array one entry per distinct name: username (as asked), exists,
     *               and the five dates as UTC 'Y-m-d\TH:i:s\Z' or null
     */
    public static function shape(array $usernames, array $rows, string $timezone): array
    {
        $zone = new \DateTimeZone($timezone);

        $byName = [];
        foreach ($rows as $row) {
            $byName[self::normalize((string) $row['username'])] = $row;
        }

        $shaped = [];
        foreach (self::firstSpellings($usernames) as $key => $asked) {
            $row = $byName[$key] ?? null;
            $entry = ['username' => $asked, 'exists' => $row !== null];
            foreach (self::DATE_COLUMNS as $column) {
                $entry[$column] = $row === null
                    ? null
                    : self::toUtc($row[$column] ?? null, $zone);
            }
            $shaped[] = $entry;
        }

        return $shaped;
    }

    private static function normalize(string $name): string
    {
        return strtolower(trim($name));
    }

    /** @return array normalized name => first spelling asked, in asked order */
    private static function firstSpellings(array $usernames): array
    {
        $first = [];
        foreach ($usernames as $name) {
            $key = self::normalize((string) $name);
            if (!isset($first[$key])) {
                $first[$key] = (string) $name;
            }
        }

        return $first;
    }

    /**
     * Null, an empty string and MySQL's zero date are the same absence: a
     * zero date converted would become a date in year 0 or a PHP error printed
     * ahead of the JSON.
     */
    private static function toUtc($value, \DateTimeZone $zone): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        $value = (string) $value;
        if (strncmp($value, '0000-00-00', 10) === 0) {
            return null;
        }

        try {
            $date = new \DateTime($value, $zone);
        } catch (\Exception $e) {
            return null;
        }

        return $date->setTimezone(new \DateTimeZone('UTC'))
            ->format('Y-m-d\TH:i:s\Z');
    }
}
