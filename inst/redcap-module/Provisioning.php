<?php

namespace UBEP\Provisioning;

use ExternalModules\AbstractExternalModule;

/**
 * The provisioning channel.
 *
 * No hooks: the module exists to give api.php a module context, from which it
 * reads its own system settings. The spike verified that get/setSystemSetting
 * work from a NOAUTH page, which is what makes the per-server secret reachable
 * where it is declared.
 *
 * Name and namespace are not free choices: the External Module framework
 * derives the class file from the last segment of the namespace in config.json,
 * so `UBEP\Provisioning` must live in `Provisioning.php` and declare
 * `Provisioning`. The classes under lib/ use their own namespace on purpose —
 * they are loaded by explicit require and must stay usable, and testable,
 * without the framework present.
 */
class Provisioning extends AbstractExternalModule
{
}
