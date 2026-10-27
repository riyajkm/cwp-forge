#!/usr/bin/env bash
# Render the cwp-user-module templates into a local output directory.
# usage: new-user-module.sh <name> [--title "Title"] [--out DIR] [--force] [--install [--apply]]
# Rendering only writes under --out (default ./<name>-module). Nothing under /usr/local/cwpsrv is touched
# unless you pass --install --apply, which runs the generated install.sh (dry-run without --apply).
set -Eeuo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TPL=$HERE/../templates
NAME='' TITLE='' OUT='' FORCE=0 INSTALL=0 APPLY=0

die() { printf 'new-user-module: %s\n' "$*" >&2; exit 1; }
usage() { sed -n '2,5p' "${BASH_SOURCE[0]}" | cut -c3-; }

while (($#)); do
  case $1 in
    --title) (($# >= 2)) || die "--title needs a value"; TITLE=$2; shift 2 ;;
    --out) (($# >= 2)) || die "--out needs a value"; OUT=$2; shift 2 ;;
    --force) FORCE=1; shift ;;
    --install) INSTALL=1; shift ;;
    --apply) APPLY=1; shift ;;
    -h | --help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) [[ -z $NAME ]] || die "only one module name"; NAME=$1; shift ;;
  esac
done
[[ -n $NAME ]] || { usage; exit 1; }
[[ $NAME =~ ^[a-z][a-z0-9_]{1,40}$ ]] || die "name must match ^[a-z][a-z0-9_]{1,40}$ (it becomes PHP identifiers, file names and a Twig file name)"
[[ $NAME != cwpmod_example ]] || die "cwpmod_example is the template placeholder"
if [[ -z $TITLE ]]; then TITLE=${NAME//_/ }; TITLE=${TITLE^}; fi
[[ $TITLE =~ ^[A-Za-z0-9\ ._-]{1,60}$ ]] || die "title: letters, digits, space . _ - only (max 60)"
OUT=${OUT:-./$NAME-module}
((APPLY == 0 || INSTALL == 1)) || die "--apply only makes sense with --install"
if [[ -e $OUT ]] && ((FORCE == 0)); then die "$OUT exists (use --force)"; fi
case $(cd -- "$(dirname -- "$OUT")" 2>/dev/null && pwd)/ in
  /usr/local/cwpsrv/*) die "refusing to render into the CWP tree; install with --install --apply" ;;
esac

UPPER=${NAME^^}
render() { # render <template> <dest>
  install -d -- "$(dirname -- "$2")"
  sed -e "s/cwpmod_example/$NAME/g" -e "s/CWPMOD_EXAMPLE/$UPPER/g" -e "s/CWPMOD_TITLE/$TITLE/g" -- "$TPL/$1" >"$2"
}

render module.php "$OUT/cwp/$NAME.php"
render lang.ini "$OUT/cwp/$NAME.ini"
render mod.html "$OUT/cwp/mod_$NAME.html"
render menuconf.snippet "$OUT/cwp/menuconf.snippet"
render process-jobs.php "$OUT/process-jobs.php"
render fix-module.sh "$OUT/fix-module.sh"
render install.sh "$OUT/install.sh"
render uninstall.sh "$OUT/uninstall.sh"
chmod 0755 "$OUT/fix-module.sh" "$OUT/install.sh" "$OUT/uninstall.sh"

if command -v php >/dev/null 2>&1; then
  for f in "$OUT/cwp/$NAME.php" "$OUT/process-jobs.php"; do php -l "$f" >/dev/null || die "PHP syntax error in $f"; done
fi
echo "Rendered '$NAME' into $OUT"

if ((INSTALL)); then
  if ((APPLY)); then "$OUT/install.sh" --apply; else "$OUT/install.sh"; fi
else
  echo "Next: add your actions to $OUT/process-jobs.php and $OUT/cwp/$NAME.php, then $OUT/install.sh (dry-run) / --apply on the CWP server."
fi
