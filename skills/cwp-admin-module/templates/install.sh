#!/usr/bin/env bash
# CWPMOD_TITLE installer for CWP (Control Web Panel). Dry-run unless --apply.
# Layout expected next to this script: cwp/ (files for resources/admin), engine, fix-menu.sh.
set -Eeuo pipefail

MODULE='cwpmod_example'
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LIB=/usr/local/lib/$MODULE
CRON=/etc/cron.d/$MODULE
AUTOUPDATE=/root/.cwp_autoupdate.sh
APPLY=0

for a in "$@"; do
  case $a in
    --apply) APPLY=1 ;;
    -h | --help) echo "usage: install.sh [--apply]   (dry-run unless --apply)"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 1 ;;
  esac
done
run() { if ((APPLY)); then "$@"; else printf '+ %s\n' "$*"; fi; }

[[ -d /usr/local/cwpsrv/htdocs/resources/admin ]] || { echo "CWP admin resources not found; is this a CWP server?" >&2; exit 1; }
((APPLY == 0 || EUID == 0)) || { echo "run as root" >&2; exit 1; }
for f in cwp/modules/$MODULE.php cwp/modules/$MODULE/lib.php cwp/addons/ajax/ajax_$MODULE.php cwp/include/menu.snippet engine fix-menu.sh; do
  [[ -f $HERE/$f ]] || { echo "missing $HERE/$f" >&2; exit 1; }
done

echo "1. payload and engine"
run install -d -m 0755 -o root -g root -- "$LIB" "$LIB/cwp"
run cp -a -- "$HERE/cwp/." "$LIB/cwp/"
run install -m 0755 -o root -g root -- "$HERE/engine" "$LIB/engine"
run install -m 0755 -o root -g root -- "$HERE/fix-menu.sh" "$LIB/fix-menu"

echo "2. self-heal: daily cron and CWP's after-update hook"
if ((APPLY)); then
  printf '%s\n' "17 3 * * * root $LIB/fix-menu --apply --quiet" >"$CRON"
  chmod 0644 "$CRON"
  [[ -f $AUTOUPDATE ]] || printf '#!/bin/bash\n' >"$AUTOUPDATE"
  if ! grep -qF -- "$LIB/fix-menu" "$AUTOUPDATE"; then printf '%s\n' "$LIB/fix-menu --apply --quiet || true  # $MODULE" >>"$AUTOUPDATE"; fi
  chmod 0700 "$AUTOUPDATE"
else
  echo "+ write $CRON"
  echo "+ append fix-menu line to $AUTOUPDATE (if absent)"
fi

echo "3. module files and menu line (handles chattr +i)"
if ((APPLY)); then "$LIB/fix-menu" --apply; else COPY="$HERE/cwp" "$HERE/fix-menu.sh"; fi

((APPLY)) || echo "(dry-run: nothing changed; re-run with --apply)"
echo "Open the admin panel, press Ctrl+F5, and look for the menu entry (index.php?module=$MODULE)."
