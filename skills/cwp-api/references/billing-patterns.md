# Billing integration patterns (WHMCS, Blesta, custom)

## Event to call map (official)

| Billing event | Call |
|---|---|
| Order activated | `account add` (+ `autossl=1` if the domain already points at the server) |
| Invoice overdue | `account susp` |
| Invoice paid | `account unsp` |
| Upgrade / downgrade | `changepack udp` (package **id**) or `account udp` (package name) |
| Password reset | `changepass udp` |
| "Login to panel" button | `user_session list`, then redirect to `msj.details[0].url` |
| Service terminated | `account del` |
| Usage sync | `account list` or `accountdetail list` |

## Rules that make it robust

1. One API key per integration, bound to one IP, with the minimum function x action grants. For a billing flow tick: account (add, udp, del, list, susp, unsp), changepack/udp, changepass/udp, user_session/list, packages/list, accountdetail/list.
2. Resolve package name to id via `packages list` (cache a few minutes) before `changepack`.
3. Idempotency: CWP has no idempotency key. After a timeout or 5xx, `account list`, look for the username, and only then decide to retry `add`. Same for `del` (already gone is success).
4. Store the CWP username and the package id in your billing record. Generate usernames yourself (lower-case alphanumerics, unique) rather than trusting user input.
5. Mint the autologin URL on click, never on page render and never stored.
6. `susp`/`unsp` are idempotent in effect; check `account list` status if you need certainty.
7. Mask the key in logs and error text; never log `account_metadata` or `email list` output (hashes).
8. Verify TLS (`CWP_VERIFY_TLS=1`). Pin or install the CA if the server cert is self-signed.
9. Silent-success trap: wrong field names (`nofile`/`nproc` on `account add`, or `limit_*` on `udp`) are accepted and ignored. Read the account back to verify limits.
10. Timeouts: about 120 s for `account add`/`del` (they do real work), 10 s connect timeout.

## Reference flow (pseudo)

```
create:    pkg = packages.list -> find by name -> id
           account.list -> if username exists: stop (already created)
           account.add (domain,user,pass,email,server_ips,package,autossl?)
           on timeout: account.list -> exists? success : retry once
suspend:   account.susp user
unsuspend: account.unsp user
upgrade:   changepack.udp user, package=<id>
terminate: account.del user   (take a backup first if policy requires)
sync:      account.list -> map username -> diskused/disklimit/bandwidth/bwlimit/status
```

## Existing modules

| System | Facts |
|---|---|
| WHMCS (official `cwp7`) | Download `http://dl1.centos-webpanel.com/files/3rdparty/whmcs/cwp7.zip` (last update 30 Mar 2020; plain HTTP, inspect the zip). Extract to `WHMCS/modules/servers/cwp7/cwp7.php`. Server type "Cwp7", username root, "Access Hash" = API key. Create the CWP key with preset "WHMCS". Allow each side's IP in CSF. If WHMCS runs on the same host as CWP, php-fpm restarts during account creation can return 503: run WHMCS under php-cgi. |
| WHMCS rewrite (community, MIT) [F] | https://github.com/bradleygb/whmcs-cwp-module for PHP 8 / WHMCS 8.5-9.0. Lists bugs of the 2020 module: disk/bandwidth sync never matched, package change posted to `account` instead of `changepack`, wrong limit field names, an `acction` typo, key logged in clear, TLS verify off, autologin URL minted on every page view. Review before use. |
| Blesta | Module v2.0 uses the new API: create, cancel, suspend, unsuspend. Server fields: label, hostname (FQDN), API key, SSL toggle, account limit, name servers. Firewall (unblock IP) management was removed in Blesta 4.8 (legacy API only). https://docs.blesta.com/display/user/CentOS+Web+Panel |
| HostBill | API key at CWP Settings > API Manager. |
| WISECP, ClientExec, HopeBilling | Listed on the CWP wiki / forum; details not verified. |

The official Softaculous and WHMCS pages under "Scripts Installers" in the developer docs are empty; do not rely on them.

## Reseller keys

Set **Owner** to a reseller: the key manages only that reseller's customers and packages. Use it when an external system serves a single reseller, so a leaked key cannot touch root-owned accounts.
