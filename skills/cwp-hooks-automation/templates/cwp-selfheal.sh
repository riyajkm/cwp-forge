#!/usr/bin/env bash
# cwp-selfheal.sh - re-apply custom module files, hook files and admin menu lines after CWP updates.
# Install: /usr/local/sbin/cwp-selfheal.sh (0750 root:root). Dry-run by default; use --apply.
#
# Kept copy layout (edit KEEP below):
#   $KEEP/files/<absolute path inside CWP>   e.g. files/usr/local/cwpsrv/htdocs/resources/admin/modules/mymod.php
#   $KEEP/menu-lines.txt                     one <li>...</li> per line for include/3rdparty.php
#
# Usage: cwp-selfheal.sh [--apply] [--quiet]
set -euo pipefail
umask 022
export PATH=/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

NAME=mycwpmod                                   # change me (also used for dirs)
KEEP="/opt/$NAME/keep"
MENU_FILE=/usr/local/cwpsrv/htdocs/resources/admin/include/3rdparty.php
LOGDIR="/var/log/$NAME"
LOCK="/var/lock/$NAME-selfheal.lock"

apply=0 quiet=0
for a in "$@"; do
  case "$a" in
    --apply) apply=1 ;;
    --quiet) quiet=1 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 64 ;;
  esac
done

changes=0
say() { [ "$quiet" = 1 ] || printf '%s\n' "$*"; }
log() {
  say "$*"
  if [ "$apply" = 1 ]; then
    mkdir -p "$LOGDIR"
    printf '%s %s\n' "$(date -Is)" "$*" >> "$LOGDIR/selfheal.log"
  fi
}

[ -d "$KEEP/files" ] || { echo "no kept copy at $KEEP/files" >&2; exit 66; }

exec 9>"$LOCK"
flock -n 9 || { say "another run holds the lock; exiting"; exit 0; }

is_immutable() { lsattr -d -- "$1" 2>/dev/null | awk '{print $1}' | grep -q 'i'; }

# Run "$@" with immutable flag lifted on the given paths, then restore it.
declare -a relock=()
unlock_path() {
  if [ -e "$1" ] && is_immutable "$1"; then
    chattr -i -- "$1"
    relock+=("$1")
  fi
}
restore_locks() {
  local p
  for p in "${relock[@]+"${relock[@]}"}"; do chattr +i -- "$p" 2>/dev/null || true; done
  relock=()
}
trap restore_locks EXIT

nearest_existing() { local d="$1"; while [ ! -e "$d" ]; do d="$(dirname "$d")"; done; printf '%s' "$d"; }

heal_file() {
  local src="$1" dst="$2" anc mode
  if [ -f "$dst" ] && cmp -s -- "$src" "$dst"; then return 0; fi
  changes=$((changes + 1))
  if [ "$apply" = 0 ]; then say "WOULD copy $src -> $dst"; return 0; fi
  anc="$(nearest_existing "$(dirname "$dst")")"
  unlock_path "$anc"
  unlock_path "$dst"
  mode="$(stat -c %a -- "$src")"
  install -D -m "$mode" -- "$src" "$dst"
  restore_locks
  log "restored $dst"
}

# 1. Files
while IFS= read -r -d '' src; do
  rel="${src#"$KEEP/files"}"
  heal_file "$src" "$rel"
done < <(find "$KEEP/files" -type f -print0)

# 2. Menu lines (idempotent append)
if [ -f "$KEEP/menu-lines.txt" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    if [ -f "$MENU_FILE" ] && grep -qF -- "$line" "$MENU_FILE"; then continue; fi
    changes=$((changes + 1))
    if [ "$apply" = 0 ]; then say "WOULD append menu line to $MENU_FILE: $line"; continue; fi
    anc="$(nearest_existing "$(dirname "$MENU_FILE")")"
    unlock_path "$anc"
    unlock_path "$MENU_FILE"
    printf '%s\n' "$line" >> "$MENU_FILE"
    restore_locks
    log "added menu line"
  done < "$KEEP/menu-lines.txt"
fi

if [ "$changes" -eq 0 ]; then
  say "nothing to do"
elif [ "$apply" = 0 ]; then
  say "$changes change(s) pending; re-run with --apply"
else
  v="$(/scripts/cwp_version 2>/dev/null | head -n 1 || true)"
  log "healed $changes item(s); cwp version: ${v:-unknown}"
fi
