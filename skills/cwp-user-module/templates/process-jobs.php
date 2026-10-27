<?php
// CWPMOD_TITLE job processor. Runs as root from cron: /usr/local/cwp/php71/bin/php -q /usr/local/lib/cwpmod_example/process-jobs.php
// Consumes validated JSON jobs written by the user-panel module into a root-controlled spool. Never trust a job file:
// the user name comes from the file name AND must match the body, the action must be in the allowlist, args are re-validated.
if (PHP_SAPI !== 'cli') { exit(1); }

const CWPMOD_EXAMPLE_SPOOL = '/var/spool/cwpmod_example';
const CWPMOD_EXAMPLE_LOG = '/var/log/cwpmod_example-jobs.log';
const CWPMOD_EXAMPLE_PANEL_UID = 0;      // uid the panel PHP runs as (0 = root). Set it if `ps` shows another uid (see references).
const CWPMOD_EXAMPLE_MAX_JOBS = 50;      // per run
const CWPMOD_EXAMPLE_MAX_BYTES = 4096;   // per job file
const CWPMOD_EXAMPLE_RE_USER = '/^[a-z][a-z0-9_]{0,31}$/';

function cwpmod_example_log(string $m): void
{
    @file_put_contents(CWPMOD_EXAMPLE_LOG, date('c') . ' ' . $m . "\n", FILE_APPEND | LOCK_EX);
}

// Run a command from an argument array (no shell). Returns [exitcode, stdout].
function cwpmod_example_exec(array $cmd, int $timeout = 120): array
{
    $p = @proc_open($cmd, [0 => ['file', '/dev/null', 'r'], 1 => ['pipe', 'w'], 2 => ['file', '/dev/null', 'w']], $pipes, '/', ['PATH' => '/usr/bin:/bin', 'LANG' => 'C']);
    if (!is_resource($p)) { return [127, '']; }
    stream_set_blocking($pipes[1], false);
    $out = '';
    $end = time() + $timeout;
    while (true) {
        $out .= (string)fread($pipes[1], 65536);
        $st = proc_get_status($p);
        if (!$st['running']) { $code = (int)$st['exitcode']; break; }
        if (time() > $end) { proc_terminate($p, 9); $code = 124; break; }
        usleep(100000);
    }
    $out .= (string)stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    proc_close($p);
    return [$code, substr($out, 0, 1000000)];
}

// action => handler(string $user, array $args): array. Add privileged actions here, one small function each.
function cwpmod_example_action_usage_report(string $user, array $args): array
{
    $top = $args['top'] ?? null;
    if (!is_int($top) || $top < 1 || $top > 20) { throw new RuntimeException('invalid top'); }
    $home = '/home/' . $user;
    if (is_link($home) || !is_dir($home)) { throw new RuntimeException('no such home'); }
    [$code, $out] = cwpmod_example_exec(['du', '-kx', '--max-depth=1', '--', $home]); // du never follows symlinks it finds
    if ($code !== 0 && $out === '') { throw new RuntimeException('du failed'); }
    $rows = [];
    foreach (explode("\n", trim($out)) as $line) {
        $f = explode("\t", $line, 2);
        if (count($f) !== 2 || !ctype_digit($f[0]) || $f[1] === $home) { continue; }
        $rows[] = ['folder' => basename($f[1]), 'kib' => (int)$f[0]];
    }
    usort($rows, function ($a, $b) { return $b['kib'] <=> $a['kib']; });
    return ['top' => array_slice($rows, 0, $top)];
}
function cwpmod_example_handlers(): array
{
    return ['usage-report' => 'cwpmod_example_action_usage_report'];
}

