# Fix patterns (before / after)

Contents: 1 guard - 2 session check - 3 CSRF - 4 verb allowlist - 5 no shell strings - 6 SQL - 7 path safety - 8 escaping - 9 secrets - 10 identity - 11 rate limit - 12 audit

## 1. Guard
```php
// before: nothing, file reachable by URL
// after (page)
if(!isset($include_path)){echo "invalid access";exit();}
// after (AJAX file ajax_<name>.php; $include_path is NOT set here)
if(!isset($ajax_file)){echo "invalid access";exit();}
```

## 2. Session check
```php
if (empty($_SESSION['logged']) || empty($_SESSION['token'])) { http_response_code(403); exit; }
```
Do not call `session_start()`.

## 3. CSRF (HMAC of the session token, no session writes)
```php
function mod_csrf(): string { return hash_hmac('sha256', 'mymodule_csrf', (string)$_SESSION['token']); }

// render: <input type="hidden" id="csrf" value="<?php echo htmlspecialchars(mod_csrf(), ENT_QUOTES, 'UTF-8'); ?>">
// verify on every state-changing action:
$sent = $_SERVER['HTTP_X_CSRF'] ?? ($_POST['csrf'] ?? '');
if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !hash_equals(mod_csrf(), (string)$sent)) {
    http_response_code(403); echo json_encode(['ok' => false, 'error' => 'bad token']); exit;
}
```

## 4. Verb and argument allowlist
```php
// before
$out = shell_exec("/usr/local/mymod/bin/mymod " . $_POST['cmd']);
// after
const VERBS = ['status', 'snapshots', 'backup'];           // fixed list
$verb = $_POST['acc'] ?? '';
if (!in_array($verb, VERBS, true)) { http_response_code(400); exit; }
$acct = $_POST['account'] ?? '';
if (!preg_match('/^[a-z][a-z0-9_]{0,31}$/D', $acct)) { http_response_code(400); exit; }
```
Use `/D` (or `\z`): a bare `$` accepts a trailing newline.

## 5. No shell strings: argument array
```php
// before
$out = shell_exec("tar czf /backup/$name.tgz " . $dir);
// after
function run_engine(array $args, ?string $stdin = null, int $timeout = 300): array {
    $cmd = array_merge(['timeout', (string)$timeout, '/usr/local/mymod/bin/mymod'], $args);
    $spec = [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
    $p = proc_open($cmd, $spec, $pipes, null, ['PATH' => '/usr/sbin:/usr/bin:/sbin:/bin']);
    if (!is_resource($p)) { return [1, '', 'spawn failed']; }
    if ($stdin !== null) { fwrite($pipes[0], $stdin); }
    fclose($pipes[0]);
    $out = stream_get_contents($pipes[1]);
    $err = stream_get_contents($pipes[2]);
    fclose($pipes[1]); fclose($pipes[2]);
    return [proc_close($p), $out, $err];
}
[$rc, $out] = run_engine(['backup', '--account', $acct]);
```
An array never invokes a shell. Put user values after `--` if the CLI supports it. When a shell string is truly required, use `escapeshellarg()` on every value and comment why.

Detached job: `proc_open(['setsid', '-f', BIN, ...], [0 => ['file', '/dev/null', 'r'], 1 => ['file', '/dev/null', 'w'], 2 => ['file', '/dev/null', 'w']], $p)`.

## 6. SQL
```php
// before
$r = $mysql_conn->query("SELECT * FROM user WHERE username='" . $_POST['u'] . "'");
// after
$st = $mysql_conn->prepare('SELECT id, domain FROM user WHERE username = ?');
$st->bind_param('s', $acct);
$st->execute();
$rows = $st->get_result()->fetch_all(MYSQLI_ASSOC);
```
Identifier that cannot be bound:
```php
if (!preg_match('/^' . preg_quote($acct, '/') . '_[A-Za-z0-9_]{1,56}$/D', $db)) { exit; }
$q = 'SHOW TABLES FROM `' . str_replace('`', '``', $db) . '`';
```

## 7. Path safety
```php
function safe_path(string $root, string $rel): ?string {
    $root = realpath($root);
    if ($root === false || strpbrk($rel, "\0\n") !== false) { return null; }
    $full = realpath($root . '/' . ltrim($rel, '/'));      // false if missing: resolve the parent dir instead
    if ($full === false || strncmp($full . '/', $root . '/', strlen($root) + 1) !== 0) { return null; }
    return $full;
}
function has_symlink(string $path, string $stop): bool {   // refuse symlink components on write/restore
    while (strlen($path) > strlen($stop)) { if (is_link($path)) { return true; } $path = dirname($path); }
    return false;
}
```
Forbidden restore roots: `/`, `/etc`, `/root`, `/usr`, `/home`, `/var/lib/mysql`. Refuse if the resolved target equals or lies under one.

## 8. Output escaping
```php
echo '<td>' . htmlspecialchars($row['domain'], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') . '</td>';
echo '<script>var DATA=' . json_encode($data, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) . ';</script>';
header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
```
JS: `$('#x').text(value)`, never `.html(value)`.

## 9. Secrets
```php
// before: visible in ps and logs
shell_exec("restic -p $password backup ...");
// after: stdin or child environment
run_engine(['set-secret', 'S3_SECRET'], $secret);
// config file written 0600
$old = umask(077); file_put_contents($f, $data, LOCK_EX); chmod($f, 0600); umask($old);
```
Shell: `printf '%s' "$secret" | cmd --password-stdin`, never `cmd --password "$secret"`.

## 10. User-module identity
```php
// before
$acct = $_POST['user'];
// after
$acct = (string)($_SESSION['username'] ?? '');
if (!preg_match('/^[a-z][a-z0-9_]{0,31}$/D', $acct)) { http_response_code(403); exit; }
$home = '/home/' . $acct;       // derive everything from $acct, then run safe_path()
```

## 11. Rate limit / single flight
```php
$lock = fopen('/var/lib/mymod/lock/' . $acct . '.lock', 'c');
if (!flock($lock, LOCK_EX | LOCK_NB)) { http_response_code(429); echo json_encode(['ok' => false, 'error' => 'busy']); exit; }
```

## 12. Audit line
```php
function audit(string $action, string $target, string $result): void {
    $clean = fn($s) => substr(preg_replace('/[\x00-\x1f\x7f]/', ' ', (string)$s), 0, 200);
    $line = gmdate('c') . "\t" . $clean($_SESSION['username'] ?? '?') . "\t" . $clean($action)
          . "\t" . $clean($target) . "\t" . $clean($result) . "\n";
    file_put_contents('/var/log/mymod-audit.log', $line, FILE_APPEND | LOCK_EX);
}
```
