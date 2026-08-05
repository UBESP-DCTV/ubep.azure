<?php
// inst/redcap-module/lib/TestedSurfaces.php

namespace UbepProvisioning;

/**
 * The surface handshake: does the caller consider this instance's surface one
 * it has tested against?
 *
 * The module knows what it is -- it computes its own fingerprint at runtime --
 * but not what has been tested: that registry lives in the R package. So the
 * caller declares, and this compares. Qualifying a new surface therefore costs
 * one row in that registry and no redeployment of this module to any server.
 *
 * An absent, empty or malformed declaration accepts nothing, like the IP allow
 * list and like the test project list before it. A brake that opens when it is
 * not configured is not a brake -- and here that direction matters twice over,
 * because the declaration arrives from a JSON body and may be anything at all.
 * Nothing here may raise: this runs on a page that has already sent its
 * headers, so a TypeError would print ahead of the JSON body and the client,
 * which recognises a response by its shape, would report the module absent.
 *
 * This protects against drift, not against a hostile caller: whoever holds the
 * secret reads the current fingerprint from any `state` and can declare it
 * back. It is not an access control, and it does not replace the three
 * presidia. It catches the case that actually happens -- an instance upgraded
 * underneath a job that keeps running.
 */
class TestedSurfaces
{
    public static function accepts(string $fingerprint, $declared): bool
    {
        if ($fingerprint === '' || !is_array($declared)) {
            return false;
        }

        foreach ($declared as $entry) {
            if (is_string($entry) && $entry === $fingerprint) {
                return true;
            }
        }

        return false;
    }
}
