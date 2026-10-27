---
description: Security-review a CWP module (path or current directory) with the cwp-reviewer agent
argument-hint: [path-to-module]
allowed-tools: Read, Grep, Glob, Bash(bash:*), Bash(git diff:*), Bash(git ls-files:*), Bash(shellcheck:*), Bash(php -l:*)
---

Security-review the CWP module at `$ARGUMENTS` (default: the current directory).

1. Confirm the path exists and contains PHP or shell files; otherwise say what is missing and stop.
2. Run the read-only scan from the `cwp-security-review` skill: `bash ${CLAUDE_PLUGIN_ROOT}/skills/cwp-security-review/scripts/cwp-review-scan.sh <path>` (if that variable is empty, use the skill's `scripts/` directory in this repo).
3. Launch the `cwp-reviewer` agent on the same path with the scan output as leads. It applies `references/checklist.md` and returns severity-ranked findings with fixes.
4. Present the result: findings by severity (CRITICAL first), checklist pass/fail line, verdict. Keep it short.
5. Do not modify any file. Ask whether to apply fixes; if yes, fix one finding at a time using `references/fix-patterns.md` and re-run the scan.

Redact real hostnames, IPs and accounts in the report.
