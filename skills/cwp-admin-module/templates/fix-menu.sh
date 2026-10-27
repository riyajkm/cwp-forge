#!/usr/bin/env bash
# CWPMOD_TITLE fix-menu: put the module files and the menu line into CWP, and keep CWP's immutable flags as found.
# Used by install.sh, the daily self-heal cron, /root/.cwp_autoupdate.sh (CWP runs it after every update) and uninstall.sh.
# Dry-run unless --apply.   usage: fix-menu [--apply] [--remove] [--quiet]
set -Eeuo pipefail

MODULE='cwpmod_example'
COPY=${COPY:-/usr/local/lib/$MODULE/cwp}                         # pristine payload kept by install.sh
RES=${CWP_RES:-/usr/local/cwpsrv/htdocs/resources/admin}
MENU=$RES/include/3rdparty.php
MARK="index.php?module=$MODULE\""                                  # closing quote: module "foo" must not match "foo_bar"
APPLY=0 REMOVE=0 QUIET=0
LOCKED=()

say() { ((QUIET)) || printf '%s\n' "$*"; }
die() { printf 'fix-menu: %s\n' "$*" >&2; exit 1; }

for a in "$@"; do
  case $a in
    --apply) APPLY=1 ;;
    --remove) REMOVE=1 ;;
    --quiet) QUIET=1 ;;
    -h | --help) echo "usage: fix-menu [--apply] [--remove] [--quiet]   (dry-run unless --apply)"; exit 0 ;;
    *) die "unknown option: $a" ;;
  esac
done
[[ -d $RES ]] || die "CWP admin resources not found: $RES"
((APPLY == 0 || EUID == 0)) || die "run as root"
run() { if ((APPLY)); then "$@"; else say "+ $*"; fi; }

# --- immutability: unlock only the paths we write into, restore exactly those afterwards ---
is_immutable() { local f; f=$(lsattr -d -- "$1" 2>/dev/null | cut -d' ' -f1) || return 1; [[ $f == *i* ]]; }
unlock() {
  local p
  for p in "$@"; do
    [[ -e $p ]] || continue
    if is_immutable "$p"; then
      LOCKED+=("$p")
      if ((APPLY)); then chattr -i -- "$p"; else say "+ chattr -i $p"; fi
    fi
  done
}
relock() {
  local p
  for p in ${LOCKED[@]+"${LOCKED[@]}"}; do
    if ((APPLY)); then chattr +i -- "$p" || echo "fix-menu: could not restore the immutable flag on $p" >&2; fi
  done
  LOCKED=()
}
trap relock EXIT
trap 'exit 130' INT TERM
# Tree-wide variant, if you must (chattr -R fails on CWP's symlinks, so skip them):
#   find "$DIR" -xdev ! -type l -exec chattr -i -- {} +      (and +i to restore)

[[ -d $COPY || $REMOVE == 1 ]] || die "payload missing: $COPY (run install.sh)"
files=()
if [[ -d $COPY ]]; then
  while IFS= read -r -d '' f; do files+=("${f#"$COPY"/}"); done < <(find "$COPY" -type f ! -path "$COPY/include/*" -print0)
fi

unlock "$RES/modules" "$RES/modules/$MODULE" "$RES/modules/language/en" "$RES/addons/ajax" "$RES/include" "$MENU"
for rel in ${files[@]+"${files[@]}"}; do unlock "$RES/$rel"; done

changed=0
if ((REMOVE == 0)); then
  [[ -f $COPY/include/menu.snippet ]] || die "menu snippet missing in $COPY"
  for rel in ${files[@]+"${files[@]}"}; do
    if ! cmp -s -- "$COPY/$rel" "$RES/$rel" 2>/dev/null; then
      run install -D -m 0644 -o root -g root -- "$COPY/$rel" "$RES/$rel"; changed=1
    fi
  done
  if ! grep -qF -- "$MARK" "$MENU" 2>/dev/null; then
    run install -d -m 0755 -o root -g root -- "${MENU%/*}"
    if ((APPLY)); then
      [[ -f $MENU ]] || install -m 0644 -o root -g root /dev/null "$MENU"
      [[ ! -s $MENU || -z $(tail -c1 "$MENU") ]] || echo >>"$MENU"
      cat -- "$COPY/include/menu.snippet" >>"$MENU"
    else
      say "+ append menu line to $MENU"
    fi
    changed=1
  fi
  if ((changed)); then say "$MODULE: module (re)applied"; else say "$MODULE: already in place"; fi
else
  for rel in ${files[@]+"${files[@]}"}; do run rm -f -- "$RES/$rel"; done
  run rmdir --ignore-fail-on-non-empty -- "$RES/modules/$MODULE"
  if grep -qF -- "$MARK" "$MENU" 2>/dev/null; then
    if ((APPLY)); then
      tmp=$(grep -vF -- "$MARK" "$MENU" || true)
      if [[ -n $tmp ]]; then printf '%s\n' "$tmp" >"$MENU"; else : >"$MENU"; fi   # write in place: keeps owner and mode
    else
      say "+ remove menu line from $MENU"
    fi
  fi
  say "$MODULE: module removed"
fi
((APPLY)) || say "(dry-run: nothing changed; add --apply)"
