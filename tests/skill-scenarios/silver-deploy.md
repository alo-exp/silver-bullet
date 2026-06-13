# silver-deploy Scenario

## Purpose

Validate SB-owned deployment orchestration.

## Expected Behavior

- Detects deployment platform from source evidence.
- Writes `.planning/DEPLOYMENT.md`.
- Runs blast-radius, DevOps gates, runtime-release domain audit, health checks, and rollback readiness.
- Hands production watches to `silver:canary`.
- Blocks failed deployment states until fixed, rolled back, or converted into an incident.
