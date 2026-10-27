---
description: Scaffold a new CWP module (admin or user panel) from the cwp-forge templates
argument-hint: <module-name> [admin|user]
---

Create a new CWP module named `$ARGUMENTS`.

1. Parse the arguments: the first word is the module name (lowercase letters, digits, underscore; must match `^[a-z][a-z0-9_]{1,30}$`, else stop and ask). The second word is `admin` or `user`; if missing, ask which panel and what the module should do (one short question).
2. Delegate planning to the `cwp-architect` agent with the module name, panel and purpose. Show the user the plan (files, actions table, privilege boundary, risks) and wait for a go-ahead before writing code.
3. After approval, use the `cwp-admin-module` skill (admin panel) or the `cwp-user-module` skill (user panel) and its templates to create the files in the current repository, never on a live server path.
4. Add install/uninstall using the `cwp-release` skill templates (idempotent, `--dry-run`, chattr-safe, keep config).
5. Run the scan `cwp-security-review/scripts/cwp-review-scan.sh` on the new module and fix CRITICAL and HIGH hits.
6. Report: files created, how to test on a disposable CWP VM, what is left. Do not commit.

Use example.com and alice for any sample data. Do not install anything on this machine or any server.
