---
name: "silver:secure"
title: "Secure"
description: This skill verifies security and threat-mitigation coverage for completed SB work.
argument-hint: "<phase or change scope>"
version: 0.1.0
---

# /silver:secure - Security Verification

SB-owned secure phase verifies security and threat-mitigation coverage. Use the
local `security` skill as the core threat-review lens when available, but this
skill owns the phase artifact and exit decision.

## Output

Write or update `.planning/SECURITY.md` or the current phase security section.

## Process

1. Display `SILVER BULLET > SECURE`.
2. Read SPEC, PLAN, SUMMARY, REVIEW, dependency changes, auth/data flows, and
   touched configuration.
3. Check:
   - authn/authz and privilege boundaries;
   - secrets and credential handling;
   - injection, XSS, CSRF, SSRF, deserialization, and filesystem/network access;
   - data retention, privacy, logging, and telemetry;
   - dependency and supply-chain risk;
   - infra exposure when relevant;
   - runtime exploitability when a live or local target is available.
4. Invoke or apply `silver:domain-audit` with `dependency-supply`,
   `environment-secrets`, `api-contract`, `data-contract`, `runtime-release`,
   or `accessibility` packs as the scope requires.
5. For penetration-test-style requests, combine white-box source review with
   black-box checks only against authorized targets, record exact commands and
   evidence, and stop on any material exploitability finding until fixed or
   explicitly accepted.
6. Invoke `security` for the independent hard gate when available or required
   by the workflow.
7. Record mitigations, residual risks, and BLOCK/WARN/INFO findings.

## Exit Gate

Security passes only when BLOCK findings are fixed or explicitly accepted by
the user with the risk stated in the artifact.
