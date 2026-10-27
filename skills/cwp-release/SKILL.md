---
name: cwp-release
description: Package and publish a Control Web Panel (CWP) module as a professional open-source project. Use when asked to release, ship, package, open-source, version, tag, document or announce a CWP admin or user module, or to write its install.sh/uninstall.sh/upgrade, CHANGELOG, GitHub Actions CI (shellcheck, php -l, bats), release workflow, SECURITY.md, CONTRIBUTING.md, issue templates, README, or a CWP forum post. Covers idempotent installers with dry-run and chattr handling, self-heal after CWP updates, SemVer and Keep a Changelog, branch protection, repo topics, git executable bits from Windows. Not for the module's code (cwp-admin-module, cwp-user-module) or its security audit (cwp-security-review).
license: MIT
compatibility: Needs git; gh CLI optional for repo settings. Templates target bash 4+, AlmaLinux/Rocky 8 CWP servers, GitHub Actions.
---

# Release a CWP module

Goal: a stranger can read the README, run one command, get the module, upgrade it safely, and remove it cleanly. Before releasing, run the `cwp-security-review` skill and fix CRITICAL and HIGH findings.

## Steps

1. **Layout.** Use this tree (adapt names):
   ```
   install.sh  uninstall.sh  upgrade (optional, or install.sh is the upgrader)
   cwp-module/   # files copied under /usr/local/cwpsrv/htdocs/resources/admin/
   engine/       # root CLI (if any), installed under /usr/local/<name>/
   contrib/      # cron, logrotate, self-heal units
   tests/        # *.bats and stubs
   docs/  .github/  CHANGELOG.md  README.md  LICENSE  SECURITY.md  CONTRIBUTING.md  CODE_OF_CONDUCT.md  .gitattributes  .editorconfig
   ```
2. **Installer.** Start from [templates/install.sh](templates/install.sh) (a skeleton; the fuller scripts live in the `cwp-admin-module` templates). Rules:
   - `set -Eeuo pipefail`, `umask 022`, run as root only, supported-OS check with `--force` override.
   - **Idempotent**: second run changes nothing; never overwrite existing config or secrets (`install -m 0600` only if absent).
   - `--dry-run` prints every action (`run()` wrapper), changes nothing. `--version`, `--help`, `--no-module`.
   - **chattr-safe**: `/usr/local/cwpsrv/htdocs/admin` is immutable on CWP. Lift with `find DIR -xdev ! -type l -exec chattr -i {} +`, write, restore the same way, only on dirs you write into. Use a `trap` so the lock is restored on failure.
   - Menu entry: append the `<li>` to `resources/admin/include/3rdparty.php` only if absent (create the file if missing).
   - Pin downloads (version and SHA-256 hard-coded); never `curl | bash`.
   - Cron to `/etc/cron.d/<name>`, shipped commented out or enabled by a flag.
3. **Uninstall.** `uninstall.sh [--dry-run] [--purge]`: removes module files, menu line, cron; **keeps config, data and secrets** unless `--purge` plus an interactive "type the name" confirmation.
4. **Upgrade.** Re-running `install.sh` from the new release upgrades; keep a `VERSION` file and print `old -> new`. Config migrations are additive and idempotent. Backup replaced files to `/usr/local/<name>/var/backup/<timestamp>/`.
5. **Self-heal after CWP updates.** CWP updates can replace `3rdparty.php`, reset immutability or overwrite the resources dir. Ship `contrib/<name>-heal` plus a daily `/etc/cron.d/<name>-heal` that runs `install.sh --heal` (re-adds the menu line and module files, never touches config) and logs one line. Document `install.sh --heal` in the README.
6. **Version.** SemVer; one source of truth (`VERSION` file or `INSTALLER_VERSION`), checked equal to the newest `CHANGELOG.md` heading in CI. Pre-1.0: minor = features, patch = fixes, say that breaking changes may land in minors.
7. **Changelog.** Keep a Changelog: `## [Unreleased]`, then `## [x.y.z] - YYYY-MM-DD` with Added/Changed/Deprecated/Removed/Fixed/Security. Use [templates/CHANGELOG.md](templates/CHANGELOG.md).
8. **CI and release.** Copy [templates/ci.yml](templates/ci.yml) (shellcheck, `php -l` on the PHP versions CWP ships, bats) and [templates/release.yml](templates/release.yml) (tag `v*.*.*` -> release notes cut from CHANGELOG, tarball + SHA256SUMS).
9. **Repo hygiene.** [references/github-setup.md](references/github-setup.md): branch protection, topics, issue templates, security policy, Windows executable-bit fix, `.gitattributes` with `eol=lf`.
10. **README.** [references/readme-structure.md](references/readme-structure.md).
11. **Announce.** [references/community.md](references/community.md): CWP forum etiquette and developer programme. Verify the current process before promising anything; do not invent endorsements or compatibility claims.

## Pre-release gate (stop if any fails)

- [ ] `cwp-security-review` scan clean or findings accepted in writing
- [ ] `shellcheck -x` clean at all severities (CI fails on info)
- [ ] `php -l` passes for every PHP file on the oldest and newest PHP you claim
- [ ] `install.sh --dry-run` run twice on a disposable CWP VM: second run reports no changes
- [ ] Uninstall then reinstall leaves config intact
- [ ] `git ls-files --stage | grep -v ' 100755 ' | grep '\.sh$'` prints nothing (scripts executable)
- [ ] CHANGELOG entry dated, version bumped, tag `vX.Y.Z` matches
- [ ] No real hostnames, IPs, accounts, keys in repo (`git grep -nE '[0-9]{1,3}(\.[0-9]{1,3}){3}'`)

## Rules

- Never commit, tag or push without the user asking. Propose the exact commands.
- Never test installers on a customer or production server. Use a disposable VM.
- Do not claim support for a CWP version you have not tested; write the tested matrix in the README.
