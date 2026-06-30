---
name: "silver:incident"
title: "Incident"
description: >
  This skill should be used for SB-owned incident response, postmortem,
  corrective action filing, and release/process feedback loops.
argument-hint: "<incident scope or symptoms>"
version: 0.1.0
---

# /silver:incident - Incident Response And Postmortem

SB-owned incident workflow for active runtime failures, release regressions, and
customer-impacting defects. It extends `silver:forensics` with impact, response,
and corrective-action ownership.

## Output

Write or update `.planning/INCIDENT.md`.

The artifact must include:

- impact summary and affected users/systems;
- timeline with detection, mitigation, and recovery timestamps;
- current status and rollback/containment decision;
- root cause and contributing process gaps;
- corrective actions filed through `silver:add`;
- verification and canary evidence after recovery.

## Process

1. Display `SILVER BULLET > INCIDENT`.
2. Establish severity, affected surface, and whether mitigation or rollback is
   needed before investigation continues.
3. Capture evidence from logs, CI/deploy history, release notes, user reports,
   monitoring, and changed files.
4. Invoke or apply `silver:forensics` for root-cause reconstruction when the
   failure path is unclear.
5. Invoke or apply `silver:domain-audit --pack incident-retro` and affected
   runtime/API/data/security packs.
6. Record containment, fix, verification, and canary evidence.
7. File every corrective action through `silver:add` with owner, priority, and
   due expectation.
8. Feed recurring process gaps into `silver:retro`.

## Exit Gate

The incident workflow is complete only when the user-impacting state is
mitigated or explicitly accepted, root cause is evidenced, and corrective
actions are tracked.
