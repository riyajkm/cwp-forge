# Surviving CWP updates

## What gets overwritten

| Thing | Status |
|---|---|
| User theme `original` (`/usr/local/cwpsrv/var/services/users/cwp_theme/original/`) | overwritten [V docs: clone and rename] |
| `/usr/local/cwpsrv/htdocs/resources/conf/user_panel/menuConf.php` | overwritten [U, inferred] |
| Default vhost and DNS templates (`default.tpl`) | overwritten [V wiki]; use new names |
| `include/menu.php` (core menu) | overwritten [F] |
| `include/3rdparty.php` (your admin menu lines) | may be lost [U]; verify on your version |
| Admin modules in `resources/admin/modules/`, AJAX in `addons/ajax/` | usually kept but not guaranteed [U] |
| Hook files in `resources/admin/hooks/` | may be wiped [U] |
| `/usr/local/cwp/.conf/*` | config area, kept |

Rule: assume everything under `/usr/local/cwpsrv/` that you added can disappear. Keep a copy elsewhere.

## The run-after-update hook

`/root/.cwp_autoupdate.sh`: if it exists (bash), CWP runs it after each update. [V] https://wiki.centos-webpanel.com/run-after-update-script. Documented uses: re-apply branding, re-copy module files.

Do not overwrite an existing file. Append a guarded, idempotent line:

```bash
grep -qF 'cwp-selfheal.sh' /root/.cwp_autoupdate.sh 2>/dev/null || {
  [ -e /root/.cwp_autoupdate.sh ] || printf '#!/bin/bash\n' > /root/.cwp_autoupdate.sh
  printf '%s\n' '/usr/local/sbin/cwp-selfheal.sh --apply >> /var/log/cwp-forge/selfheal-update.log 2>&1 || true' >> /root/.cwp_autoupdate.sh
  chmod 700 /root/.cwp_autoupdate.sh
}
```

The update may run it while files are still settling; the daily cron is the safety net.

## Self-heal pattern

1. **Kept copy**: `/opt/<name>/keep/` mirrors `/` (e.g. `keep/usr/local/cwpsrv/htdocs/resources/admin/modules/<name>.php`). Menu lines live in `/opt/<name>/menu-lines.txt`, one `<li>` per line.
2. **Compare, then copy**: `cmp -s` source and target; copy only if different or missing; preserve mode with `install -m` from the kept file's mode.
3. **Menu**: append each line to `include/3rdparty.php` only if `grep -qF` finds nothing. Create the file if it does not exist.
4. **chattr**: `/usr/local/cwpsrv/htdocs/admin` is `chattr +i` recursively; `resources/admin` was not immutable on a verified server [V field]. Before writing, check `lsattr -d` on the target and its nearest existing parent; lift `i` only on those paths, write, restore. For bulk operations use `find DIR -xdev ! -type l -exec chattr -i {} +` because `chattr -R` fails on symlinks (`admin/login/design -> ../design`). Touch only dirs you write into.
5. **Lock**: `flock -n` so cron and autoupdate runs never overlap.
6. **Report**: log each repair; on failure call `/scripts/add_alert alert-danger "..." LOGFILE`.
7. **Dry-run default**; cron and the autoupdate line pass `--apply`.
8. **No restart by default**: PHP modules are read per request [U]. If you change `cwpsrv` config use `/scripts/restart_cwpsrv` or `reload_cwpsrv`.

Provided as `templates/cwp-selfheal.sh` (+ cron or systemd timer).

## Avoid fragile designs

- Do not patch core files (`admin/login/login.php`, `menu.php`): every update reverts them. If you must, the self-heal must re-patch idempotently and verify with a marker.
- Do not replace `menuConf.php` wholesale: that silently drops other customisations. Patch your entry in with a marker check.
- Do not rely on inode or mtime to detect an update; compare content.
- Do not upgrade the panel's own PHP (`/usr/local/cwp/php71`): it is tied to the encoded core.
- Record the CWP version at heal time (`/scripts/cwp_version`) in the log: it explains regressions.

## Testing

Edit one kept target file (change a byte), run `cwp-selfheal.sh` without flags (shows the repair), then with `--apply`, then again (no changes). Simulate the `chattr +i` case on a test dir and confirm the flag is restored.
