#!/usr/bin/env bash
# Skeleton installer for a CWP admin module. Replace NAME and the copy list.
# Full working version: see the cwp-admin-module skill templates (install.sh).
# Idempotent; never overwrites existing config or secrets. Run as root: sudo ./install.sh [--dry-run]
set -Eeuo pipefail
IFS=$'\n\t'
umask 022

NAME=mymodule
INSTALLER_VERSION=0.1.0
HOME_DIR=/usr/local/$NAME
CWP_RES=/usr/local/cwpsrv/htdocs/resources/admin
MENU_FILE=$CWP_RES/include/3rdparty.php
MENU_LINE="<li><a href=\"index.php?module=$NAME\"><span class=\"icon16 icomoon-icon-database\"></span>My Module</a></li>"
CRON_FILE=/etc/cron.d/$NAME

SRC=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DRY=0 HEAL=0 FORCE=0
LOCKED_DIRS=()

info() { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
run() { if ((DRY)); then (IFS=' '; printf '+ %s\n' "$*"); else "$@"; fi; }

usage() {
  cat <<USAGE
$NAME installer $INSTALLER_VERSION
Usage: sudo ./install.sh [--dry-run] [--heal] [--force] [--version]
  --dry-run  print the actions, change nothing
  --heal     re-add module files and menu line after a CWP update; keep config
  --force    continue on an unsupported OS
USAGE
}

while (($#)); do
  case $1 in
    --dry-run) DRY=1 ;;
    --heal) HEAL=1 ;;
    --force) FORCE=1 ;;
    --version) echo "$INSTALLER_VERSION"; exit 0 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

# Lift immutability only on directories we write into; restore on any exit.
unlock_dir() {
  local d=$1
  if lsattr -d "$d" 2>/dev/null | cut -c5 | grep -q i; then
    run find "$d" -xdev ! -type l -exec chattr -i {} +
    LOCKED_DIRS+=("$d")
  fi
}
relock() {
  local d
  for d in "${LOCKED_DIRS[@]}"; do
    run find "$d" -xdev ! -type l -exec chattr +i {} +
  done
}
trap relock EXIT
trap 'die "failed at line $LINENO (command: $BASH_COMMAND)"' ERR

preflight() {
  ((DRY)) || [[ $EUID -eq 0 ]] || die "run as root"
  [[ -d $CWP_RES ]] || die "CWP admin resources not found at $CWP_RES"
  if ! grep -qE 'AlmaLinux|Rocky|CentOS' /etc/os-release && ! ((FORCE)); then
    die "unsupported OS (use --force to continue)"
  fi
}

install_module() {
  unlock_dir "$CWP_RES"
  run install -d -m 0755 "$CWP_RES/modules/$NAME" "$CWP_RES/addons/ajax"
  run install -m 0644 "$SRC/cwp-module/$NAME.php" "$CWP_RES/modules/$NAME.php"
  run install -m 0644 "$SRC/cwp-module/ajax_$NAME.php" "$CWP_RES/addons/ajax/ajax_$NAME.php"
  run install -m 0644 "$SRC/cwp-module/language/en/$NAME.ini" "$CWP_RES/modules/language/en/$NAME.ini"
}

add_menu() {
  if [[ -f $MENU_FILE ]] && grep -qF -- "module=$NAME" "$MENU_FILE"; then
    info "menu entry already present"
    return
  fi
  unlock_dir "$(dirname "$MENU_FILE")"
  if ((DRY)); then echo "+ append menu line to $MENU_FILE"; else printf '%s\n' "$MENU_LINE" >>"$MENU_FILE"; fi
}

install_config() {
  run install -d -m 0750 "$HOME_DIR" "$HOME_DIR/var"
  if [[ -e $HOME_DIR/config ]]; then
    info "config exists, keeping it"
  else
    run install -m 0600 "$SRC/engine/config.example" "$HOME_DIR/config"
  fi
}

preflight
install_module
add_menu
((HEAL)) || install_config
if ! ((HEAL)); then
  [[ -e $CRON_FILE ]] || run install -m 0644 "$SRC/contrib/cron" "$CRON_FILE"
fi
info "done ($NAME $INSTALLER_VERSION)"
