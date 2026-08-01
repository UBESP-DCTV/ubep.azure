<?php
// The provisioning channel endpoint: state, apply and revoke.

require_once __DIR__ . '/lib/VersionGate.php';
require_once __DIR__ . '/lib/Surface.php';
require_once __DIR__ . '/lib/Auth.php';
require_once __DIR__ . '/lib/StateReader.php';
require_once __DIR__ . '/lib/FieldNames.php';
require_once __DIR__ . '/lib/TestProjects.php';
require_once __DIR__ . '/lib/Planner.php';
require_once __DIR__ . '/lib/Applier.php';

use UbepProvisioning\Applier;
use UbepProvisioning\Auth;
use UbepProvisioning\Planner;
use UbepProvisioning\StateReader;
use UbepProvisioning\Surface;
use UbepProvisioning\TestProjects;
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

// Writes happen only on an explicit boolean false. An absent field, a string,
// a number or a malformed body all simulate: the safe direction is the one the
// endpoint already takes for the operation, where an unreadable body becomes
// `state` instead of something that writes.
$dryRun = !(($body['dry_run'] ?? true) === false);

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
    'dry_run' => $dryRun,
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

$requests = [];
foreach (($body['requests'] ?? []) as $request) {
    if (isset($request['username'], $request['project_id'])) {
        $requests[] = [
            'username' => (string) $request['username'],
            'project_id' => (int) $request['project_id'],
            'role_name' => $request['role_name'] ?? null,
            'dag_name' => $request['dag_name'] ?? null,
            'expiration' => $request['expiration'] ?? null,
        ];
    }
}

if ($operation === 'state') {
    $pairs = array_map(
        fn($r) => ['username' => $r['username'], 'project_id' => $r['project_id']],
        $requests
    );
    $response['results'] = StateReader::read($pairs);
    $response['summary'] = ['letti' => count($response['results'])];
    echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

if ($operation !== 'apply' && $operation !== 'revoke') {
    http_response_code(501);
    $response['errors'][] = [
        'code' => 'INTERNO',
        'message' => "operation '$operation' is not implemented in this version",
    ];
    echo json_encode($response, JSON_UNESCAPED_SLASHES);
    exit;
}

// PROJECT_ID is a define(): one per process, immutable, and it is what makes
// invariant 6 true (every write lands in its own project's log). A write
// spanning more than one project could only give one of them that partition,
// so a write is confined to a single project_id and refused outright before
// touching anything -- never written and then undone. dry_run stays free to
// cross projects: it writes nothing, so there is no log partition to lose,
// and simulating a batch is how one discovers it needs to be split.
if (!$dryRun) {
    $projectIds = array_unique(array_map(fn($r) => $r['project_id'], $requests));
    if (count($projectIds) > 1) {
        http_response_code(400);
        $response['errors'][] = [
            'code' => 'INTERNO',
            'message' => 'a write request must touch a single project_id',
        ];
        echo json_encode($response, JSON_UNESCAPED_SLASHES);
        exit;
    }
    if ($projectIds !== [] && !defined('PROJECT_ID')) {
        define('PROJECT_ID', (int) reset($projectIds));
    }
}

$pairs = array_map(
    fn($r) => ['username' => $r['username'], 'project_id' => $r['project_id']],
    $requests
);
$current = StateReader::read($pairs);

$plan = $operation === 'apply'
    ? Planner::planApply($requests, $current)
    : Planner::planRevoke($requests, $current);

if (!$dryRun) {
    $allowed = (string) $module->getSystemSetting('test-project-ids');
    foreach ($plan as $index => $entry) {
        if (!TestProjects::allows($entry['project_id'], $allowed)) {
            $plan[$index]['outcome'] = 'errore';
            $plan[$index]['errors'][] = [
                'code' => 'INTERNO',
                'message' => 'writes are confined to test projects '
                    . 'in this module version',
            ];
        }
    }

    // The full plan goes in, error entries included: both apply() and
    // revoke() skip anything whose outcome is not one they write for
    // (writeKindFor() returns null for 'errore'; revoke() filters on
    // 'revocato'), so there is no separate writable/refused split to keep in
    // sync by key here.
    $plan = $operation === 'apply'
        ? Applier::apply($plan)
        : Applier::revoke($plan);
}

// Counted after the brake and the Applier have rewritten outcomes, or this
// would report intentions instead of facts and an 'errore' would show as a
// 'creato'.
$summary = [];
foreach ($plan as $entry) {
    $summary[$entry['outcome']] = ($summary[$entry['outcome']] ?? 0) + 1;
}

$response['results'] = $plan;
$response['summary'] = $summary;

echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
