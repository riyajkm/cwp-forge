# Security policy

## Supported versions

| Version | Supported |
|---|---|
| latest release | yes |
| older releases | security fixes only for the previous minor |

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's private reporting:
**Security tab -> Report a vulnerability** on this repository.

Include: module version, CWP version and OS, steps to reproduce, impact. Redact hostnames, IPs, account names and keys.

Targets: acknowledgement within 5 days, a fix or mitigation plan within 30 days, public disclosure in the release notes once a fixed version is available. We credit reporters who want it.

## Scope

In scope: this module's PHP, JavaScript, engine scripts, installer and cron files.
Out of scope: vulnerabilities in CWP itself (report to the CWP team), in third-party tools we only call, and issues needing prior root access on the server.

## Security model

This module runs part of its code as root inside CWP. See "Security model" in the README for the privilege boundary, what is logged, and how secrets are stored.

We act in good faith toward researchers who follow this policy and do not access data that is not their own.
