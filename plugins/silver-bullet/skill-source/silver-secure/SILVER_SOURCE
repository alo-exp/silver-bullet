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
   - infra exposure when relevant.
4. Invoke `security` for the independent hard gate when available or required
   by the workflow.
5. Record mitigations, residual risks, and BLOCK/WARN/INFO findings.

## Exit Gate

Security passes only when BLOCK findings are fixed or explicitly accepted by
the user with the risk stated in the artifact.
