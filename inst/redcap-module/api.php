<?php
// The provisioning channel endpoint. Read only in this version.

require_once __DIR__ . '/lib/VersionGate.php';
require_once __DIR__ . '/lib/Surface.php';
require_once __DIR__ . '/lib/Auth.php';
require_once __DIR__ . '/lib/StateReader.php';

use UbepProvisioning\Auth;
use UbepProvisioning\StateReader;
use UbepProvisioning\Surface;
use UbepProvisioning\VersionGate;

const UBEP_CONTRACT_VERSION = 1;
const UBEP_FLOOR_MAJOR = 17;
const UBEP_CEILING_MAJOR = 17;

header('Content-Type: application/json; charset=utf-8');

function ubep_fail(string $code, string $message, int $status): void
{
    http_response_code($status);
    echo json_encode(
        [
            'contract_version' => UBEP_CONTRACT_VERSION,
            'errors' => [['code' => $code, 'message' => $message]],
        ],
        JSON_UNESCAPED_SLASHES
    );
    exit;
}

// --- authorisation: this is the whole of it, see the spec ------------------
$secret = $_SERVER['HTTP_X_UBEP_SECRET'] ?? null;
if (!Auth::checkSecret($secret, $module->getSystemSetting('shared-secret'))) {
    ubep_fail('TRASPORTO_SEGRETO_RIFIUTATO', 'secret rejected', 403);
}
if (!Auth::checkIp(
    $_SERVER['REMOTE_ADDR'] ?? null,
    (string) $module->getSystemSetting('ip-allow-list')
)) {
    ubep_fail('TRASPORTO_SEGRETO_RIFIUTATO', 'address not allowed', 403);
}

// --- context ---------------------------------------------------------------
// None of these is a permission. SUPER_USER is declared false because REDCap
// resolves `!defined("SUPER_USER") || SUPER_USER` to true, so omitting it is
// the permissive variant, not the neutral one. USERID and PROJECT_ID exist for
// traceability; without PROJECT_ID a write lands outside the project's log.
if (!defined('SUPER_USER')) {
    define('SUPER_USER', false);
}
if (!defined('USERID')) {
    define('USERID', 'ubep-provisioning');
}

$body = json_decode(file_get_contents('php://input'), true);
if (!is_array($body)) {
    $body = [];
}
$operation = $body['operation'] ?? 'state';

$version = REDCAP_VERSION;
$gate = VersionGate::classify($version, UBEP_FLOOR_MAJOR, UBEP_CEILING_MAJOR);

// The map is asked with a null project id on purpose: with a project it
// returns the base plus that project's feature-conditional fields (a project
// with randomisation enabled adds three), which would make the fingerprint a
// property of the project instead of the instance.
$fingerprint = Surface::fingerprintFrom(
    Surface::signaturesOf('\\UserRights', Surface::METHODS),
    \UserRights::getApiUserPrivilegesAttr(false, null)
);

$versionFile = __DIR__ . '/VERSION';
$moduleVersion = is_readable($versionFile)
    ? trim(file_get_contents($versionFile))
    : 'unknown';

$response = [
    'server' => $_SERVER['HTTP_HOST'] ?? php_uname('n'),
    'redcap_version' => $version,
    'redcap_major' => VersionGate::majorOf($version),
    'module_version' => $moduleVersion,
    'contract_version' => UBEP_CONTRACT_VERSION,
    'version_gate' => $gate,
    'surface_fingerprint' => $fingerprint,
    'dry_run' => true,
    'results' => [],
    'summary' => [],
    'errors' => [],
];

// Below the floor: refuse everything, reads included. Classified as transport,
// not data: the request is queued for the next run, not sent back to whoever
// filed it.
if ($gate === VersionGate::BELOW) {
    $response['errors'][] = [
        'code' => 'TRASPORTO_VERSIONE_SOTTO_MINIMO',
        'message' => 'instance major ' . VersionGate::majorOf($version)
            . ' is below the module floor ' . UBEP_FLOOR_MAJOR,
    ];
    echo json_encode($response, JSON_UNESCAPED_SLASHES);
    exit;
}

if ($operation !== 'state') {
    http_response_code(501);
    $response['errors'][] = [
        'code' => 'INTERNO',
        'message' => "operation '$operation' is not implemented in this version",
    ];
    echo json_encode($response, JSON_UNESCAPED_SLASHES);
    exit;
}

$pairs = [];
foreach (($body['requests'] ?? []) as $request) {
    if (isset($request['username'], $request['project_id'])) {
        $pairs[] = [
            'username' => (string) $request['username'],
            'project_id' => (int) $request['project_id'],
        ];
    }
}

$response['results'] = StateReader::read($pairs);
$response['summary'] = ['letti' => count($response['results'])];

echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
