<?php
// CWPMOD_TITLE - CWP user-panel module (customer area).
// Lives in /usr/local/cwpsrv/var/services/user_files/modules/cwpmod_example.php; CWP includes it for ?module=cwpmod_example.
// The only identity is $_SESSION['username']. Privileged work is never done here: it is queued as a validated job
// in a root-owned spool and executed by /usr/local/lib/cwpmod_example/process-jobs.php (cron, root).
// VERIFY per CWP version (see references/verify-per-version.md): which $_SESSION keys exist, and how the module is invoked.
if (empty($_SESSION['username']) || !is_string($_SESSION['username'])) { http_response_code(403); echo "login required"; exit(); }

const CWPMOD_EXAMPLE_SPOOL = '/var/spool/cwpmod_example';
const CWPMOD_EXAMPLE_RE_USER = '/^[a-z][a-z0-9_]{0,31}$/';
const CWPMOD_EXAMPLE_MAX_PENDING = 3;

// ---------- identity and CSRF ----------
function cwpmod_example_user(): string
{
    $u = $_SESSION['username'];
    if (!preg_match(CWPMOD_EXAMPLE_RE_USER, $u) || !is_dir('/home/' . $u)) { http_response_code(403); echo "invalid session"; exit(); }
    return $u;
}
function cwpmod_example_secret(): string
{
    // 'tokenuser' is documented for user modules; fall back to 'token'. Empty means fail closed (no writes).
    foreach (['tokenuser', 'token'] as $k) {
        if (!empty($_SESSION[$k]) && is_string($_SESSION[$k])) { return $_SESSION[$k]; }
    }
    return '';
}
function cwpmod_example_csrf(string $user): string
{
    $s = cwpmod_example_secret();
    return $s === '' ? '' : hash_hmac('sha256', 'cwpmod_example_csrf|' . $user, $s);
}
function cwpmod_example_csrf_ok(string $user): bool
{
    $want = cwpmod_example_csrf($user);
    $got = $_POST['csrf'] ?? ($_SERVER['HTTP_X_CSRF_TOKEN'] ?? '');
    return $want !== '' && is_string($got) && hash_equals($want, $got);
}

// ---------- output ----------
function cwpmod_example_out(bool $ok, $data = null, ?string $err = null, int $http = 200): void
{
    while (ob_get_level() > 0) { ob_end_clean(); }
    http_response_code($http);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($ok ? ['ok' => true, 'data' => $data] : ['ok' => false, 'error' => $err ?? 'error'], JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_INVALID_UTF8_SUBSTITUTE);
    exit();
}

// ---------- job queue (producer side) ----------
// Allowed actions and their argument validators. The root processor repeats this validation; keep both lists in sync.
function cwpmod_example_job_args(string $action, array $in): ?array
{
    switch ($action) {
        case 'usage-report':
            $top = $in['top'] ?? '10';
            if (!is_string($top) || !ctype_digit($top) || (int)$top < 1 || (int)$top > 20) { return null; }
            return ['top' => (int)$top];
    }
    return null;
}
function cwpmod_example_submit(string $user, string $action, array $args): ?string
{
    $in = CWPMOD_EXAMPLE_SPOOL . '/incoming';
    if (!is_dir($in) || !is_writable($in)) { return null; }
    if (count(glob($in . '/' . $user . '.*.json') ?: []) >= CWPMOD_EXAMPLE_MAX_PENDING) { return ''; } // too many pending
    $id = bin2hex(random_bytes(16));
    $job = ['v' => 1, 'id' => $id, 'user' => $user, 'action' => $action, 'args' => (object)$args, 'ts' => time()];
    $tmp = $in . '/.tmp-' . $id;
    $fh = @fopen($tmp, 'x');                                  // 'x': fail if it exists, never follow a planted file
    if ($fh === false) { return null; }
    $okw = fwrite($fh, json_encode($job)) !== false;
    fclose($fh);
    if (!$okw || !@chmod($tmp, 0600) || !@rename($tmp, $in . '/' . $user . '.' . $id . '.json')) { @unlink($tmp); return null; }
    return $id;
}
function cwpmod_example_status(string $user, string $id): array
{
    if (!preg_match('/^[a-f0-9]{32}$/', $id)) { return ['state' => 'unknown']; }
    $res = CWPMOD_EXAMPLE_SPOOL . '/results/' . $id . '.json';
    if (is_file($res) && !is_link($res)) {
        $r = json_decode((string)file_get_contents($res), true);
        if (is_array($r) && ($r['user'] ?? '') === $user) { return ['state' => ($r['status'] ?? '') === 'ok' ? 'done' : 'failed', 'result' => $r['data'] ?? null, 'error' => $r['error'] ?? null]; }
        return ['state' => 'unknown']; // someone else's job id: say nothing
    }
    foreach (['incoming/' . $user . '.' . $id . '.json', 'processing/' . $user . '.' . $id . '.json'] as $p) {
        if (file_exists(CWPMOD_EXAMPLE_SPOOL . '/' . $p)) { return ['state' => 'queued']; }
    }
    return ['state' => 'unknown'];
}

// ---------- routing: ?module=cwpmod_example&acc=<action> (the user panel has no separate AJAX folder) ----------
$cwpmod_example_user = cwpmod_example_user();
if (isset($_GET['acc'])) {
    $acc = is_string($_GET['acc']) ? $_GET['acc'] : '';
    $post = ($_SERVER['REQUEST_METHOD'] ?? '') === 'POST';
    if ($acc === 'submit') {
        if (!$post) { cwpmod_example_out(false, null, 'POST required', 405); }
        if (!cwpmod_example_csrf_ok($cwpmod_example_user)) { cwpmod_example_out(false, null, 'Invalid or missing security token. Reload the page.', 403); }
        $action = is_string($_POST['action'] ?? null) ? $_POST['action'] : '';
        $args = cwpmod_example_job_args($action, $_POST);
        if ($args === null) { cwpmod_example_out(false, null, 'Invalid request'); }
        $id = cwpmod_example_submit($cwpmod_example_user, $action, $args);
        if ($id === null) { cwpmod_example_out(false, null, 'The job queue is not available. Ask your administrator.', 503); }
        if ($id === '') { cwpmod_example_out(false, null, 'Too many pending jobs. Try again in a minute.', 429); }
        cwpmod_example_out(true, ['id' => $id]);
    }
    if ($acc === 'status') {
        cwpmod_example_out(true, cwpmod_example_status($cwpmod_example_user, is_string($_GET['id'] ?? null) ? $_GET['id'] : ''));
    }
    cwpmod_example_out(false, null, 'Unknown action', 404);
}

// ---------- page data for the Twig template (mod.*) ----------
$mod['username'] = $cwpmod_example_user;
$mod['csrf'] = cwpmod_example_csrf($cwpmod_example_user);
