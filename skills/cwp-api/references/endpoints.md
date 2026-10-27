# CWP API endpoint reference

Source: official docs https://docs.control-webpanel.com/docs/developer/api/ (rewritten 25 Oct 2026) unless tagged. `[F]` = forum/community claim, `[U]` = unverified or inferred. Check against **API Manager > Interactive Documentation** on your server.

All calls: `POST https://HOST:2304/v1/FUNCTION/`, form fields, plus `key` and `action`.

## Permission map

A key needs the function x action row ticked in API Manager. The internal permission names differ from the labels (`account/udp` is checked as "accout_upd" [F]).

| URL function | Actions | API Manager row |
|---|---|---|
| `account` | add, udp, del, list, susp, unsp | Account |
| `accountdetail` | list | Account Details |
| `account_metadata` | list | Metadata Account |
| `accountquota` | list | Account Quota |
| `quotalimit` | list | Quota limit |
| `changepack` | udp | Account pack change |
| `changepass` | udp | Change of password |
| `user_session` | list | Autologin |
| `packages` | add, udp, del, list | Packages |
| `admindomains` | add, del, list | Domains and Subdomains |
| `email` | add, udp, del, list, susp, unsp | Email |
| `emailadmin` | list | Email Admin Server |
| `ftp` | add, udp, del, list | FTP |
| `databasemysql` | add, del, list, susp, unsp | MySQL Databases |
| `usermysql` | add, udp, del, list | MySQL Users |
| `autossl` | add, del, list, renew | AutoSSL |
| `dkim` | add | Dkim (Domain) |
| `cronjobsusers` | add, del, list | Cronjobs Users |
| `typeserver` | list | Type Server |
| `firewall` | list (`modo`=status/on/off) | [U] row name not documented |
| `testconex` | none | always allowed for a valid key |

Presets in API Manager ("Enable Functions for"): CWP to CWP transfers, WHMCS, CLUSTER CWP, APP CWP.

## Common errors

| Text | Cause |
|---|---|
| `key does not exist` | wrong or deleted key |
| `No special characters are allowed!` | key contains non-alphanumerics (copy/paste junk, trailing newline) |
| `unauthorized host` | caller IP is not the key's Ip Origin (NAT? IPv6 vs IPv4?) |
| `Key off` | key disabled |
| `Unauthorized action ...` | function x action row not ticked. May echo the key [F]: mask |
| `All data is required` / `Some data is required` | missing parameter |
| `Check All Fields (only lower caps ...` | bad or duplicate username/domain |
| `user does not exist` | `user` is not an account |
| `Something went wrong` | e.g. `changepack` given a package name instead of an id |
| `Invalid function` | unsupported action (e.g. `dkim` only supports `add`) |
| HTML "Slim Application Error" | wrong or missing parameter on some functions |

Response shape: `{"status":"OK"|"Error", "msj"|"result"|"message": ...}`. Mostly HTTP 200 even on error.

## account

`/v1/account/`

| action | params | response |
|---|---|---|
| add | required: `domain`, `user` (lower-case alphanumerics), `pass`, `email`, `server_ips`. Optional: `package` (name or id; falls back to the first package if missing), `inode` (0 = unlimited), `limit_nproc`, `limit_nofile`, `autossl` (1; domain must already resolve to the server), `backup` (`on`/`off`), `lang` (default `en`), `reseller` (1), `encodepass` | `{"status":"OK"}` |
| udp | `user` + any of `email`, `package`, `server_ips`, `backup`, `inode`, `processes`, `openfiles` | `{"status":"OK"}` |
| susp / unsp | `user` | OK |
| del | `user` | `{"status":"OK"}` + HTML removal log (parse only the leading JSON) |
| list | none (returns every account the key may see) | `msj[]`: `package_name`, `idpackage`, `id`, `backup`, `username`, `email`, `setup_date`, `ip_address`, `domain`, `reseller`, `owner`, `diskused`, `disklimit`, `bandwidth`, `bwlimit`, `status` |

- `encodepass`: any value, even `false`, makes the API base64-decode `pass`. Omit it, or send `true` with a base64 password.
- `add` uses `limit_nproc`/`limit_nofile`; `udp` uses `processes`/`openfiles`.
- Filtering `list` by username server-side: [U]. Filter client-side, or use `accountdetail`.
- `del` removes the account including its removal log output. Back up first.

## changepack / changepass

- `/v1/changepack/` : `action=udp`, `user`, `package` = package **id** (a name fails with a bare error).
- `/v1/changepass/` : `action=udp`, `user`, `pass`. Changes the panel, SSH, FTP and main MySQL password.

## Account information (read-only)

- `/v1/accountdetail/` `user`: `result.domains[]` (`domain`, `path`, `email`), `subdomins[]`, `databases[]`, `account_info` (`directory`, `email`, `package_id`, `package_name`, `space_disk`, `space_usage`, `space_available`, `db_max`, `db_used`, `state`, `reseller`, `bandwidth`, `bandwidth_used`, `ftp_accounts`, `ftp_accounts_used`, `email_accounts`, `email_accounts_used`, `addons_domains`, ...). Disk and bandwidth in MB.
- `/v1/account_metadata/` `user`: `general` (includes password hash `pass`: do not log), `domais`, `subdomais`, `email`, `database`, `ftp_accounts`. Typos in key names are real.
- `/v1/accountquota/` `user`: `domains`, `subdomins`, `emailaccount`, `mail_autoreply`, `ftp`, each `{pack, account, sw}`. No `status` field.
- `/v1/quotalimit/` `user`: `msj: {used, quota}`.

