# cwp-forge

**Build anything for CWP (Control Web Panel) with an AI coding agent.**

Skills, agents and commands that teach Claude Code, Codex, Gemini CLI, Cursor and Copilot how CWP really works,
including the parts the official docs leave out: secure admin modules, customer-panel modules, API integrations,
read-only server inspection, code review and releases.

[![CI](https://github.com/riyajkm/cwp-forge/actions/workflows/ci.yml/badge.svg)](https://github.com/riyajkm/cwp-forge/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/riyajkm/cwp-forge?include_prereleases)](https://github.com/riyajkm/cwp-forge/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/riyajkm/cwp-forge?style=flat)](https://github.com/riyajkm/cwp-forge/stargazers)

> Status: v0.1, early. Built from the official docs, forum knowledge and hands-on debugging on a production
> CWP Pro server while building [CWP Vault](https://github.com/riyajkm/cwp-vault). Reports and fixes welcome.

## What it knows that the docs don't

CWP's admin panel is mostly ionCube-encoded and its developer docs are thin. These are things you normally learn the hard way:

1. **Module AJAX has a different entry point.** It runs through `loader_ajax.php?ajax=<module>&acc=<action>`, and `$include_path` is **not** set there. `$ajax_file` is.
2. **`$_SESSION` is read-only.** It is populated, but never call `session_start()`. Derive CSRF tokens from `$_SESSION['token']`.
3. **The admin theme is old.** It ships Bootstrap 3 with jQuery 2.1.1, where `$.ajax().then()` doesn't transform values and tab events don't always fire.
4. **`htdocs/admin` is `chattr +i`.** Installers must handle that, and `chattr -R` trips over CWP's own symlinks.
5. **Old AWS CLI on CWP crashes on some S3 errors.** It fails with `'NoneType' is not iterable` when the error message is empty, which happens on Contabo and other Ceph-based storage.

cwp-forge puts these, plus the full CWP API, hooks, paths and data model, into skills an agent loads only when it needs them.

## What's inside

| Skill | Use it to |
|---|---|
| `cwp-admin-module` | Scaffold a complete, secure admin module: page, AJAX, CSRF, safe root calls, native CWP UI, menu link, installer |
| `cwp-user-module` | Build a customer-panel module, with a safe root job queue for privileged actions |
| `cwp-api` | Call the CWP REST API (all functions) from PHP, Python or bash; billing integrations |
| `cwp-hooks-automation` | Account/DNS hooks, cron, surviving CWP updates |
| `cwp-inspect` | Map a live server **read-only** into a facts file the other skills use |
| `cwp-troubleshoot` | Diagnose common CWP problems (backups/S3, AutoSSL, mail, PHP-FPM) |
| `cwp-security-review` | Review a CWP module for injection, CSRF, traversal, secrets and session mistakes |
| `cwp-release` | Package and publish a module: installer, upgrades, CI, changelog, releases |

Agents: `cwp-architect` (plans), `cwp-reviewer` (read-only review), `cwp-scout` (read-only server inspection).
Commands: `/cwp-new-module`, `/cwp-inspect`, `/cwp-review`.

Safety: anything that touches a server is a **dry run by default** and needs `--apply`. The inspector and reviewers are read-only.

## Demo

> Create a CWP admin module called `quota_watch` that lists accounts close to their disk quota and lets me email the owner.

The agent loads `cwp-admin-module` and runs its generator, `new-admin-module.sh quota_watch`, which writes a complete module:

```
quota_watch/
├── cwp/
│   ├── addons/ajax/ajax_quota_watch.php
│   ├── include/menu.snippet
│   ├── modules/
│   │   ├── language/en/quota_watch.ini
│   │   ├── quota_watch.php
│   │   └── quota_watch/lib.php
├── engine
├── fix-menu.sh
├── install.sh
└── uninstall.sh
```

The agent then fills in the quota logic, and `/cwp-review` checks the result for injection, CSRF and traversal mistakes.

## Built with it: CWP Vault

[CWP Vault](https://github.com/riyajkm/cwp-vault), encrypted and ransomware-proof S3 backups for CWP, was built with these patterns.

[![CWP Vault dashboard inside the CWP admin panel](https://raw.githubusercontent.com/riyajkm/cwp-vault/main/docs/images/dashboard.jpg)](https://github.com/riyajkm/cwp-vault)

## Install

**Claude Code**

```
/plugin marketplace add riyajkm/cwp-forge
/plugin install cwp-forge@cwp-forge
```

**Codex, Gemini CLI, Cursor, Copilot and 40+ other agents** (via the open Agent Skills standard)

```
npx skills add riyajkm/cwp-forge
```

Or copy any folder from `skills/` into your agent's skills directory.

## Contributing

Corrections from real servers are the most valuable contribution: if a skill is wrong for your CWP version,
open an issue with the version and what you saw. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
