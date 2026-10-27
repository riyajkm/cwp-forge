# Safe automation checklist (root scripts on a CWP server)

1. **Idempotent.** Re-running changes nothing the second time. Use "ensure" semantics: create if missing, append if absent (`grep -qF`), copy if `cmp` differs.
2. **Dry-run first.** Default to printing the plan; an explicit `--apply` acts. In skills and docs: show the dry-run output, wait for the user's yes.
3. **Strict input.** Event data is untrusted (a customer chooses a domain). Validate: user `^[a-z][a-z0-9]{0,31}$`, domain `^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$` (lower-case; punycode for IDN). Reject, do not sanitise. Pass values as argv items; in PHP use `proc_open([...])` with an array and no shell; in bash always quote.
4. **No blocking.** A hook must return in milliseconds. Hand off to a detached worker (`setsid -f`, stdio to `/dev/null`, otherwise an SSH/PHP caller hangs on the inherited pipe [V field]). Inside the worker use `timeout`.
5. **Locks.** `exec 9>/var/lock/NAME.lock; flock -n 9 || exit 0` for cron/timer jobs; `flock -w 30` for per-event workers that must not be dropped.
6. **Logging.** One line per action, ISO timestamp, event, user, result, to `/var/log/<name>/`. Never log passwords, API keys, hashes. Add a logrotate stanza (weekly, rotate 8, compress, missingok, notifempty).
7. **Backups and revert.** Before overwriting a file, keep `file.bak.<timestamp>` (or rely on the kept source copy). Document the one command that undoes the change.
8. **Least privilege.** Hooks run as root inside the panel; the worker should drop to the account with `runuser -u USER -- cmd` when it touches user data. Never `chmod 777`. Scripts 0750 root:root; cron.d files 0644 root:root.
9. **Environment.** Cron and the panel have a minimal environment: set `PATH`, call interpreters by absolute path, do not rely on `HOME`.
10. **Fail soft toward CWP, loud toward the admin.** A failing worker must never break the panel action: catch everything in the hook. Report with `/scripts/add_alert alert-danger "text" LOGFILE`.
11. **Reconcile.** Hooks can be missed (`account_unsuspend` reports). Add a daily job that compares current state (`/scripts/list_users`) to what your automation believes.
12. **Test on a lab VM**, with throwaway names (user `alice`, `example.com`). Never test destructive paths on production.
13. **Updates.** Assume CWP updates revert anything under `/usr/local/cwpsrv/`; keep a copy and self-heal (update-survival.md).
14. **No curl-pipe-bash, no telemetry**, pinned downloads with checksums.
15. **Service reloads.** Prefer `reload` over `restart`; batch changes and reload once.
16. **Security.** CWP has had critical RCE issues: keep it patched, keep API keys IP-restricted, and do not add world-reachable endpoints from a module without auth and CSRF checks.
