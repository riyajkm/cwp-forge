---
name: cwp-api
description: Calls the CWP (Control Web Panel, formerly CentOS Web Panel) REST API on port 2304 to create, suspend, unsuspend, change, list and delete hosting accounts, packages, domains, email, FTP, MySQL, AutoSSL, DKIM and cron jobs, and to mint panel autologin links. Covers API Manager keys, IP allowlists, per-function permissions, response and error handling, the WHMCS/Blesta billing lifecycle, and the local /scripts/cwp_api shell alternative. Use when the user mentions the CWP API, CWP API key, API Manager, port 2304, WHMCS or billing integration with CWP, or wants a PHP/Python/bash client for Control Web Panel.
license: MIT
compatibility: Needs network access to the CWP server on TCP 2304 (or shell access on the server for /scripts/cwp_api). Client templates need curl, PHP 7.4+, or Python 3.6+. Facts checked against the official docs of Oct 2026; verify on your CWP version.
---

# CWP REST API

Endpoint: `https://HOST:2304/v1/FUNCTION/`. Always `POST`, form-encoded. Every call carries `key` and `action`. Full function list: [references/endpoints.md](references/endpoints.md).

## Setup (once, by the admin)

1. Admin panel > **CWP Settings > API Manager > Allow new Api access**.
2. Set **Ip Origin** to the caller's IP (never `ALL` or `%` in production), **Owner** `root` or a reseller (reseller keys only see that reseller's customers and packages), **Format Request** JSON, then grant only the function x action rows needed.
3. Open TCP 2304 in the firewall (CSF) for the caller IP only.
4. One key per integration. Treat it like a root password.
5. Smoke test (key from env, not argv): `scripts/cwp-api.sh testconex` should print `{"status":"OK","result":"Conex Api OK"}`.

## Calling rules

- Send `key` and `action` on every call. Actions: `add`, `udp`, `del`, `list`, `susp`, `unsp`, plus `renew` (autossl).
- Success is `{"status":"OK",...}`. Failure is `{"status":"Error",...}` usually with HTTP 200. Data sits in `msj`, `result` or `message` depending on the function. Always check `status`, never only the HTTP code.
- Treat a non-JSON body as an error (a bad parameter can return an HTML "Slim Application Error" page).
- Exceptions to the status rule: `accountquota` has no `status`; `account del` returns `{"status":"OK"}` followed by an HTML log (parse only the leading JSON); `packages del` returns an empty body.
- `packages add` does not return the new id: call `packages list` afterwards.
- After a timeout never blindly retry an `add`. `list` first and reconcile.
- Verify TLS. Use the insecure option only for a self-signed lab server, or pin the CA.
- Never put the key in argv, URLs or logs. a forum report says CWP echoes the key inside `Unauthorized action ...` errors [F], so mask it before logging.
- Every call is logged server-side in `/var/log/cwp/cwp_api.log` (first place to look when debugging). `debug=1` adds detail where supported.

## Gotchas that cost hours

- Permissions are per function and per action. `Unauthorized action ...` means that exact row is not ticked even if the function looks enabled.
- `changepack` needs the package **id**, not the name. Resolve via `packages list`. `account udp package=<name>` takes a name.
- Field names differ between calls: `account add` uses `limit_nproc` / `limit_nofile`, `account udp` uses `processes` / `openfiles`. Wrong names are silently ignored.
- `account add`: `package` that does not exist falls back to the first package. Check the name first.
- `encodepass` with any value (even `false`) makes the API base64-decode `pass`. Omit it normally.
- `email`: only `add` uses `email` (local part). Everything else uses `mailbox` (full address).
- `admindomains list` returns nothing without `type=domain|subdomain`.
- `ftp udp` / `del` need the FULL login `userftp@domain`.
- `cronjobsusers` values must be URL-encoded (`--data-urlencode`); `del` needs the exact `execute` and `command` of the job. `list` with no jobs returns an Error "There are no scheduled tasks" (not a failure of the call).
- Autologin URLs (`user_session`) are single-purpose tokens: mint on click, redirect, never store or email.
- `account_metadata` and `email list` return password hashes: never log them.
- Key typos in responses are real (`domais`, `subdomins`, `domian_max`).

## Pick a client

| Need | Use |
|---|---|
| One-off call or shell scripting from a workstation | `scripts/cwp-api.sh` (dry-run first) |
| PHP app or billing module | `templates/cwp_api.php` |
| Python tooling | `templates/cwp_api.py` (stdlib only) |
| Sourceable bash functions in your own scripts | `templates/cwp_api.sh` |
| You are on the CWP server as root | `/scripts/cwp_api` (see [references/local-shell-api.md](references/local-shell-api.md)) |

### scripts/cwp-api.sh

```bash
export CWP_HOST=server.example.com     # host or host:port, default port 2304
export CWP_API_KEY=...                 # or CWP_API_KEY_FILE=/path/to/key (mode 600)
scripts/cwp-api.sh account action=list
scripts/cwp-api.sh account action=susp user=alice            # mutating: prints the request only
scripts/cwp-api.sh account action=susp user=alice --apply    # performs it
```

Read-only actions (`list`, `testconex`) run immediately. Mutating actions (`add udp del susp unsp renew`) print the redacted request unless `--apply` is given. `--dry-run` forces print-only. `--insecure` skips TLS verification (documented opt-out for self-signed certs). The key travels to curl on stdin via `-K -`, never in argv. Exit codes: 0 OK, 2 API error, 3 non-JSON body, 4 usage, 5 transport.

Show the dry-run output to the user and get a yes before using `--apply` on suspend, delete or password changes.

## Billing and lifecycle

Map billing events to calls (order active -> `account add`; overdue -> `susp`; paid -> `unsp`; plan change -> `changepack`; terminate -> `account del`; usage sync -> `account list`). Patterns, idempotency, WHMCS/Blesta/HostBill notes and known bugs of the old modules: [references/billing-patterns.md](references/billing-patterns.md).

## Security checklist

- IP-restricted key, minimal function x action grants, reseller-owned key when the integration only manages one reseller.
- TLS verify on; key from env or secret store; masked in logs; rotate by creating a new key then deleting the old.
- Validate `user`/`domain` inputs client-side (lower-case alphanumerics for `user`) before sending.
- Keep CWP patched: the API/admin surface has had critical remote-code-execution vulnerabilities, so do not expose 2304 to the internet.

## Unverified

Marked `[U]` in the references. Notably: the firewall permission row name, whether `account list` accepts a username filter, and whether API calls fire action hooks. The panel's **API Manager > Interactive Documentation** tab is the authoritative list for your version.
