# cwp-forge

**Build anything for CWP (Control Web Panel) with an AI coding agent.**

Skills, agents and commands that teach Claude Code, Codex, Gemini CLI, Cursor and Copilot how CWP really works —
including the parts the official docs leave out — so they can build secure admin modules, customer-panel modules,
API integrations and automations, inspect a server, review code and ship releases.

[![CI](https://github.com/riyajkm/cwp-forge/actions/workflows/ci.yml/badge.svg)](https://github.com/riyajkm/cwp-forge/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> Status: v0.1 — early. Built from the official docs, forum knowledge and hands-on debugging on a production
> CWP Pro server while building [CWP Vault](https://github.com/riyajkm/cwp-vault). Reports and fixes welcome.

## Why

CWP's admin panel is mostly ionCube-encoded and its developer docs are thin. Things you only learn the hard way:

- Module AJAX runs through `loader_ajax.php?ajax=<module>&acc=<action>`, where `$include_path` is **not** set — `$ajax_file` is.
- `$_SESSION` is populated but read-only; never call `session_start()`; derive CSRF tokens from `$_SESSION['token']`.
- The admin theme ships Bootstrap 3 with jQuery 2.1.1, where `$.ajax().then()` doesn't transform values and tab events don't always fire.
- `htdocs/admin` is `chattr +i`, and `chattr -R` trips over CWP's own symlinks.
- Old AWS CLI on CWP crashes with `'NoneType' is not iterable` on S3 errors with empty messages (Contabo and other Ceph-based storage).

cwp-forge puts all of it — plus the full CWP API, hooks, paths and data model — into skills an agent loads only when needed.

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

## Example

> Create a CWP admin module that lists accounts close to their disk quota and lets me email the owner.

The agent loads `cwp-admin-module`, scaffolds the page, AJAX handler and menu link with the right guards,
reads `root_cwp.user` safely, and gives you an installer with a dry run.

## Reference implementation

[CWP Vault](https://github.com/riyajkm/cwp-vault) — encrypted S3 backups for CWP — was built with these patterns.

## Contributing

Corrections from real servers are the most valuable contribution: if a skill is wrong for your CWP version,
open an issue with the version and what you saw. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
