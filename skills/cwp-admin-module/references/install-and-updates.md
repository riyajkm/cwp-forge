# Installing, immutability, and surviving CWP updates

## Paths
| What | Where |
|---|---|
| Page | `/usr/local/cwpsrv/htdocs/resources/admin/modules/<name>.php` |
| Sub-files | `.../modules/<name>/lib.php` |
| Language | `.../modules/language/en/<name>.ini` |
| AJAX | `.../addons/ajax/ajax_<name>.php` |
| Menu | `.../include/3rdparty.php` (create if missing, append one `<li>`) |
| Engine, payload copy, fix-menu | `/usr/local/lib/<name>/` (root, 0755) |
| State | `/var/lib/<name>/` (root, 0700) |
| Cron | `/etc/cron.d/<name>` |

Official docs say to run `chattr -i -R /usr/local/cwpsrv/htdocs/admin` before creating files. On a live server `htdocs/admin` was `chattr +i` recursively while `resources/admin` was not. Check, do not assume: `lsattr -d <dir>`.

## Immutability, done safely
- `chattr -R` fails on symlinks (for example `admin/login/design -> ../design`). For a tree use `find DIR -xdev ! -type l -exec chattr -i -- {} +` and restore with `+i` the same way.
- Prefer touching only what you write into: the target directories and any existing target files. `fix-menu` records which of those were immutable, unlocks them, writes, and re-locks exactly those in an `EXIT` trap (so errors and Ctrl-C also restore the flag).
- Never leave a path unlocked that was locked before, and never lock something that was not.
- `lsattr` fails on non-ext filesystems; treat that as "not immutable".

## Installer flow (templates `install.sh`, `fix-menu.sh`, `uninstall.sh`)
1. Dry-run by default: print every command with `+ `; `--apply` executes. Require root only for `--apply`.
2. Preflight: CWP admin tree exists, payload files exist.
3. Copy payload to `/usr/local/lib/<name>/cwp`, engine and `fix-menu` to `/usr/local/lib/<name>/`.
4. Write `/etc/cron.d/<name>` (daily `fix-menu --apply --quiet`) and append a line to `/root/.cwp_autoupdate.sh` (CWP runs it after every update; create with `#!/bin/bash` if absent; idempotent).
5. Run `fix-menu --apply`: copy changed files (`cmp -s` first), append the menu line if the marker `index.php?module=<name>"` is absent (add a newline first if the file does not end with one).
6. Uninstall reverses all of it; keeps `/var/lib/<name>` unless `--purge`; removes only its own menu line.

## What CWP updates overwrite
Core files, the `original` user theme, `menuConf.php`, vhost/DNS templates. Your module directories are usually left alone, but a menu file or an immutable-tree reset can drop your line. The self-heal (cron plus autoupdate hook) makes this a non-event. Verify on the target version: update CWP in a test VM or run `/root/.cwp_autoupdate.sh` by hand and confirm the entry returns.

## Menu caveats
- Some old CWP versions ignored `3rdparty.php` (the answer was "use the direct link"). Test the target version; the direct URL `index.php?module=<name>` always works.
- A top-level menu group is possible but needs HTML tricks (close the dev menu, open a hidden `<li>`); only do it if requested, and mark it version-specific.

## Packaging
Ship a tarball of the rendered output dir (`install.sh`, `uninstall.sh`, `fix-menu.sh`, `engine`, `cwp/`). Files committed from Windows lose the executable bit; run `git update-index --chmod=+x` on the scripts. Keep `shellcheck -S style` clean. In bash scripts that split lines with `IFS=$'\n\t'`, use `IFS=' ' read` for space separated fields.
