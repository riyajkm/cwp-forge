# Root job queue for user-panel modules

Problem: a customer-facing module sometimes needs an action only root can do (rebuild a vhost, fix permissions, read quota, restart a per-user service). The panel process must not run arbitrary root commands on behalf of a request, and there is no setuid helper to lean on.

## Design (default)
```
browser --(POST + CSRF)--> user module (panel PHP)
   validates session user + action + args
   writes /var/spool/<name>/incoming/<user>.<id>.json  (atomic: create exclusive tmp, rename)
root cron (every minute) --> process-jobs.php
   flock, claim by rename -> processing/, lstat checks, strict JSON shape,
   user re-checked against the real account, allowlisted handler, argument-array exec
   writes results/<id>.json (mode 0600), moves job to done/
browser --(GET status, polling)--> module reads results/<id>.json only if result.user == session user
```
No setuid, no sudo rules, no listening socket, no API key. The trust boundary is the spool directory: it is owned by the panel uid with mode 0700, so customers (shell, FTP, cron, PHP in their own site) cannot create or edit jobs.

## Who is the panel uid? (VERIFY)
Admin pools run as root. Check the user panel: `ps -o user=,pid=,cmd= -C php-fpm,cwpsrv | sort -u` and the pool config `grep -E '^(user|group)' /usr/local/cwp/php71/etc/php-fpm.d/*.conf`. If it is root, `PANEL_UID=0` (default). If not, install with `PANEL_UID=<uid> ./install.sh --apply` and set `CWPMOD_EXAMPLE_PANEL_UID` (rendered as `<NAME>_PANEL_UID`) in `process-jobs.php`; the processor then accepts job files owned by that uid and chowns results to it. A non-root panel uid makes the processor the only privileged component, which is the safer setup.

## Job format
```json
{"v":1,"id":"<32 hex>","user":"alice","action":"usage-report","args":{"top":10},"ts":1730000000}
```
Exactly these keys in this order. File name must be `<user>.<id>.json`. Max 4096 bytes. The module fills `user` from `$_SESSION['username']` and nothing else.

## Writing a new action
1. Module: add a case to `<name>_job_args()` returning typed, range-checked args (`null` rejects). Keep the pending-job cap.
2. Processor: add `<name>_action_<verb>(string $user, array $args): array` and register it in `<name>_handlers()`. Re-validate args (types, ranges, enums) inside the handler. Throw `RuntimeException` for expected failures; the browser only gets a generic message, the log gets the detail.
3. Execute with the argument-array helper (`<name>_exec([...])`), never a string. Use `runuser -u <user> -- cmd` when the action should run with the customer's rights.
4. Paths derived from the user: build from `/home/<user>`, reject symlinks (`is_link`), use `realpath` plus prefix check, do not follow links as root.
5. Idempotent handlers: a job may be replayed after a crash. Put side effects behind checks.
6. Add a forged-job test (see the SKILL.md checklist).

## Hardening already in the template
- Exclusive create (`fopen 'x'`) then `rename`: no half-written job, no planted file reuse.
- Processor: `lstat` (regular file, size cap, owner uid), atomic claim via `rename`, strict key list, regex for id/user, file name must match body, user must be a real account (`posix_getpwnam`, uid >= 1000, home `/home/<user>`), allowlist of actions.
- Single instance via `flock`; per-run job cap; results and finished jobs expire.
- Per-user pending cap in the module (3), poll cap in the UI (40 x 3 s).

## Alternatives
- **systemd path unit** instead of cron polling (lower latency): `x.path` with `PathExistsGlob=/var/spool/<name>/incoming/*.json` and `Unit=x.service`; the service runs the same `process-jobs.php`. Keep the flock.
- **CWP admin API (port 2304)** from the root processor, for actions CWP exposes (`/scripts/cwp_api` groups: account, webservers, apps). Keep the key in a root-only file read by the processor, never in the user module.
- **Rejected**: setuid binaries, `sudoers` entries for the panel user with wildcards, a root daemon accepting unauthenticated local connections, writing job files into the customer's home (customer controls them; root would have to treat them as hostile and symlink-safe).

## Limits
Latency up to one cron minute (UI polls). Throughput is a few dozen jobs per minute. Long jobs should be started detached by the handler and report progress through a status file under `/var/lib/<name>`.
