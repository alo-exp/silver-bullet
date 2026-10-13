# silver-canary Scenario

## Purpose

Validate SB-owned post-deploy runtime watch.

## Expected Behavior

- Writes `.planning/CANARY.md`.
- Selects HTTP, browser, logs, metrics, and rollback checks from available evidence.
- Applies `sb:domain-audit --pack runtime-release`.
- Blocks repeated runtime failures, critical console errors, broken core flows, or missing rollback evidence.
- Hands confirmed production-impacting failures to `sb:incident`.
