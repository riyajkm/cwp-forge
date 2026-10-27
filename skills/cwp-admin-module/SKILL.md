---
name: cwp-admin-module
description: Builds a complete, secure admin module (addon) for CWP, Control Web Panel (CentOS Web Panel), on the admin panel at port 2030/2031. Covers the module page, AJAX through loader_ajax.php, CSRF, root engine calls through a verb allowlist, Bootstrap 3 / Supr UI, language file, admin menu entry, and an installer that handles chattr +i and survives CWP updates. Use when asked to create, extend, review or fix a CWP admin module, admin addon, admin menu item, or loader_ajax handler.
---

# CWP admin module

Admin modules are plain PHP files that CWP includes inside its own layout. Most of CWP is ionCube-encoded, so everything below comes from observed behaviour (see `references/`). Target the live server's PHP; write code that also runs on PHP 7.2 (no `match`, no `str_contains`, no typed properties).

## Workflow

1. **Requirements.** Ask or decide: module name (`^[a-z][a-z0-9_]{1,40}$`), what it reads (CWP DB `root_cwp`, files, `/scripts/*`), what it changes, and which changes need root. List every state-changing action; each becomes a POST+CSRF verb.
2. **Scaffold.** Run `scripts/new-admin-module.sh <name> --title "Title" --out ./<name>-module`. It renders `templates/` (page, lib, ajax file, language ini, menu snippet, engine, install, uninstall, fix-menu) and `php -l`s the PHP. It never writes to `/usr/local/cwpsrv`.
3. **Implement in this order:**
   - `cwp/modules/<name>/lib.php`: add verbs to `<name>_check_args()` (verb allowlist plus per-flag validators) and cases to `<name>_dispatch()`. Reads are GET, writes are POST+CSRF.
   - `engine`: the root-side script. Re-validate every argument there; the PHP allowlist is only the first gate.
   - `cwp/modules/<name>.php`: UI. Keep all markup escaped (`esc()` in JS, `<name>_h()` in PHP).
   - `cwp/modules/language/en/<name>.ini`: every visible string.
4. **AJAX.** Always `loader_ajax.php?ajax=<name>&acc=<action>`, handled by `addons/ajax/ajax_<name>.php`, guarded by `if(!isset($ajax_file)){echo "invalid access";exit();}`. `index.php?module=<name>&acc=...` returns the whole HTML layout and is useless. Details: `references/ajax-and-session.md`.
5. **CSRF.** Token = `hash_hmac('sha256', '<name>_csrf', $_SESSION['token'])`, embedded in the page, sent as POST field `csrf`, checked with `hash_equals`. Never call `session_start()` and never write `$_SESSION` (writes do not persist).
6. **Engine calls.** `proc_open` with an argument array (no shell), fixed env, timeout, output caps. Never `shell_exec`, `exec`, `system`, backticks or `escapeshellarg` string building. See `references/security.md`.
7. **UI.** Bootstrap 3 + Supr theme, jQuery 2.1.1. Wrap AJAX in an explicit `$.Deferred()`, add a `click` fallback for tabs, no CDNs, scope CSS under `#<name>`. See `references/ui-supr-bootstrap3.md`.
8. **Menu.** One `<li>` appended (idempotently) to `resources/admin/include/3rdparty.php`; created if missing. Done by `fix-menu`, never by hand-editing CWP core files.
9. **Install.** `install.sh` (dry-run unless `--apply`) copies the payload to `/usr/local/lib/<name>/`, installs the engine, then runs `fix-menu`, which unlocks only the paths it writes into (`chattr -i`), copies files, appends the menu line and restores the flags. A daily cron and `/root/.cwp_autoupdate.sh` re-run it so CWP updates cannot silently remove the module. See `references/install-and-updates.md`.
10. **Test on a live server** (checklist below). Do not report done on `php -l` alone.

## Hard rules

- Guards: page file `if(!isset($include_path))`, AJAX file `if(!isset($ajax_file))`, plus `$_SESSION['logged']` and `$_SESSION['token']` checks in the shared lib.
- Prefix every global function and constant with the module name; other modules share the same PHP process (a bare `h()` can collide).
- Every input: type-check (`is_string`), regex-validate to a whitelist, then use. Account names `^[a-z][a-z0-9_]{0,31}$`. Paths: absolute, no `..`, no control characters, then `realpath` under an allowed root.
- SQL: prepared statements on `$mysql_conn` (pass the handle from the entry file; it is a loader-scope variable). Select only the columns you read.
- JSON responses: `{"ok":true,"data":...}` or `{"ok":false,"error":"..."}` with `JSON_HEX_*` flags and `Cache-Control: no-store`.
- No secrets in the module tree or in the page. Engine files holding secrets: root, 0600.
- Do not modify CWP core files (`menu.php`, `login.php`, hooks). Only append to `3rdparty.php`.
- Use absolute `require` paths (`__DIR__`); cwpsrv's include_path is not the module directory.
- cwpsrv pools run as root with a minimal env (no HOME). Set `HOME`, `PATH`, `LANG` yourself for child processes.

## Test checklist (on a real CWP server, with a scratch admin login)

1. `php -l` every PHP file with `/usr/local/cwp/php71/bin/php -l` (that binary is PHP 8.3 on current builds).
2. Logged out: `curl -sk 'https://HOST:2031/loader_ajax.php?ajax=<name>&acc=status'` returns an empty body or an error, never data.
3. Logged in, GET a write action (`acc=refresh`): 405. POST without `csrf`: 403. POST with a wrong token: 403. POST with the right token: 200.
4. Bad input: account `x;id`, `../etc`, an over-long string, an array parameter (`account[]=a`): clean `ok:false`, engine never started (check `ps` or the engine log).
5. Escaping: store `<img src=x onerror=alert(1)>` as a value shown by the page (for example a domain or package label in a scratch DB row) and confirm it renders as text.
6. UI: load the page with the browser console open; tabs switch by click; failed AJAX shows an alert; no CDN requests.
7. Lifecycle: `install.sh` dry-run output matches `--apply`; run `--apply` twice (second run reports "already in place"); `chattr +i` the module dir, run `fix-menu --apply`, confirm the flag is restored; `uninstall.sh --apply` removes files and the menu line and leaves other modules' menu lines.
8. Update survival: run `/root/.cwp_autoupdate.sh` (or `fix-menu --apply`) after deleting the menu line; it comes back.

## References

- `references/ajax-and-session.md`: loader_ajax.php contract, variables, session and CSRF facts.
- `references/ui-supr-bootstrap3.md`: theme classes, jQuery 2.1.1 quirks, tab fallback, notifications.
- `references/security.md`: threat model, runner rules, validation catalogue, review checklist.
- `references/install-and-updates.md`: immutability, installer flow, surviving CWP updates, paths.
