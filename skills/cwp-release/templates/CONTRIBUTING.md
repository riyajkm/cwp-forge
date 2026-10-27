# Contributing

Thanks for helping. Keep changes small and tested.

## Setup

- Test on a disposable CWP VM, never a customer or production server.
- Tools: `shellcheck`, `php` (7.4+), `bats`.

## Workflow

1. Branch from `dev`: `git switch -c feature/short-name`.
2. Make the change with tests (`tests/*.bats` for shell, a PHP lint for PHP).
3. Run locally:
   ```bash
   shellcheck -x -S style $(git ls-files '*.sh')
   find . -name '*.php' -print0 | xargs -0 -n1 php -l
   bats tests/
   ```
4. Add a line under `## [Unreleased]` in `CHANGELOG.md`.
5. Open a PR into `dev`. Fill in the template, including the CWP version you tested on.

## Rules

- New scripts: `git update-index --chmod=+x <file>` (Windows commits default to 644).
- Shell: `set -Eeuo pipefail`, quote everything, no `eval`, no `curl | bash`.
- PHP: guard every file (`$include_path` / `$ajax_file`), session check, CSRF, allowlists, prepared statements, escape output. Run the `cwp-security-review` checklist.
- No secrets, real hostnames, IPs or account names in code, tests, issues or logs (use example.com, alice).
- Installers stay idempotent and keep user config.
- Commit messages: imperative, one logical change each.

## Releases (maintainers)

SemVer, Keep a Changelog. Tag `vX.Y.Z` on `main` after the CHANGELOG entry is dated; `release.yml` publishes the tarball and checksums.

## Conduct

Be respectful. See `CODE_OF_CONDUCT.md`.
