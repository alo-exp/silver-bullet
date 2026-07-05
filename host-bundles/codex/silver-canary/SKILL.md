---
name: "silver:canary"
title: "Canary"
description: >
  This skill should be used for SB-owned post-deploy canary and runtime watch
  evidence after releases, deploys, or high-risk runtime changes.
argument-hint: "<live URL or runtime scope> [--duration <time>] [--interval <time>]"
version: 0.1.0
---

# /silver:canary - Post-Deploy Runtime Watch

SB-owned post-deploy confidence gate. It observes the released system after a
deployment and records evidence instead of treating a green deploy command as
user safety.

**Pre-execution** (blocks runtime watch edits until recorded):

`silver:blast-radius` → `silver:plan`

**Post-execution:** `silver:execute` → `silver:verify` → `silver:ship`

Queue source: `hooks/lib/orchestrator-state.sh` (`silver-canary` composer).

## Output

Write or update `.planning/CANARY.md`.

The artifact must include:

- target URL/service, duration, interval, and error threshold;
- HTTP/browser/log/metric checks selected;
- baseline response or screenshot evidence;
- failures, timestamps, and rollback decision;
- final recommendation: `PASS`, `PASS_WITH_WARNINGS`, or `BLOCK`.

## Process

1. Display `SILVER BULLET > CANARY`.
2. Identify live routes, health endpoints, critical user flows, and available
   observability sources.
3. Select watch modes:
   - HTTP checks for status, latency, redirects, cache headers, and response shape;
   - browser checks for console errors, first-screen rendering, auth-free flows,
     accessibility smoke, and visual regressions;
   - logs/metrics checks when the environment exposes them;
   - rollback readiness check for production-impacting changes.
4. Invoke or apply `silver:domain-audit --pack runtime-release`.
5. Run checks for the requested duration or a documented quick-watch window.
6. Escalate repeated failures, critical console errors, 5xx responses, broken
   core flows, or missing rollback evidence as `BLOCK`.
7. If a production-impacting failure is confirmed, hand off to `silver:incident`.

## Exit Gate

Canary passes only when runtime evidence covers the released artifact and no
unresolved `BLOCK` remains. Passing CI alone is not canary evidence.
