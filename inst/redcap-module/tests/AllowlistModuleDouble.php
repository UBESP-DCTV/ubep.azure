<?php

namespace UbepProvisioning;

/**
 * Stand-in for the REDCap module object, so the *reading* of the setting can
 * be tested without REDCap.
 *
 * It exists because a fingerprint test that only feeds hand-written strings to
 * the digest collaudates the hash and not the reader: a reader asking for the
 * wrong key would keep every such assertion green. This double records which
 * keys were asked for and answers null to anything else, so a typo in the key
 * name produces a different fingerprint instead of an unnoticed pass.
 *
 * Not named test_*.php on purpose: the runner globs that pattern, and this
 * file holds no assertions.
 */
class AllowlistModuleDouble
{
    /** @var string[] Keys this double was asked for, in order. */
    public array $asked = [];

    /** @var array<string,string> */
    private array $settings;

    public function __construct(array $settings)
    {
        $this->settings = $settings;
    }

    public function getSystemSetting(string $key)
    {
        $this->asked[] = $key;

        return $this->settings[$key] ?? null;
    }
}
