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
$malformed = [];
foreach (($body['requests'] ?? []) as $request) {
    if (isset($request['username'], $request['project_id'])) {
        $requests[] = [
            'username' => (string) $request['username'],
            'project_id' => (int) $request['project_id'],
            // A non-scalar value (an array, say) would flow unchanged into
            // Planner::shape() and then Applier::flat()'s (string) cast,
            // which raises a PHP warning that prints ahead of the JSON body
            // -- headers are already sent and output is unbuffered here --
            // and breaks the client's parse. Anything not scalar is treated
            // as absent instead.
            'role_name' => is_scalar($request['role_name'] ?? null)
                ? (string) $request['role_name'] : null,
            'dag_name' => is_scalar($request['dag_name'] ?? null)
                ? (string) $request['dag_name'] : null,
            'expiration' => is_scalar($request['expiration'] ?? null)
                ? (string) $request['expiration'] : null,
        ];
        continue;
    }

    // isset() is false both for an absent key and for a present null, so
    // this is the same condition the branch above tests, inverted. Reported
    // instead of silently dropped: on apply/revoke the response is the
    // audit trail of a write, and a caller must see every row it asked
    // about, whether or not the row could be planned -- otherwise a
    // ten-request revoke with one null project_id comes back as "9
    // revocato", no error, no ninth row, and no sign the tenth was never
    // considered. Whatever the request did supply is carried through so the
    // caller can identify which row this was.
    $missing = [];
    if (!isset($request['username'])) {
        $missing[] = 'username';
    }
    if (!isset($request['project_id'])) {
        $missing[] = 'project_id';
    }
    $malformed[] = [
        'username' => isset($request['username']) && is_scalar($request['username'])
            ? (string) $request['username'] : null,
        'project_id' => isset($request['project_id']) && is_scalar($request['project_id'])
            ? (int) $request['project_id'] : null,
        'outcome' => 'errore',
        'before' => ['role_name' => null, 'dag_name' => null, 'expiration' => null],
        'after' => ['role_name' => null, 'dag_name' => null, 'expiration' => null],
        'errors' => [[
            'code' => 'DATO_UTENTE_NON_VALIDO',
            'message' => implode(', ', $missing) . ' missing or null',
        ]],
    ];
}

$pairs = array_map(
    fn($r) => ['username' => $r['username'], 'project_id' => $r['project_id']],
    $requests
);

if ($operation === 'state') {
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
// and simulating a batch is how one discovers it needs to be split. Only
// well-formed requests are counted: a malformed one contributes no
// project_id and is reported on its own, below, never written -- so it has
// nothing to add to, or spoil, this count.
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

// An empty $pairs means "nothing to plan", not "the whole instance" -- that
// second meaning belongs to StateReader::read() alone, for the state call
// above. Without the guard, a write with zero usable requests would still
// full-scan the rights table of a live instance and then discard the
// result, since Planner iterates $requests, not $current, and $requests is
// empty either way.
$current = $pairs === [] ? [] : StateReader::read($pairs);

$plan = $operation === 'apply'
    ? Planner::planApply($requests, $current)
    : Planner::planRevoke($requests, $current);

// Write-only, per the phase-2 design spec §4 "Il freno" and rollout §10
// point 1: with the brake active in simulation too, a dry_run over any
// non-test project would return 'errore' for every entry of that project --
// not a degraded preview but an impossible one, since "solo dry_run, su
// tutto" depends on being able to simulate a real batch, production
// projects included. Only $plan is checked here, and $plan holds only
// requests Planner could shape; $malformed joins after, so a null
// project_id never reaches TestProjects::allows(), which is typed int.
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
}

$plan = array_merge($plan, $malformed);

if (!$dryRun) {
    // The full plan goes in, error entries included: both apply() and
    // revoke() skip anything whose outcome is not one they write for
    // (writeKindFor() returns null for 'errore'; revoke() filters on
    // 'revocato'), so there is no separate writable/refused split to keep in
    // sync by key here, and the $malformed rows -- 'errore' from the moment
    // they are built, with no valid pair to write -- need no second guard
    // either.
    $plan = $operation === 'apply'
        ? Applier::apply($plan)
        : Applier::revoke($plan);
}

// Every key the operation can produce is seeded at zero and counted after
// the brake and the Applier have rewritten outcomes. Both matter: counting
// on the plan before rewriting would report intentions instead of facts,
// and not seeding would leave "summary": [] on an empty plan -- a JSON
// array where every other response is an object -- and would read as
// summary$errore == NULL, not 0, on the R side.
$summary = array_fill_keys(
    $operation === 'apply'
        ? ['noop', 'creato', 'aggiornato', 'errore']
        : ['noop', 'revocato', 'errore'],
    0
);
foreach ($plan as $entry) {
    $summary[$entry['outcome']] = ($summary[$entry['outcome']] ?? 0) + 1;
}

$response['results'] = $plan;
$response['summary'] = $summary;

echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
