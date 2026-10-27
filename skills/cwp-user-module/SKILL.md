---
name: cwp-user-module
description: Builds a secure customer-panel (user area) module for CWP, Control Web Panel (CentOS Web Panel), on ports 2082/2083. Covers the PHP logic file in user_files/modules, Twig template mod_<name>.html, language ini, menuConf.php registration, per-user identity from $_SESSION['username'], AJAX with ?acc=, CSRF, and a root job queue (validated JSON jobs in a root-owned spool processed by a root cron) for privileged actions. Use when asked to create, extend, review or fix a CWP user module, client area addon, customer panel feature, or user menu item.
---

# CWP user module (customer panel)

User modules run in the customer panel for ANY customer, so the threat model is "hostile logged-in tenant". The documentation is thin (2020) and parts are unverified; every step marked VERIFY must be checked on the target CWP version (`references/verify-per-version.md`).

## Workflow

1. **Requirements.** Module name (`^[a-z][a-z0-9_]{1,40}$`), what the customer sees, and which actions need privilege (anything outside the user's own data that the panel process cannot or must not do). List each as a queue action with typed arguments.
2. **Scaffold.** `scripts/new-user-module.sh <name> --title "Title" --out ./<name>-module` renders `templates/` and lints the PHP. It never touches `/usr/local/cwpsrv` unless `--install --apply`.
3. **Files (all rendered for you):**
   - `/usr/local/cwpsrv/var/services/user_files/modules/<name>.php`: logic. Sets `$mod[...]` for the template; on `?acc=` echoes JSON and exits.
   - `/usr/local/cwpsrv/var/services/users/cwp_lang/en/<name>.ini`: labels (English is mandatory), available in Twig as `langmod.KEY`.
   - `/usr/local/cwpsrv/var/services/users/cwp_theme/<theme>/mod_<name>.html`: Twig template; receives `mod`, `langmod`, `users`. Never edit the `original` theme in place without a self-heal; clone it and list your themes in `THEMES`.
   - `htdocs/resources/conf/user_panel/menuConf.php`: add a block, never replace the file (other modules' entries live there).
4. **Identity.** The only identity is `$_SESSION['username']`. Validate it (`^[a-z][a-z0-9_]{0,31}$`, `/home/<u>` exists). Never accept a username, path or account from `$_GET/$_POST` as "who". Every query, path and job is scoped to that name.
5. **AJAX.** Same route with `&acc=<action>`: `./{{users}}/index.php?module=<name>&acc=<action>`; there is no separate AJAX folder. Reads GET, writes POST + CSRF; respond with `{"ok":..}` JSON and `exit`.
6. **CSRF.** HMAC of a per-login session secret (`tokenuser`, falling back to `token`) bound to the username; empty secret means refuse writes (fail closed). VERIFY which session keys exist.
7. **Privileged actions: root job queue** (`references/root-job-queue.md`). The module never shells out as root. It validates the request, writes a small JSON job atomically into `/var/spool/<name>/incoming/` (root/panel-owned, mode 0700), and a root cron (`process-jobs.php`) validates it again, runs an allowlisted handler with an argument array, and writes a result the module polls. User identity in the job comes from the session, and the processor checks it against the file name and the real account.
8. **UI.** Twig + Bootstrap 3 (Inspinia-style) + jQuery. Escape every Twig output (`|e`, `|e('html_attr')`), keep JS free of `{{`, `{%`, `{#`, pass data via `data-*` attributes, explicit `$.Deferred()` around AJAX. `references/twig-and-ui.md`.
9. **Register and install.** `install.sh` (dry-run default, `--apply`): payload to `/usr/local/lib/<name>/`, spool, processor cron, `fix-module` (copies files, patches `menuConf.php` with backup + `php -l` + rollback, handles `chattr +i`), daily self-heal cron and `/root/.cwp_autoupdate.sh` hook. Then enable the module for a package under User Accounts > Features, Themes and Languages (VERIFY per version).
10. **Test** with the checklist below on a real server with two test accounts.

## Hard rules

- No `shell_exec`, `exec`, `system`, backticks, or string-built commands anywhere in the module. Per-user commands that must run unprivileged go through the queue handler (`su`/`runuser` with an argument array) or are avoided.
- Paths from users: `realpath` and require the prefix `/home/<session user>/`; reject symlink escapes. The queue processor never opens files inside a user-writable directory as root.
- Never trust job content: the processor re-validates shape, id, user, action, args, file owner, size, and that the user is a real hosting account.
- No per-user JSON state in the home directory that root later reads. State the processor trusts lives under `/var/lib/<name>` or the spool.
- Do not embed CWP API keys or any admin secret in the user module. If an admin API call is needed, do it in the root processor.
- No DB access to `root_cwp` from the user module unless VERIFIED available and scoped; prefer the queue.
- Write PHP that also runs on 7.2 (cwpsrv builds differ); use absolute `require` paths.
- Do not run the module as the template demo in production: replace the `usage-report` example with your own action and keep the allowlist tight.

## Test checklist

1. `php -l` module and processor with the panel's PHP binary.
2. Logged out: module URL and `&acc=submit`/`status` give no data.
3. Account A cannot read account B's job: take A's job id, request `acc=status&id=<id>` as B: state `unknown`.
4. `acc=submit` by GET: 405. POST without or with a wrong `csrf`: 403. Another user's `csrf` value: 403.
5. Forged jobs: drop a hand-written JSON file in the spool (as root) with a mismatched file name, extra keys, an unknown action, `user` = `root` / `../x` / a nonexistent account, a symlink, a 1 MB file: the processor logs a reject and runs nothing.
6. As a customer with shell access: confirm you cannot list or write `/var/spool/<name>` (permission denied).
7. Processor concurrency: run two instances; the second exits (flock). Kill mid-run; the job in `processing/` is not re-run blindly (decide: re-queue or reject, document it).
8. Menu: entry appears for an enabled package, absent otherwise; direct `?module=<name>` for a package without the feature must not work (VERIFY).
9. Lifecycle: install dry-run equals apply; second apply is a no-op; `menuConf.php` still lints and other entries are intact; uninstall removes only the block between the markers; after a CWP update (or running the autoupdate script) everything is back.

## References

- `references/root-job-queue.md`: design, file format, handler authoring, alternatives (systemd path unit), threat analysis.
- `references/verify-per-version.md`: what is undocumented or version-specific and how to check each item.
- `references/twig-and-ui.md`: template contract, Twig escaping, JS rules, toasts, dev toggle.
- For the admin side of the same feature, use the `cwp-admin-module` skill (different paths, `loader_ajax.php`, `$_SESSION['token']`).
