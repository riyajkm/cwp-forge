#!/usr/bin/env bash
# CWPMOD_TITLE fix-module: put the user-panel module files into CWP and add/remove its block in menuConf.php.
# Safe to re-run: used by install.sh, the daily self-heal cron, /root/.cwp_autoupdate.sh (after CWP updates) and uninstall.sh.
# Dry-run unless --apply.   usage: fix-module [--apply] [--remove] [--quiet]
# Env: THEMES="original mytheme" (themes that get mod_<name>.html), PHP_BIN, CWP_SVC, CWP_MENUCONF, COPY.
set -Eeuo pipefail

MODULE='cwpmod_example'
COPY=${COPY:-/usr/local/lib/$MODULE/cwp}
SVC=${CWP_SVC:-/usr/local/cwpsrv/var/services}
MENUCONF=${CWP_MENUCONF:-/usr/local/cwpsrv/htdocs/resources/conf/user_panel/menuConf.php}
THEMES=${THEMES:-original}
PHP_BIN=${PHP_BIN:-/usr/local/cwp/php71/bin/php}
BACKUP=${BACKUP:-/usr/local/lib/$MODULE/backup}
BEGIN="// >>> $MODULE (managed"
END="// <<< $MODULE"
APPLY=0 REMOVE=0 QUIET=0
LOCKED=()

say() { ((QUIET)) || printf '%s\n' "$*"; }
die() { printf 'fix-module: %s\n' "$*" >&2; exit 1; }
for a in "$@"; do
  case $a in
    --apply) APPLY=1 ;;
    --remove) REMOVE=1 ;;
    --quiet) QUIET=1 ;;
    -h | --help) echo "usage: fix-module [--apply] [--remove] [--quiet]   (dry-run unless --apply)"; exit 0 ;;
    *) die "unknown option: $a" ;;
  esac
done
[[ -d $SVC/user_files/modules ]] || die "user panel tree not found: $SVC/user_files/modules"
[[ -f $MENUCONF ]] || die "menuConf.php not found: $MENUCONF (verify the path for this CWP version)"
((APPLY == 0 || EUID == 0)) || die "run as root"
run() { if ((APPLY)); then "$@"; else say "+ $*"; fi; }

# Destinations: source name in $COPY -> path under $SVC
declare -A DEST=(
  ["$MODULE.php"]="$SVC/user_files/modules/$MODULE.php"
  ["$MODULE.ini"]="$SVC/users/cwp_lang/en/$MODULE.ini"
)
THEMEFILES=()
for t in $THEMES; do [[ $t =~ ^[A-Za-z0-9_-]+$ ]] || die "bad theme name: $t"; THEMEFILES+=("$SVC/users/cwp_theme/$t/mod_$MODULE.html"); done

# --- immutability: unlock only paths we write into, restore exactly those afterwards ---
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
    if ((APPLY)); then chattr +i -- "$p" || echo "fix-module: could not restore the immutable flag on $p" >&2; fi
  done
  LOCKED=()
}
trap relock EXIT
trap 'exit 130' INT TERM

targets=("${DEST[@]}" ${THEMEFILES[@]+"${THEMEFILES[@]}"})
dirs=()
for f in "${targets[@]}" "$MENUCONF"; do dirs+=("${f%/*}"); done
unlock "${dirs[@]}" "${targets[@]}" "$MENUCONF"

has_block() { grep -qF -- "$BEGIN" "$MENUCONF"; }

if ((REMOVE)); then
  for f in "${targets[@]}"; do run rm -f -- "$f"; done
  if has_block; then
    if ((APPLY)); then
      install -d -m 0700 -- "$BACKUP"; cp -p -- "$MENUCONF" "$BACKUP/menuConf.php.$(date +%Y%m%d%H%M%S)"
      sed -i "\|$BEGIN|,\|$END|d" "$MENUCONF"        # in place: keeps owner and mode
    else
      say "+ remove $MODULE block from $MENUCONF"
    fi
  fi
  say "$MODULE: removed"
  ((APPLY)) || say "(dry-run: nothing changed; add --apply)"
  exit 0
fi

[[ -d $COPY ]] || die "payload missing: $COPY (run install.sh)"
changed=0
copy_if_changed() { # src dst
  if ! cmp -s -- "$1" "$2" 2>/dev/null; then run install -D -m 0644 -o root -g root -- "$1" "$2"; changed=1; fi
}
copy_if_changed "$COPY/$MODULE.php" "${DEST["$MODULE.php"]}"
copy_if_changed "$COPY/$MODULE.ini" "${DEST["$MODULE.ini"]}"
for f in ${THEMEFILES[@]+"${THEMEFILES[@]}"}; do copy_if_changed "$COPY/mod_$MODULE.html" "$f"; done

if ! has_block; then
  changed=1
  if ((APPLY)); then
    [[ -x $PHP_BIN ]] || PHP_BIN=$(command -v php || true)
    [[ -n $PHP_BIN ]] || die "no php binary to lint menuConf.php"
    # shellcheck disable=SC2016
    grep -qF -- '$menu' "$MENUCONF" || die "menuConf.php has no \$menu array; refusing to patch (verify this CWP version)"
    install -d -m 0700 -- "$BACKUP"
    cp -p -- "$MENUCONF" "$BACKUP/menuConf.php.$(date +%Y%m%d%H%M%S)"
    mapfile -t L <"$MENUCONF"
    n=${#L[@]}
    while ((n > 0)) && [[ -z ${L[n - 1]//[[:space:]]/} ]]; do n=$((n - 1)); done
    tmp=$(mktemp)
    if ((n > 0)) && [[ ${L[n - 1]} =~ ^[[:space:]]*\?\>[[:space:]]*$ ]]; then   # keep the file's closing tag last
      { printf '%s\n' "${L[@]:0:n-1}"; cat -- "$COPY/menuconf.snippet"; printf '%s\n' "${L[n - 1]}"; } >"$tmp"
    else
      { printf '%s\n' "${L[@]:0:n}"; cat -- "$COPY/menuconf.snippet"; } >"$tmp"
    fi
    if "$PHP_BIN" -l "$tmp" >/dev/null; then cat -- "$tmp" >"$MENUCONF"; rm -f -- "$tmp"; else rm -f -- "$tmp"; die "patched menuConf.php failed php -l; left untouched"; fi
  else
    say "+ add $MODULE block to $MENUCONF (backup, php -l, then write)"
  fi
fi
if ((changed)); then say "$MODULE: (re)applied"; else say "$MODULE: already in place"; fi
((APPLY)) || say "(dry-run: nothing changed; add --apply)"
