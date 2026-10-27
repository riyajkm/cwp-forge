# GitHub repository setup for a CWP module

Contents: 1 Create - 2 Branches and protection - 3 Executable bits from Windows - 4 Line endings - 5 Topics and metadata - 6 Issue and PR templates - 7 Security policy - 8 Release flow

## 1. Create
```bash
gh repo create OWNER/cwp-mymodule --public --description "Short what-it-does for CWP (Control Web Panel)" --license mit
```
Name `cwp-<thing>`; start with a one-line value statement in the description.

## 2. Branches and protection
- `main` = released code, `dev` = integration. Work in `feature/*` branches, PR into `dev`, release PR `dev -> main`, tag on `main`.
- Protect `main` (and `dev` if others push): require PR, require status checks `shellcheck`, `bats`, `php-lint`, dismiss stale approvals, no force pushes, no deletions, linear history optional.
```bash
gh api -X PUT repos/OWNER/cwp-mymodule/branches/main/protection --input - <<'JSON'
{
  "required_status_checks": {"strict": true, "contexts": ["shellcheck", "bats", "php-lint (7.4)", "php-lint (8.1)"]},
  "enforce_admins": false,
  "required_pull_request_reviews": {"required_approving_review_count": 0, "dismiss_stale_reviews": true},
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
```
Check the exact job names in the Actions UI first; a mismatched context blocks every merge. A solo maintainer keeps review count 0 but still gets the CI gate.

## 3. Executable bits from Windows
Files committed from Windows get mode 100644, so CI cannot run them. Fix every script before committing:
```bash
git update-index --chmod=+x install.sh uninstall.sh engine/* scripts/*.sh tests/helpers/*.sh
git ls-files --stage | grep '\.sh$'        # every line must start with 100755
```
Add a CI step that fails when a `*.sh` is not 100755 (see ci.yml `exec-bits`).

## 4. Line endings
`.gitattributes`:
```
* text=auto eol=lf
*.sh text eol=lf
*.php text eol=lf
*.bats text eol=lf
```
A CRLF in a shebang makes `bash\r: No such file` on the server.

## 5. Topics and metadata
```bash
gh repo edit OWNER/cwp-mymodule --add-topic cwp --add-topic control-web-panel --add-topic centos-web-panel \
  --add-topic hosting --add-topic sysadmin --add-topic bash --add-topic php --add-topic almalinux \
  --homepage "https://example.com/cwp-mymodule"
```
Enable Issues and Discussions; disable Wiki if docs live in `docs/`.

## 6. Issue and PR templates
`.github/ISSUE_TEMPLATE/bug_report.yml` fields: CWP version, OS, PHP (cwpsrv) version, module version, what happened, expected, logs (with a warning to redact hostnames, IPs, accounts, keys). `feature_request.yml`: problem, proposal, alternatives. `config.yml`: `blank_issues_enabled: false` and a contact link to SECURITY.md for vulnerabilities.
`.github/PULL_REQUEST_TEMPLATE.md`: what/why, tested on (CWP version), checklist (shellcheck, php -l, bats, CHANGELOG entry, docs).

## 7. Security policy
Ship `SECURITY.md` (template provided): supported versions, private reporting via GitHub Security Advisories (enable "Private vulnerability reporting"), response targets, what is in scope (the module, its installer), safe-harbour sentence. Enable Dependabot alerts for GitHub Actions (`.github/dependabot.yml` with `package-ecosystem: github-actions`).

## 8. Release flow
1. PR `dev -> main` with CHANGELOG moved from Unreleased to `[x.y.z] - date`, version files bumped.
2. After merge: `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z` (only when the user asks).
3. `release.yml` builds the tarball, `SHA256SUMS`, and publishes notes cut from CHANGELOG. Verify the Release page, then update README badges and the compatibility matrix.
4. Pin the install command in the README to the tag, not `main`.
