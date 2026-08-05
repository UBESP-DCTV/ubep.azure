<?php
// inst/redcap-module/lib/TestProjects.php

namespace UbepProvisioning;

/**
 * The phase two brake: writes are confined to designated test projects.
 *
 * An empty or unconfigured list denies everything, like the IP allow list does.
 * A brake that opens when it is not configured is not a brake.
 *
 * There is deliberately no wildcard. "Put `all` while I test" is the shortcut
 * that would come to mind, and it is how this restraint would stop existing
 * without anyone removing a line of code. The removal is meant to happen once,
 * visibly, when the registry says conformance has been earned.
 */
class TestProjects
{
    public static function allows(int $projectId, string $list): bool
    {
        $entries = preg_split(
            '/[\s,]+/',
            trim($list),
            -1,
            PREG_SPLIT_NO_EMPTY
        );
        if ($entries === false || $entries === []) {
            return false;
        }

        foreach ($entries as $entry) {
            if (ctype_digit($entry) && (int) $entry === $projectId) {
                return true;
            }
        }

        return false;
    }
}
