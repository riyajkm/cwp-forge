#!/usr/bin/env bash
# CWPMOD_TITLE uninstaller for the CWP user panel. Dry-run unless --apply. Keeps the spool and log unless --purge.
set -Eeuo pipefail

MODULE='cwpmod_example'
LIB=/usr/local/lib/$MODULE
CRON=/etc/cron.d/$MODULE
AUTOUPDATE=/root/.cwp_autoupdate.sh
APPLY=0 PURGE=0

for a in "$@"; do
  case $a in
    --apply) APPLY=1 ;;
    --purge) PURGE=1 ;;
    -h | --help) echo "usage: uninstall.sh [--apply] [--purge]   (dry-run unless --apply)"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 1 ;;
  esac
done
run() { if ((APPLY)); then "$@"; else printf '+ %s\n' "$*"; fi; }
((APPLY == 0 || EUID == 0)) || { echo "run as root" >&2; exit 1; }

run rm -f -- "$CRON"   # stop the processor first
if [[ -x $LIB/fix-module ]]; then
  if ((APPLY)); then THEMES="${THEMES:-original}" "$LIB/fix-module" --remove --apply; else THEMES="${THEMES:-original}" "$LIB/fix-module" --remove; fi
else
  echo "fix-module not found at $LIB/fix-module; module files and menuConf.php block were not removed" >&2
fi
if [[ -f $AUTOUPDATE ]] && grep -qF -- "$LIB/fix-module" "$AUTOUPDATE"; then
  if ((APPLY)); then
    tmp=$(grep -vF -- "$LIB/fix-module" "$AUTOUPDATE" || true)
    printf '%s\n' "$tmp" >"$AUTOUPDATE"
  else
    echo "+ remove fix-module line from $AUTOUPDATE"
  fi
fi
run rm -rf -- "$LIB"
if ((PURGE)); then run rm -rf -- "/var/spool/$MODULE" "/var/log/$MODULE-jobs.log"; else echo "kept /var/spool/$MODULE and the job log (use --purge to delete)"; fi
((APPLY)) || echo "(dry-run: nothing changed; re-run with --apply)"
