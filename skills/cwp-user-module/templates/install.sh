#!/usr/bin/env bash
# CWPMOD_TITLE installer for the CWP user panel. Dry-run unless --apply.
# Layout expected next to this script: cwp/ (module.php renamed, ini, html, menuconf.snippet), process-jobs.php, fix-module.sh.
# Env: THEMES="original" (user themes that get the Twig template; clones too), PANEL_UID=0 (see references/root-job-queue.md).
set -Eeuo pipefail

MODULE='cwpmod_example'
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LIB=/usr/local/lib/$MODULE
SPOOL=/var/spool/$MODULE
CRON=/etc/cron.d/$MODULE
AUTOUPDATE=/root/.cwp_autoupdate.sh
PANEL_UID=${PANEL_UID:-0}
PHP_BIN=/usr/local/cwp/php71/bin/php
APPLY=0

for a in "$@"; do
  case $a in
    --apply) APPLY=1 ;;
    -h | --help) echo "usage: install.sh [--apply]   (dry-run unless --apply)"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 1 ;;
  esac
done
run() { if ((APPLY)); then "$@"; else printf '+ %s\n' "$*"; fi; }
[[ $PANEL_UID =~ ^[0-9]+$ ]] || { echo "PANEL_UID must be a number" >&2; exit 1; }
[[ -d /usr/local/cwpsrv/var/services/user_files/modules ]] || { echo "CWP user panel tree not found; is this a CWP server?" >&2; exit 1; }
((APPLY == 0 || EUID == 0)) || { echo "run as root" >&2; exit 1; }
for f in "cwp/$MODULE.php" "cwp/$MODULE.ini" "cwp/mod_$MODULE.html" cwp/menuconf.snippet process-jobs.php fix-module.sh; do
  [[ -f $HERE/$f ]] || { echo "missing $HERE/$f" >&2; exit 1; }
done
[[ -x $PHP_BIN ]] || PHP_BIN=$(command -v php || true)
[[ -n $PHP_BIN ]] || { echo "no php binary found" >&2; exit 1; }

echo "1. payload, processor, fix-module"
run install -d -m 0755 -o root -g root -- "$LIB" "$LIB/cwp"
run cp -a -- "$HERE/cwp/." "$LIB/cwp/"
run install -m 0700 -o root -g root -- "$HERE/process-jobs.php" "$LIB/process-jobs.php"
run install -m 0755 -o root -g root -- "$HERE/fix-module.sh" "$LIB/fix-module"

echo "2. spool (owned by the panel uid $PANEL_UID, mode 0700: customers cannot write to it)"
run install -d -m 0700 -o "$PANEL_UID" -g "$PANEL_UID" -- "$SPOOL"
for d in incoming processing results 'done'; do
  run install -d -m 0700 -o "$PANEL_UID" -g "$PANEL_UID" -- "$SPOOL/$d"
done
if ((PANEL_UID != 0)); then echo "NOTE: also set CWPMOD_EXAMPLE_PANEL_UID to $PANEL_UID in $LIB/process-jobs.php"; fi

echo "3. cron: job processor every minute, self-heal daily; CWP after-update hook"
if ((APPLY)); then
  printf '%s\n' \
    "* * * * * root $PHP_BIN -q $LIB/process-jobs.php" \
    "23 3 * * * root THEMES=\"${THEMES:-original}\" $LIB/fix-module --apply --quiet" >"$CRON"
  chmod 0644 "$CRON"
  [[ -f $AUTOUPDATE ]] || printf '#!/bin/bash\n' >"$AUTOUPDATE"
  if ! grep -qF -- "$LIB/fix-module" "$AUTOUPDATE"; then printf '%s\n' "THEMES=\"${THEMES:-original}\" $LIB/fix-module --apply --quiet || true  # $MODULE" >>"$AUTOUPDATE"; fi
  chmod 0700 "$AUTOUPDATE"
else
  echo "+ write $CRON"
  echo "+ append fix-module line to $AUTOUPDATE (if absent)"
fi

echo "4. module files and menuConf.php block (handles chattr +i, backs up and lints menuConf.php)"
if ((APPLY)); then "$LIB/fix-module" --apply; else COPY="$HERE/cwp" "$HERE/fix-module.sh"; fi

((APPLY)) || echo "(dry-run: nothing changed; re-run with --apply)"
echo "Next: Admin > User Accounts > Features, Themes and Languages: enable the module for a package, then log in as a test user."
