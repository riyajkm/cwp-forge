---
name: cwp-hooks-automation
description: Builds safe automation on a CWP (Control Web Panel, CentOS Web Panel) server - action hooks for account and DNS events, cron jobs in /etc/cron.d, systemd timers, /scripts/* helpers, and self-healing so custom modules, menu lines and hooks survive CWP updates (/root/.cwp_autoupdate.sh, chattr-aware re-apply from a kept copy). Use when the user asks for a CWP hook, account_new or account_suspend automation, a cron or timer on a CWP server, how to keep a CWP module or branding after an update, or which /scripts helper to call.
license: MIT
compatibility: Runs on the CWP server as root (AlmaLinux/Rocky/CentOS family). Bash templates need util-linux (flock, setsid) and cron or systemd. Facts tagged [V] verified on a live CWP Pro server (AlmaLinux 8, Oct 2026) or in the official wiki, [F] forum, [U] unverified.
---

# CWP hooks and automation

Everything here runs as root on a customer's production server: test on a disposable CWP VM first, read the dry-run, then apply.

## 1. Action hooks

Official page: https://wiki.centos-webpanel.com/action-hooks. Details, argument shapes and the reliability table: [references/hooks.md](references/hooks.md).

- Hooks are **PHP**, not shell. A file named after the event defines a function with the same name taking one array. CWP calls it. [V wiki]
- Location: `/usr/local/cwpsrv/htdocs/resources/admin/hooks/account/` (`account_new`, `account_remove`, `account_suspend`, `account_unsuspend`, `account_new_domain`, `account_remove_domain`, `account_new_subdomain`, `account_remove_subdomain`) and `.../hooks/dns/` (`dns_serial_update`, `dns_new_zone_add`, `dns_new_subdomain_add`, `dns_zone_remove`, `dns_subdomain_remove`).
- `echo` output is not visible. Log to a file.
- `account_new` works; `account_unsuspend` was reported as not firing [F 2024]. Do not build critical flows on a single hook: add a reconciling cron or an API poll.
- No hooks are documented for backups, SSL issue, mailbox create/delete, package change or login. [U] Poll instead.
- The hook runs inside the panel's PHP (pools run as root, minimal env, no `HOME`) [V]. Keep it tiny: validate, then hand off to a detached worker. Never run a long job inline, or the panel request hangs.

Start from `templates/hook_stub.php` (rename the file and function to the event) and `templates/hook-worker.sh` (validates args, logs, locks, dry-run by default).

## 2. Cron

- Your own jobs: a file in `/etc/cron.d/<name>` (root-owned, mode 0644, a `user` column, explicit `PATH`). Use letters, digits, hyphen in the name. [U: general cronie behaviour]
- CWP's own jobs run PHP as `/usr/local/cwp/php71/bin/php -q <file>` from `/var/spool/cron/root`. [V] The directory name is historical; the binary is PHP 8.3 on a current build [V field] (older sources say 7.2): write portable syntax and check `php -v`.
- Per-user crons are in `/var/spool/cron/USER`. Run scripts as the user, use full interpreter paths (`/opt/alt/phpNN/usr/bin/php` for the PHP selector), `chmod +x`, test with `su USER -s /bin/bash`. Check `/var/log/cron`. [V wiki]
- Remove a leftover `SHELL=/usr/local/cpanel/bin/jailshell` line in cron files of imported cPanel accounts.

## 3. Surviving CWP updates

CWP updates overwrite core files: the `original` user theme, `menuConf.php`, `include/3rdparty.php` edits, default vhost/DNS templates, anything you patched. Hook files may be wiped too [U]. Full pattern: [references/update-survival.md](references/update-survival.md).

1. Keep the source of truth outside CWP's tree (e.g. `/opt/<yourname>/keep/` mirroring `/`).
2. If `/root/.cwp_autoupdate.sh` exists CWP runs it after each update [V wiki]. Append one guarded line there that calls the self-heal script. Do not replace the file (it may hold the user's branding).
3. Add a daily cron (or systemd timer) running the same self-heal as a safety net for updates that skip the hook.
4. Self-heal is idempotent: compare, copy only on difference, append a menu line only when missing, respect `chattr +i` (lift only on the dirs/files you touch, restore after, never recursive on symlinks).

Templates: `templates/cwp-selfheal.sh`, `templates/cwp-selfheal.cron`, `templates/cwp-selfheal.service` + `.timer`.

## 4. Helpers (`/scripts/*`)

Prefer these to raw service commands: `list_users`, `list_domains`, `list_subdomains`, `whoowns DOMAIN`, `restart_cwpsrv`, `reload_cwpsrv`, `restart_httpd`, `phpfpm_rebuild_user_conf`, `cwpsrv_rebuild_user_conf`, `cwp_api webservers rebuild_user U`, `cwp_api account fix_perms U`, `add_alert TYPE "text" [LOGFILE]`, `update_cwp`. Catalogue with usage notes: [references/scripts-helpers.md](references/scripts-helpers.md).

`scripts/cwp-env-check.sh` is a read-only survey (hook dir contents, autoupdate file, immutable flags, cron.d, PHP version). Run it before designing anything.

## 5. Safe automation rules

Checklist in [references/safe-automation.md](references/safe-automation.md). Short form:

- Idempotent: running twice equals running once.
- Dry-run by default; `--apply` to act. Print the plan. Ask the user before the first `--apply`.
- Validate every argument (`^[a-z][a-z0-9]{0,31}$` for users, a strict domain regex) and pass them as separate argv items, never through a shell string.
- `flock -n` so overlapping runs exit quietly; wrap long steps in `timeout`.
- Log with timestamps to `/var/log/<yourname>/`; rotate with logrotate.
- Back up before modifying; keep a revert path.
- Surface failures in the panel with `/scripts/add_alert alert-danger "..." /path/to.log`.
- Write the hook stub so a worker failure can never break CWP's own action (catch everything, return).

## Verify

After applying: trigger the event (create a throwaway account, e.g. user `alice` on `example.com`), check the worker log, run the self-heal twice (second run must report no changes), then simulate an update by editing a kept file in the CWP tree and re-run.
