# CWP module security checklist

Contents: 1 Guard - 2 Session and authorization - 3 CSRF - 4 Verbs and arguments - 5 Shell - 6 SQL - 7 Paths - 8 Output - 9 Secrets - 10 Permissions - 11 Restore and write targets - 12 User-module identity - 13 Rate limits - 14 Logging and audit - 15 Installer and cron

"Fix #n" refers to `fix-patterns.md`.

## 1. Guard (CWP-GUARD)
- [ ] Every web-reachable PHP file starts with the guard. Page: `$include_path`; AJAX: `$ajax_file`. (MEDIUM; HIGH if the file acts on request data.) Fix #1
- [ ] Library files in `<name>/` are guarded too, or contain only functions/classes and no top-level code.
- [ ] No file under the module dir is a standalone script with top-level logic that skips the guard.

## 2. Session and authorization (CWP-AUTH, CWP-SESS)
- [ ] AJAX file checks `!empty($_SESSION['logged']) && !empty($_SESSION['token'])` and answers 403 without output otherwise. (CRITICAL if missing on a root action.) Fix #2
- [ ] The check proves the right role. Admin panel (2030/2031) sessions are admin; for a user-panel module confirm the user context.
- [ ] No `session_start()`, no reliance on writing `$_SESSION`.

## 3. CSRF (CWP-CSRF)
- [ ] Every state-changing action is POST and verifies a token with `hash_equals`. GET never changes state. Fix #3
- [ ] Token = HMAC of the session token with a module-specific label; not `md5(time())`, not a constant.
- [ ] Token sent in a header or POST field, not in the URL.

## 4. Verbs and arguments
- [ ] `acc`/action/verb matched against a fixed array with `in_array($v, $ALLOWED, true)`; unknown -> 400. Fix #4
- [ ] Each argument validated by its own function (account `^[a-z][a-z0-9_]{0,31}$`, hostname regex for domains, hex for ids, `ctype_digit` plus range for integers).
- [ ] Reject, do not sanitize: failed validation stops the request.
- [ ] Reject newline, NUL and a leading `-` in anything that becomes an argv item.

## 5. Shell (CWP-SH)
- [ ] No `shell_exec`, `exec`, `system`, `passthru`, `popen` or backticks with variables. Fix #5
- [ ] `proc_open` takes an array. No `sh -c`, no `bash -c "...$x..."`.
- [ ] User values placed after `--` when the tool supports it.
- [ ] `escapeshellarg` only where a shell string is unavoidable, with a comment saying why.
- [ ] Detached jobs: `proc_open(['setsid','-f',BIN,...])` with stdio to `/dev/null`.
- [ ] Shell scripts: `set -Eeuo pipefail`, quoted expansions, no `eval`, `IFS` set, `"${VAR:?}"` before `rm -rf`.
- [ ] Timeouts on child processes (`timeout 300 ...`) so a request cannot hang a worker.

## 6. SQL (CWP-SQL)
- [ ] Prepared statements: `$mysql_conn->prepare()` and `bind_param`. Fix #6
- [ ] Identifiers (table/column/database) cannot be bound: validate by regex or allowlist, then quote with backticks and double any backtick inside.
- [ ] Account databases verified to belong to the account (`<user>_` prefix) before `USE`, `DROP` or dump.
- [ ] `LIKE` values escape `%`, `_`, `\`.
- [ ] Module data lives in its own database or table prefix; never alter `root_cwp` tables.
- [ ] DB credentials come from the `$db_*` variables; never copied into a module file.

## 7. Paths (CWP-PATH)
- [ ] User-influenced path -> `realpath()` -> must start with the allowed root + `/`. Fix #7
- [ ] Refuse symlink components for write, restore and delete targets.
- [ ] Never `include`/`require` a path built from a request value.
- [ ] Uploaded names replaced by generated names; extension allowlist; no `.php` in any web-served dir.
- [ ] Temp files via `tempnam`/`mkdir` with 0700, not predictable `/tmp/<name>`.

## 8. Output (CWP-XSS)
- [ ] Every dynamic value in HTML goes through `htmlspecialchars($v, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')`. Fix #8
- [ ] Data for inline JS: `json_encode($v, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT)`.
- [ ] AJAX responses send `Content-Type: application/json` and `X-Content-Type-Options: nosniff`.
- [ ] JS builds DOM with `.text()` / `textContent`, not `.html(userValue)`.
- [ ] Errors shown to the user are generic; details go to the log.
- [ ] No external CDN scripts (a compromised CDN would own a root panel).

## 9. Secrets (CWP-SEC)
- [ ] No secret in argv (visible in `ps`) or logs. Use stdin, child environment, or a `0600` file. Fix #9
- [ ] Settings screens are write-only for secrets: show "set / not set", never the value.
- [ ] No hard-coded keys or default passwords; the installer generates them (`openssl rand`).
- [ ] Responses and audit lines scrub secrets and cap error text length.

## 10. Permissions
- [ ] Entry points set `umask 077` (or 027 with a stated reason). Config and secret files `0600 root:root`; state dirs `0750`.
- [ ] Module files `0644 root:root`; scripts `0755`; nothing world-writable.
- [ ] `chmod -R ug-s` after extracting or restoring user data.

## 11. Restore and write targets
- [ ] Default target is a fresh `0700` dir created by the module, never the live path.
- [ ] A user-given target must not exist (or be empty), is resolved by `realpath`, has no symlink components, and is not under `/`, `/etc`, `/root`, `/usr`, `/home`, `/var/lib/mysql`.
- [ ] DB restore goes to a new database; `DEFINER=` clauses stripped.
- [ ] No in-place overwrite without an explicit confirmation and a pre-restore backup.

## 12. User-module identity
- [ ] The acting account comes only from `$_SESSION['username']`. A `user`/`account` request field is ignored or rejected. Fix #10
- [ ] Every path and database is derived from the session identity and re-checked against it.
- [ ] A user module cannot list or read other accounts' data (check `ls`, `glob`, DB listings).

## 13. Rate limits
- [ ] Expensive or destructive actions are limited (lock file or counter, one concurrent job per account). Fix #11
- [ ] Token-guessing endpoints are throttled.

## 14. Logging and audit
- [ ] Every state change appends one audit line: time, session user, action, target, result. No secrets. Fix #12
- [ ] Newlines and control characters stripped from logged values (log injection).
- [ ] Log file mode `0640`, rotated.

## 15. Installer and cron
- [ ] `install.sh` is idempotent, never overwrites config or secrets, supports `--dry-run`.
- [ ] Downloads pinned by version and checked against a hash baked into the script (not fetched alongside).
- [ ] No `curl | bash`.
- [ ] `/etc/cron.d/<name>` is `0644 root:root`, uses absolute paths, and calls no user-writable script as root.
- [ ] `chattr -i` / `+i` only on dirs written to and restored afterwards (use `find -xdev ! -type l`).

## Verified note: web reachability

On CWP Pro (Oct 2026) files under `/usr/local/cwpsrv/htdocs/resources/` are **not** served directly: requests to
`/resources/admin/modules/<file>.php` return 404 on ports 2031 and 2087. Module code only runs through
`index.php?module=` and `loader_ajax.php?ajax=`. Keep the guards anyway (defence in depth, other versions may differ),
but a missing guard in an include-only file that defines functions is LOW, not MEDIUM.
