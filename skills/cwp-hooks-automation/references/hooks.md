# CWP action hooks

Source: https://wiki.centos-webpanel.com/action-hooks [V]; reliability from forum https://forum.centos-webpanel.com/functions/cwp-account-hooks-not-work!!/ [F]; internals from a live server [V field notes].

## Events

| Hook function | File (under `/usr/local/cwpsrv/htdocs/resources/admin/hooks/`) | Values passed |
|---|---|---|
| `account_new` | `account/account_new.php` | username, domain |
| `account_remove` | `account/account_remove.php` | username |
| `account_suspend` | `account/account_suspend.php` | username |
| `account_unsuspend` | `account/account_unsuspend.php` | username |
| `account_new_domain` | wiki lists `account_remove_domain.php` for it (typo); use `account/account_new_domain.php` and test | username, domain |
| `account_new_subdomain` | `account/account_new_subdomain.php` | username, subdomain, domain, fullsubdomain |
| `account_remove_domain` | `account/account_remove_domain.php` | username, domain |
| `account_remove_subdomain` | wiki lists `account_new_subdomain.php` for it (typo); use `account/account_remove_subdomain.php` and test | username, subdomain, domain, fullsubdomain |
| `dns_serial_update` | `dns/dns_serial_update.php` | domain, status, username, reseller? |
| `dns_new_zone_add` | `dns/dns_new_zone_add.php` | same |
| `dns_new_subdomain_add` | `dns/dns_new_subdomain_add.php` | same |
| `dns_zone_remove` | `dns/dns_zone_remove.php` | same |
| `dns_subdomain_remove` | `dns/dns_subdomain_remove.php` | same |

DNS array looks like `[domain, status=OK, username]` plus `reseller` (=1 for a reseller account, or the reseller's name for a sub-account). Whether the array is associative or positional for each event is [U]: the stub in `templates/hook_stub.php` handles both and can dump the raw array on first run so you learn the shape on your version.

## Contract

- Create the file; define a function **named exactly as the file** (minus `.php`), one array argument. CWP runs it automatically. The file is not executed standalone.
- Official example:

```php
<?php function account_new($array){ file_put_contents('/tmp/account_new.txt', print_r($array,true)); }
```

- Hooks are called by CWP's encoded code (`include/hooks.php` is ionCube-encoded [V field]); you cannot read how they are dispatched.
- Runs in the panel's PHP: pools run as root, env is minimal (`PATH`, `TMP`, `HOSTNAME` only, no `HOME`) [V field]. PHP is 8.3 on a current build although the folder is `php71` [V field]; older docs say 7.2. Use syntax valid on both where practical.
- Do not call `session_start()` and do not exit/die inside a hook: you would end the panel request.
- A fatal error in a hook may break the panel action. Wrap in try/catch (`\Throwable`) and return quietly.

## Reliability

| Observation | Source |
|---|---|
| `echo` output is not shown; write to a file/log | [F] |
| `account_new` works | [F] |
| `account_unsuspend` reported not firing (2024) | [F] |
| Hooks fire when the action goes through CWP's code (panel/API). `/scripts/cwp_api` and the legacy API: unknown | [U] |
| Hook files can be wiped by an update | [U] keep a copy, re-apply (see update-survival.md) |
| No hooks for backups, SSL issue, mailbox create/delete, package change, login | [U] |
| cPanel-style `postwwwacct` and `/usr/local/cwp/.conf/hooks` do not exist | [V searched] |

Design consequence: treat a hook as a fast path, and back it with a reconciling job (cron comparing `/scripts/list_users` or `root_cwp.user` against your state) so a missed event is caught within a day.

## Testing a hook

1. Install the stub with debug on (`touch /var/lib/cwp-forge/hook-debug`) so the raw array is dumped to the log.
2. Trigger from the panel: create a throwaway account (user `alice`, domain `example.com` on a lab VM).
3. Read `/var/log/cwp-forge/hooks.log` and the worker log.
4. Repeat through the REST API (`account add` / `susp` / `unsp`) and through `/scripts/cwp_api account suspend_user alice`; write down which paths fire which hooks on your CWP version.
