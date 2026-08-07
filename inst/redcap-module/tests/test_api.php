<?php
// The only collaudo of api.php, and the reason it exists: api.php is the one
// file of the module no other test loads, because loading it would ask for
// REDCap. So it is checked by reading it rather than running it.
//
// What is checked is name resolution, which is the failure `php -l` cannot
// see: a linter accepts `Foo::bar()` whether or not `Foo` resolves to
// anything, since that is settled at run time. api.php declares no namespace,
// so an unqualified name resolves to the global one unless a `use` imports
// it -- and requiring the file that defines `UbepProvisioning\Foo` does not
// make a bare `Foo` resolve. That is one edit away at every addition: the
// require and the call get written, the import does not.
//
// REDCap's own symbols stay out of this by construction: api.php names them
// fully qualified (`\UserRights`), and a fully qualified name is not what this
// checks. That is what keeps the test independent of a live instance.

require_once __DIR__ . '/../lib/VersionGate.php';
require_once __DIR__ . '/../lib/Surface.php';
require_once __DIR__ . '/../lib/Allowlist.php';
require_once __DIR__ . '/../lib/Auth.php';
require_once __DIR__ . '/../lib/StateReader.php';
require_once __DIR__ . '/../lib/FieldNames.php';
require_once __DIR__ . '/../lib/TestedSurfaces.php';
require_once __DIR__ . '/../lib/Planner.php';
require_once __DIR__ . '/../lib/Applier.php';

$ubepApiTokens = token_get_all(file_get_contents(__DIR__ . '/../api.php'));

/**
 * The next token that carries meaning, skipping whitespace and comments.
 *
 * @param array<int, array{0:int,1:string}|string> $tokens
 * @return array{0:int,1:string}|string|null
 */
function ubep_next_meaningful(array $tokens, int $from)
{
    $skip = [T_WHITESPACE, T_COMMENT, T_DOC_COMMENT];
    for ($i = $from; $i < count($tokens); $i++) {
        if (is_array($tokens[$i]) && in_array($tokens[$i][0], $skip, true)) {
            continue;
        }
        return $tokens[$i];
    }

    return null;
}

// --- what the file imports -------------------------------------------------
// Short name => the name it actually resolves to. A closure's `use ($x)` is
// not an import and is excluded by the shape: what follows it is `(`, not a
// name.
$ubepImports = [];
foreach ($ubepApiTokens as $i => $token) {
    if (!is_array($token) || $token[0] !== T_USE) {
        continue;
    }
    $next = ubep_next_meaningful($ubepApiTokens, $i + 1);
    if (!is_array($next)) {
        continue;
    }
    if (!in_array($next[0], [T_NAME_QUALIFIED, T_NAME_FULLY_QUALIFIED, T_STRING], true)) {
        continue;
    }
    $fqn = ltrim($next[1], '\\');
    $cut = strrpos($fqn, '\\');
    $ubepImports[$cut === false ? $fqn : substr($fqn, $cut + 1)] = $fqn;
}

// --- what the file names without qualifying it -----------------------------
// A bare `Foo` followed by `::`. `\Foo` and `Foo\Bar` tokenize as their own
// token types in PHP 8 and never reach here, which is precisely why REDCap's
// classes are invisible to this check.
$ubepUnqualified = [];
foreach ($ubepApiTokens as $i => $token) {
    if (!is_array($token) || $token[0] !== T_STRING) {
        continue;
    }
    $next = ubep_next_meaningful($ubepApiTokens, $i + 1);
    if (is_array($next) && $next[0] === T_DOUBLE_COLON) {
        $ubepUnqualified[$token[1]] = true;
    }
}
unset($ubepUnqualified['self'], $ubepUnqualified['static'], $ubepUnqualified['parent']);

// The check is only worth its lines if it is looking at something: an empty
// set would pass while the tokenizer silently found nothing.
ubep_assert_true(
    count($ubepUnqualified) > 0,
    'api.php names at least one class without qualifying it'
);

$ubepUnresolved = [];
foreach (array_keys($ubepUnqualified) as $name) {
    // No import means the global namespace, which is where api.php sits.
    $target = $ubepImports[$name] ?? $name;
    if (!class_exists($target) && !interface_exists($target)) {
        $ubepUnresolved[] = $name;
    }
}
sort($ubepUnresolved, SORT_STRING);

ubep_assert_same(
    [],
    $ubepUnresolved,
    'every class api.php names unqualified resolves once the module is loaded'
);