function cwpmod_example_valid_job($job, string $file): ?string
{
    if (!is_array($job) || array_keys($job) !== ['v', 'id', 'user', 'action', 'args', 'ts']) { return 'bad shape'; }
    if ($job['v'] !== 1 || !is_string($job['id']) || !preg_match('/^[a-f0-9]{32}$/', $job['id'])) { return 'bad id'; }
    if (!is_string($job['user']) || !preg_match(CWPMOD_EXAMPLE_RE_USER, $job['user'])) { return 'bad user'; }
    if ($file !== $job['user'] . '.' . $job['id'] . '.json') { return 'file name does not match body'; }
    if (!is_string($job['action']) || !isset(cwpmod_example_handlers()[$job['action']])) { return 'unknown action'; }
    if (!is_array($job['args']) || !is_int($job['ts'])) { return 'bad args'; }
    $pw = function_exists('posix_getpwnam') ? posix_getpwnam($job['user']) : false;
    if (!$pw || $pw['uid'] < 1000 || $pw['dir'] !== '/home/' . $job['user']) { return 'not a hosting account'; }
    return null;
}

function cwpmod_example_result(string $id, string $user, string $action, string $status, $payload): void
{
    $r = ['v' => 1, 'id' => $id, 'user' => $user, 'action' => $action, 'status' => $status, 'finished' => time()];
    $r[$status === 'ok' ? 'data' : 'error'] = $payload;
    $dst = CWPMOD_EXAMPLE_SPOOL . '/results/' . $id . '.json';
    $tmp = $dst . '.tmp';
    file_put_contents($tmp, json_encode($r));
    chmod($tmp, 0600);
    if (CWPMOD_EXAMPLE_PANEL_UID !== 0) { chown($tmp, CWPMOD_EXAMPLE_PANEL_UID); }
    rename($tmp, $dst);
}

// ---------- main ----------
$lock = fopen(CWPMOD_EXAMPLE_SPOOL . '/.lock', 'c');
if (!$lock || !flock($lock, LOCK_EX | LOCK_NB)) { exit(0); } // another run is active
$in = CWPMOD_EXAMPLE_SPOOL . '/incoming';
$work = CWPMOD_EXAMPLE_SPOOL . '/processing';
$done = CWPMOD_EXAMPLE_SPOOL . '/done';
$files = glob($in . '/*.json') ?: [];
sort($files);
foreach (array_slice($files, 0, CWPMOD_EXAMPLE_MAX_JOBS) as $path) {
    $name = basename($path);
    $st = @lstat($path);
    if ($st === false || ($st['mode'] & 0170000) !== 0100000 || $st['size'] > CWPMOD_EXAMPLE_MAX_BYTES
        || ($st['uid'] !== 0 && $st['uid'] !== CWPMOD_EXAMPLE_PANEL_UID)) {
        cwpmod_example_log("reject $name: not a regular small file from the panel");
        @rename($path, $done . '/rejected-' . bin2hex(random_bytes(4)));
        continue;
    }
    $mine = $work . '/' . $name;
    if (!@rename($path, $mine)) { continue; }          // claim it atomically
    $job = json_decode((string)file_get_contents($mine), true);
    $why = cwpmod_example_valid_job($job, $name);
    if ($why !== null) {
        cwpmod_example_log("reject $name: $why");
        @rename($mine, $done . '/rejected-' . bin2hex(random_bytes(4)));
        continue;
    }
    try {
        $data = call_user_func(cwpmod_example_handlers()[$job['action']], $job['user'], $job['args']);
        cwpmod_example_result($job['id'], $job['user'], $job['action'], 'ok', $data);
        cwpmod_example_log("ok {$job['action']} {$job['user']} {$job['id']}");
    } catch (Throwable $e) {
        cwpmod_example_result($job['id'], $job['user'], $job['action'], 'error', 'The job failed.'); // detail only in the log
        cwpmod_example_log("fail {$job['action']} {$job['user']} {$job['id']}: " . $e->getMessage());
    }
    @rename($mine, $done . '/' . $name);
}
// housekeeping: results older than a day, finished jobs older than a week
foreach ([[CWPMOD_EXAMPLE_SPOOL . '/results', 86400], [$done, 604800]] as [$dir, $age]) {
    foreach (glob($dir . '/*') ?: [] as $f) { if (is_file($f) && time() - (int)@filemtime($f) > $age) { @unlink($f); } }
}
