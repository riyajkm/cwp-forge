# Security for CWP admin modules

The cwpsrv PHP pool runs as root. A bug in a module is a root bug, and CWP itself has had unauthenticated RCE advisories. Treat every request parameter as hostile, even from a logged-in admin (CSRF and XSS turn an admin's browser into the attacker).

## Rules
1. **No shell.** Use `proc_open(array $cmd, ...)`. Never `shell_exec`, `exec`, `system`, `passthru`, `popen`, backticks, or `proc_open` with a string. `escapeshellarg` is a last resort for legacy code, not a design.
2. **Verb allowlist.** One PHP function (`<name>_check_args`) lists the verbs, their allowed flags and a validator per flag. Unknown verb, unknown flag, repeated flag, missing value: reject. The engine validates again.
3. **Fixed engine path and env.** Absolute binary under `/usr/local/lib/<name>/`, root-owned, not writable by anyone else. Env set explicitly (`PATH`, `HOME`, `LANG`).
4. **Detach long jobs** with `proc_open(['setsid','-f',BIN,...])` and stdio to `/dev/null`, so the request does not hang on inherited pipes. Poll a status verb instead of waiting.
5. **CSRF on every state change**: POST only, `hash_equals` on the HMAC token. GET must never change state.
6. **Session guard in the lib**, not only in the loader.
7. **Output encoding** at the sink (PHP `<name>_h`, JS `esc`). JSON with `JSON_HEX_*`.
8. **SQL**: prepared statements; whitelist column and table names when they vary; select only used columns; `LIMIT` large lists.
9. **Files**: accept only absolute paths, reject NUL/control characters and `..`, then `realpath` and require the result to start with an allowed root plus `/`. Open with `O_NOFOLLOW` semantics where possible; do not follow user-controlled symlinks as root. Never read user home files as root without a symlink check.
10. **Secrets**: never in the module tree, page source, JSON responses or logs. Files 0600 root.
11. **Errors**: short generic message to the browser, detail to a root-only log. No stack traces, no paths.
12. **Least data**: do not return password hashes, API keys or full config. Redact in the engine.
13. **Rate and size caps**: output cap in the runner (4 MB here), timeouts per verb, bounded list sizes.
14. **Do not weaken CWP**: no new unauthenticated endpoint, no `chmod 777`, no disabling of `open_basedir`/ModSecurity, no editing login files.

## Validators (copy as needed)
| Input | Rule |
|---|---|
| account | `^[a-z][a-z0-9_]{0,31}$` |
| database | `^<account>_[A-Za-z0-9_]{1,56}$` and prefix equals the account |
| domain | `^(?=.{1,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$` (lowercase first) |
| integer | `ctype_digit($v)` then range check |
| enum | `in_array($v, [...], true)` |
| email | `filter_var` plus no whitespace or `,;<>` |
| URL | `^https://[^\s]{1,1000}$` plus a reject list for quotes, backticks, `$` and backslash |
| path | absolute, `strlen <= 4096`, no `[\x00-\x1f]`, no `(^|/)\.\.(/|$)` |

## Review checklist
- Grep the module for `shell_exec|exec\(|system\(|passthru|popen|eval\(|assert\(|unserialize|extract\(|\$\$|include .*\$_` and any backtick operator. Each hit needs a written reason or removal.
- Every `$_GET/$_POST/$_REQUEST/$_COOKIE/$_SERVER` read goes through a validator before use. Array-typed parameters (`a[]=`) are handled (`is_string`).
- Every write action is in the `$writes` list with POST+CSRF.
- Page and AJAX file both start with their guard line.
- `innerHTML`/`.html()` calls only receive `esc()`d strings.
- Install scripts: dry-run default, no `curl | sh`, no world-writable files, no `chmod -R`.
- Run `claude-security`/`/security-review` on the diff before release.
