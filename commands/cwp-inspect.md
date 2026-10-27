---
description: Read-only inspection of a CWP server's layout, versions and module state using the cwp-inspect skill
argument-hint: [what to inspect, e.g. versions | modules | menu | php | all]
allowed-tools: Read, Grep, Glob, Bash(ls:*), Bash(cat:*), Bash(stat:*), Bash(lsattr:*), Bash(grep:*)
---

Inspect the CWP installation (read-only) for: `$ARGUMENTS` (default: all).

Use the `cwp-inspect` skill and follow it exactly. Rules:

- Read-only. Run no command that writes, restarts, installs or contacts the network. If the skill offers a script, run it only in its read-only mode.
- If this is not a CWP server (no `/usr/local/cwpsrv`), say so and stop; offer to inspect a repo checkout instead.
- Report: CWP version, OS, cwpsrv PHP version and pool user, installed third-party admin modules and user modules, `3rdparty.php` menu lines, immutability (`lsattr -d`) of the admin dirs, ports in use, relevant `/usr/local/cwp/.conf` files present.
- Redact hostnames, IPs, accounts and keys in the output (use placeholders like example.com, alice).
- End with 3 or fewer follow-up suggestions.