## packages

`/v1/packages/`

- list: `id`, `package_name`, `disk_quota`, `bandwidth`, `ftp_accounts`, `email_accounts`, `email_lists`, `databases`, `sub_domains`, `parked_domains`, `addons_domains`, `hourly_emails`, `reseller`, `accounts`.
- add: `package_name`, `disk_quota` (MB), `bandwidth` (MB), `ftp_accounts`, `email_accounts`, `email_lists`, `databases`, `sub_domains`, `parked_domains`, `addons_domains`, `hourly_emails`, `reseller` (0/1), `accounts` (reseller packages). Does not return the id.
- udp: `id` plus all fields above. Applies to every account on the package.
- del: `id`. Move accounts off first. Empty body on success.
- A reseller-owned key sees only that reseller's packages.

## user_session (autologin)

`/v1/user_session/`: `action=list`, `user`, optional `timer` (hours, default 15), optional `module` (page to open, e.g. `file_manager`).
Returns `msj.details[0].url` like `https://HOST:2083/USER/?user_session=<token>` and `.token`. Redirect the browser to it. Mint just before the redirect; do not store or email.

## admindomains

`/v1/admindomains/`: `user`, `type` (`domain` or `subdomain`, required; `list` is empty without it), `name`, `path` (relative to home, e.g. `/public_html/example.org`, add only), `autossl` (1, add only).
add returns `{"status":"OK","message":"Data Updated!"}`; del returns `Domain Deleted` / `SubDomain Deleted` and keeps files; list returns `msj[]` as `{domain,path}` or `{subdomain,path}`.

## email

`/v1/email/`

- add: `user`, `email` (local part), `domain`, `pass`, `quotamail` (MB, 0 = unlimited).
- udp: `user`, `mailbox` (full address), optional `password`, optional `quota` (MB).
- susp, unsp, del: `user`, `mailbox`.
- list: `user` -> `result[]` `{email, pass (hash), quota (bytes), consumed, status ("1" = active)}`.
- `/v1/emailadmin/` list -> `{"emailadmin":"..."}`.
- Using `email` instead of `mailbox` on non-add actions returns an error page.

## ftp

`/v1/ftp/`: add `user`, `userftp`, `domainftp`, `passftp`, `pathftp` (relative to home); login becomes `userftp@domainftp`. udp `user`, `userftp` (FULL name), `passftp`. del `user`, `userftp` (full; files kept). list -> `msj[]` `{user, path}`, first entry is the main login.

## MySQL

- `/v1/databasemysql/` add: `user`, `database` (no prefix; created as `user_database`), returns `dbsPack` like "6/0". del: `database` (full name). susp/unsp supported. list -> `{database,user,host}`.
- `/v1/usermysql/` add: `user`, `userdb` (no prefix), `pass`, `dbase` (full db name), `host` (`localhost`, `%` or IP); returns credentials. udp: `userdb`, `host`, `pass`. del: `userdb` (full), `host`. list: `user`.

## SSL and DKIM

- `/v1/autossl/` list takes no `user`, returns `{ssl, autossl, user, exp(days)}` (filter client-side). add, renew, del take `user` and `name` (domain).
- `/v1/dkim/` `add` only: `user`, `domain`.

## cronjobsusers

`/v1/cronjobsusers/`: `user`, `execute` (cron schedule), `command`. URL-encode values. del needs the same `execute` and `command`. list returns crontab lines; with none it returns an Error "There are no scheduled tasks".

## Server utilities

- `testconex`: `{"status":"OK","result":"Conex Api OK"}`.
- `typeserver` list -> `msj: "kvm"|"openvz"`.
- `firewall` list with `modo=status|on|off` controls the CSF/LFD daemon (`initiated`/`arrested`).

## Legacy API (deprecated, do not use for new work)

`https://HOST:2030/api/?key=KEY&api=FUNCTION`; key in `/usr/local/cwp/.conf/api_key.conf`, allowed IPs in `/usr/local/cwp/.conf/api_allowed.conf`. Functions: `account_new`, `account_remove`, `account_suspend`, `account_unsuspend`, `addondomain_add`, `addondomain_remove`, `subdomain_add`, `subdomain_remove`, `unblock_ip`, `testconnection`. Only `unblock_ip` has no v1 replacement.

## Old free-hosting signup endpoint

`http://IP:2030/index.php?scripts=free_hosting&domain=..&username=..&password=..&package=ID&email=..&inode=..&nproc=..&nofile=..&key=KEY`, key in `/usr/local/cwp/.conf/free_hosting_key.conf`, allowed IPs in `free_hosting_allowed.conf`. Sends a secret in the URL over plain HTTP: avoid.
