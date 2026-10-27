#!/usr/bin/env bash
# CWPMOD_TITLE uninstaller. Dry-run unless --apply. Keeps /var/lib data unless --purge.
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

# Remove module files and the menu line first (uses the installed fix-menu so chattr is handled the same way).
if [[ -x $LIB/fix-menu ]]; then
  if ((APPLY)); then "$LIB/fix-menu" --remove --apply; else "$LIB/fix-menu" --remove; fi
else
  echo "fix-menu not found at $LIB/fix-menu; module files were not removed" >&2
fi

run rm -f -- "$CRON"
if [[ -f $AUTOUPDATE ]] && grep -qF -- "$LIB/fix-menu" "$AUTOUPDATE"; then
  if ((APPLY)); then
    tmp=$(grep -vF -- "$LIB/fix-menu" "$AUTOUPDATE" || true)
    printf '%s\n' "$tmp" >"$AUTOUPDATE"
  else
    echo "+ remove fix-menu line from $AUTOUPDATE"
  fi
fi
run rm -rf -- "$LIB"
if ((PURGE)); then run rm -rf -- "/var/lib/$MODULE"; else echo "kept /var/lib/$MODULE (use --purge to delete)"; fi
((APPLY)) || echo "(dry-run: nothing changed; re-run with --apply)"
