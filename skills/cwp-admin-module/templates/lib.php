<?php
// CWPMOD_TITLE - shared glue: engine runner, validation, CSRF, AJAX handlers.
// Included by modules/cwpmod_example.php (CWP sets $include_path) and addons/ajax/ajax_cwpmod_example.php (loader_ajax.php sets $ajax_file).
// Both run after CWP's own admin login check; we still require a logged-in admin session.
if (!isset($include_path) && !isset($ajax_file)) { echo "invalid access"; exit(); }
if (empty($_SESSION['logged']) || empty($_SESSION['token'])) { http_response_code(403); echo "admin login required"; exit(); }
if (defined('CWPMOD_EXAMPLE_LIB')) { return; }
define('CWPMOD_EXAMPLE_LIB', 1);

const CWPMOD_EXAMPLE_ENGINE = '/usr/local/lib/cwpmod_example/engine';
const CWPMOD_EXAMPLE_RE_ACCOUNT = '/^[a-z][a-z0-9_]{0,31}$/';

// CWP manages its own session; never call session_start() or write to $_SESSION here.

// ---------- strings and output ----------
function cwpmod_example_lang(): array
{
    static $t = null;
    if ($t === null) { $t = @parse_ini_file(__DIR__ . '/../language/en/cwpmod_example.ini') ?: []; }
    return $t;
}
function cwpmod_example_h($s): string { return htmlspecialchars((string)$s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
function cwpmod_example_json($v): string { return json_encode($v, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_INVALID_UTF8_SUBSTITUTE); }
function cwpmod_example_out(bool $ok, $data = null, ?string $err = null, int $http = 200): void
{
    while (ob_get_level() > 0) { ob_end_clean(); }
    http_response_code($http);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo cwpmod_example_json($ok ? ['ok' => true, 'data' => $data] : ['ok' => false, 'error' => $err ?? 'error']);
    exit();
}
function cwpmod_example_str(string $k, string $src = 'P'): string
{
    $v = $src === 'P' ? ($_POST[$k] ?? '') : ($_GET[$k] ?? '');
    return is_string($v) ? trim($v) : '';
}

// ---------- database (CWP's root_cwp handle) ----------
// The entry file passes the handle in, because $mysql_conn is a variable of the loader's scope, not a guaranteed global.
function cwpmod_example_db($set = null)
{
    static $c = null;
    if ($set instanceof mysqli) { $c = $set; }
    return $c;
}

// ---------- CSRF ----------
function cwpmod_example_csrf(): string
{
    // Derived from CWP's per-login session token: stable for the login, no session write needed.
    return hash_hmac('sha256', 'cwpmod_example_csrf', (string)$_SESSION['token']);
}
function cwpmod_example_csrf_ok(): bool
{
    $got = $_POST['csrf'] ?? ($_SERVER['HTTP_X_CSRF_TOKEN'] ?? '');
    return is_string($got) && $got !== '' && hash_equals(cwpmod_example_csrf(), $got);
}

// ---------- engine runner: argument array + verb allowlist, never a shell string ----------
// Returns null when $args are allowed, else an error string.
function cwpmod_example_check_args(array $args): ?string
{
    $flagsAllowed = ['version' => [], 'disk-usage' => ['--account'], 'refresh' => ['--account']];
    foreach ($args as $a) { if (!is_string($a) || strpos($a, "\0") !== false) { return 'bad argument'; } }
    $verb = $args[0] ?? '';
    if (!isset($flagsAllowed[$verb])) { return 'verb not allowed'; }
    $n = count($args);
    for ($i = 1; $i < $n; $i++) {
        $f = $args[$i];
        if (!in_array($f, $flagsAllowed[$verb], true)) { return 'flag not allowed: ' . $verb; }
        if (++$i >= $n) { return 'missing value'; }
        $v = $args[$i];
        $ok = false;
        switch ($f) {
            case '--account': $ok = (bool)preg_match(CWPMOD_EXAMPLE_RE_ACCOUNT, $v); break;
        }
        if (!$ok) { return 'invalid ' . $f; }
    }
    return null;
}

// Returns ['ok'=>bool,'code'=>int,'data'=>mixed,'error'=>?string]. data is decoded JSON, or raw stdout when not JSON.
function cwpmod_example_run(array $args): array
{
    $args = array_values($args);
    if (($err = cwpmod_example_check_args($args)) !== null) { return ['ok' => false, 'code' => 2, 'data' => null, 'error' => $err]; }
    if (!is_file(CWPMOD_EXAMPLE_ENGINE) || !is_executable(CWPMOD_EXAMPLE_ENGINE)) {
        return ['ok' => false, 'code' => 127, 'data' => null, 'error' => 'Engine is not installed (' . CWPMOD_EXAMPLE_ENGINE . ' missing). Run install.sh.'];
    }
    $timeout = 60;
    $env = ['PATH' => '/usr/local/bin:/usr/bin:/bin', 'HOME' => '/root', 'LANG' => 'C']; // cwpsrv pools have no HOME
    $spec = [0 => ['file', '/dev/null', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
    $p = @proc_open(array_merge([CWPMOD_EXAMPLE_ENGINE], $args), $spec, $pipes, '/', $env); // array form: no shell involved
    if (!is_resource($p)) { return ['ok' => false, 'code' => -1, 'data' => null, 'error' => 'cannot start engine']; }
    stream_set_blocking($pipes[1], false);
    stream_set_blocking($pipes[2], false);
    $out = $errOut = '';
    $deadline = time() + $timeout;
    $timedOut = false;
    $exit = -1;
    while (true) {
        $r = [$pipes[1], $pipes[2]]; $w = null; $e = null;
        if (@stream_select($r, $w, $e, 1) > 0) {
            foreach ($r as $s) {
                $chunk = fread($s, 65536);
                if ($chunk === false || $chunk === '') { continue; }
                if ($s === $pipes[1]) { if (strlen($out) < 4000000) { $out .= $chunk; } }
                elseif (strlen($errOut) < 65536) { $errOut .= $chunk; }
            }
        }
        $st = proc_get_status($p);
        if (!$st['running']) { $exit = (int)$st['exitcode']; break; }
        if (time() > $deadline) { $timedOut = true; proc_terminate($p, 9); break; }
    }
    $out .= (string)stream_get_contents($pipes[1]);
    $errOut .= (string)stream_get_contents($pipes[2]);
    fclose($pipes[1]); fclose($pipes[2]);
    $closed = proc_close($p);
    if ($timedOut) { return ['ok' => false, 'code' => 124, 'data' => null, 'error' => 'engine timed out']; }
    // proc_close() returns -1 once proc_get_status() has reaped the child, so the status exit code wins.
    $code = $exit >= 0 ? $exit : $closed;
    $data = json_decode($out, true);
    if ($data === null) { $data = trim($out); }
    return ['ok' => $code === 0, 'code' => $code, 'data' => $data, 'error' => $code === 0 ? null : (cwpmod_example_clip($errOut) ?: 'engine failed')];
}
function cwpmod_example_clip(string $s): string { return substr(trim($s), 0, 300); }
function cwpmod_example_fail(array $r): void { cwpmod_example_out(false, null, $r['error'] ?? 'engine error'); }

// ---------- AJAX handlers ----------
function cwpmod_example_dispatch(string $acc): void
{
    $post = ($_SERVER['REQUEST_METHOD'] ?? '') === 'POST';
    $writes = ['refresh']; // every state-changing action: POST + CSRF
    if (in_array($acc, $writes, true)) {
        if (!$post) { cwpmod_example_out(false, null, 'POST required', 405); }
        if (!cwpmod_example_csrf_ok()) { cwpmod_example_out(false, null, 'Invalid or missing security token. Reload the page.', 403); }
    }
    $account = cwpmod_example_str('account', $post ? 'P' : 'G');
    $acctOk = (bool)preg_match(CWPMOD_EXAMPLE_RE_ACCOUNT, $account);

    switch ($acc) {
        case 'status':
            $r = cwpmod_example_run(['version']); if (!$r['ok']) { cwpmod_example_fail($r); }
            cwpmod_example_out(true, $r['data']);
        case 'accounts':
            $db = cwpmod_example_db();
            if (!($db instanceof mysqli)) { cwpmod_example_out(false, null, 'Database handle not available', 500); }
            $q = cwpmod_example_str('q', 'G');
            if ($q !== '' && !preg_match('/^[A-Za-z0-9._-]{1,64}$/', $q)) { cwpmod_example_out(false, null, 'Invalid search'); }
            $like = '%' . $q . '%';
            $st = $db->prepare('SELECT `username`, `domain`, `package` FROM `user` WHERE `username` LIKE ? OR `domain` LIKE ? ORDER BY `username` LIMIT 500');
            if (!$st) { cwpmod_example_out(false, null, 'Query failed', 500); }
            $st->bind_param('ss', $like, $like);
            $st->execute();
            cwpmod_example_out(true, $st->get_result()->fetch_all(MYSQLI_ASSOC));
        case 'usage':
            if (!$acctOk) { cwpmod_example_out(false, null, 'Invalid account'); }
            $r = cwpmod_example_run(['disk-usage', '--account', $account]); if (!$r['ok']) { cwpmod_example_fail($r); }
            cwpmod_example_out(true, $r['data']);
        case 'refresh':
            if (!$acctOk) { cwpmod_example_out(false, null, 'Invalid account'); }
            $r = cwpmod_example_run(['refresh', '--account', $account]); if (!$r['ok']) { cwpmod_example_fail($r); }
            cwpmod_example_out(true, $r['data']);
        default:
            cwpmod_example_out(false, null, 'Unknown action', 404);
    }
}
