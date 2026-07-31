<?php

namespace UbepProvisioning;

use ReflectionMethod;

/**
 * Fingerprint of the REDCap surface this channel depends on.
 *
 * The version is a proxy for compatibility; this is the thing itself. Measured
 * across the fleet on 2026-08-01, the two move independently: the field map
 * changes within major 14 (14.3.14 against 14.7.5) yet stays identical across
 * 14.7.5, 15.8.x and 17.0.6, while the signatures hold from 13.11.4 to 15.8.4
 * and change at 17. A major therefore both splits what is equal and merges what
 * differs, which is why it states policy and this states compatibility.
 *
 * This class deliberately takes signatures and field map as arguments instead
 * of reading REDCap itself: it must be testable without a REDCap instance.
 * The caller passes the map obtained with a null project id — see api.php.
 */
class Surface
{
    /** Methods whose signatures the channel depends on. */
    public const METHODS = [
        'addPrivileges',
        'updatePrivileges',
        'removePrivileges',
        'getPrivileges',
        'getRoles',
        'getApiUserPrivilegesAttr',
    ];

    public static function fingerprintFrom(
        array $signatures,
        array $fieldMap
    ): string {
        sort($signatures, SORT_STRING);

        $flatMap = [];
        foreach ($fieldMap as $key => $value) {
            $flatMap[] = $key . '=>' . $value;
        }
        sort($flatMap, SORT_STRING);

        $payload = implode('|', $signatures) . '#' . implode('|', $flatMap);

        return substr(md5($payload), 0, 12);
    }

    public static function signaturesOf(string $class, array $methods): array
    {
        $out = [];
        foreach ($methods as $method) {
            if (!method_exists($class, $method)) {
                // A major that removes a method yields a different fingerprint
                // rather than a fatal error: the instance stays readable, so it
                // can be diagnosed instead of just failing.
                $out[] = $method . ':<missing>';
                continue;
            }

            $reflection = new ReflectionMethod($class, $method);
            $parameters = [];
            foreach ($reflection->getParameters() as $parameter) {
                $type = $parameter->hasType()
                    ? ((string) $parameter->getType() . ' ')
                    : '';
                $parameters[] = $type . '$' . $parameter->getName()
                    . ($parameter->isOptional() ? '?' : '');
            }
            $returns = $reflection->hasReturnType()
                ? (string) $reflection->getReturnType()
                : 'mixed';
            $out[] = $method . '(' . implode(',', $parameters) . '):' . $returns;
        }

        return $out;
    }
}
