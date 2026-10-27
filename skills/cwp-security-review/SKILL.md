---
name: cwp-security-review
description: Security review of a Control Web Panel (CWP) admin or user module with severity-ranked findings and exact fixes. Use when asked to review, audit, harden or "check the security of" a CWP module, AJAX file, installer or engine script, before releasing a module, or when code touches $_SESSION, $_POST/$_GET, mysqli, shell_exec/proc_open, file paths, backups or restores in /usr/local/cwpsrv. Covers guards, admin session, CSRF, allowlists, shell injection, SQL, path traversal, XSS, secrets, permissions, rate limits and audit logs. Not for writing the module itself (use cwp-admin-module or cwp-user-module).
license: MIT
compatibility: Read-only review. Bundled scan script needs bash and grep. Ground truth is CWP Pro on AlmaLinux 8 with cwpsrv PHP 8.3.
---

# CWP module security review

CWP admin modules run inside cwpsrv, often as **root**. One injectable AJAX action is a root shell. Review accordingly.

## Workflow

1. **Scope.** List the files: page (`<name>.php`), AJAX (`addons/ajax/ajax_<name>.php`), libs (`<name>/*.php`), engine scripts, `install.sh`/`uninstall.sh`, cron files. Note whether the module is admin or user (user modules must never trust a client-supplied account).
2. **Scan.** Run `bash ${CLAUDE_SKILL_DIR}/scripts/cwp-review-scan.sh <module-dir>` (read-only). Every hit is a lead; open the file and confirm the data flow. Grep cannot prove safety, so a clean scan is not a pass.
3. **Walk the checklist** in [references/checklist.md](references/checklist.md) file by file. Trace every request value from entry to sink (shell, SQL, path, HTML).
4. **Report** findings ordered by severity, each with: id, file:line, why it is exploitable (one sentence: who can do what), and the exact fix from [references/fix-patterns.md](references/fix-patterns.md).
5. **Do not fix unless asked.** If asked, apply one fix per finding and re-run the scan.

## Severity

| Level | Meaning | Examples |
|---|---|---|
| CRITICAL | Remote or low-privilege path to root code execution or data loss | Request data reaches a shell string or SQL concatenation, restore to an arbitrary path, no session check on a root AJAX action |
| HIGH | Needs a logged-in admin/user, or leaks secrets | No CSRF on a state-changing action, stored XSS, path traversal on read, secret in argv or logs, user module trusting a posted username |
| MEDIUM | Defence in depth is missing | No verb allowlist (arguments still safe), `json_encode` without HEX flags, world-readable config, no audit line |
| LOW | Hygiene | No `set -euo pipefail`, verbose errors, no rate limit on a read-only action |

## Non-negotiables (CWP-specific facts)

- Guard every PHP file: pages `if(!isset($include_path)){echo "invalid access";exit();}`, AJAX files `if(!isset($ajax_file)){...}`. In the AJAX context `$include_path` is NOT set.
- `loader_ajax.php` rejects logged-out requests, but check `$_SESSION['logged']` and `$_SESSION['token']` yourself anyway.
- Never call `session_start()`; `$_SESSION` is populated by CWP's handler and writes do not persist. CSRF token = `hash_hmac('sha256', '<module>_csrf', $_SESSION['token'])`, compared with `hash_equals`.
- Privileged work: root CLI via `proc_open([...])` with an **argument array**, a verb allowlist and validated arguments. No shell string.
- User modules: identity only from `$_SESSION['username']`.
- Secrets never in argv, logs or responses: stdin, child environment, or `0600` files.

## Scan rule ids

`CWP-SH` shell, `SQL`, `PATH`, `XSS`, `SESS`, `CSRF`, `ID`, `SEC`, `NET`, `GUARD`, `AUTH`. Each prefix maps to the checklist section of the same topic.

## Report template

```
CRITICAL  CWP-SH-01  ajax_foo.php:42  shell_exec("tar ... $dir") with $dir from $_POST['dir']: any admin session (or a CSRF) runs commands as root.
          Fix: proc_open array + validate $dir (fix-patterns #5, #7).
```

End with: files reviewed, files not reviewed, and what a source review cannot show (runtime config, file modes on the server).
