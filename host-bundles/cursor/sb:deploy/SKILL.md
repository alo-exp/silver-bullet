---
name: sb:deploy
description: >
  This skill should be used for SB-owned deployment orchestration: platform
  detection, deploy command safety, health checks, rollback readiness, and
  release evidence.
argument-hint: "<environment or deploy scope> [--dry-run|--execute]"
version: 0.1.0
---

# /sb:deploy - Deployment Workflow

SB-owned deployment orchestration for production or staging rollout. It is a
DevOps/release workflow surface, not a shortcut around `sb:devops`,
`sb:ship`, or `sb:release`.

**Pre-execution** (blocks deploy actions until recorded):

`sb:blast-radius` → `devops-quality-gates` → `sb:plan`

**Post-execution:** `sb:execute` → `sb:verify` → `security` → `sb:secure` → `sb:ship`

Queue source: `hooks/lib/orchestrator-state.sh` (`silver-deploy` composer).

## Output

Write or update `.planning/DEPLOYMENT.md`.

The artifact must include:

- target environment and platform evidence;
- deploy command and dry-run/result evidence;
- required CI status and artifact/version pointer;
- rollback command or rollback owner;
- health checks, smoke tests, and monitoring links;
- `sb:canary` plan when production traffic is affected.

## Process

1. Display `SILVER BULLET > DEPLOY`.
2. Detect platform from source evidence: GitHub Actions, Vercel, Netlify, Fly,
   Railway, container scripts, Terraform/Pulumi, custom scripts, or manual runbook.
3. Invoke or apply `sb:blast-radius` for production or infrastructure-impacting
   deploys.
4. Invoke or apply `devops-quality-gates` and `sb:domain-audit` with
   `ci-workflow`, `environment-secrets`, and `runtime-release` packs.
5. Confirm the deployed artifact maps to the reviewed commit/tag.
6. Prefer a dry run, preview, or staging deploy before production when available.
7. Run the deploy command only when the release/ship workflow allows it and the
   user has not constrained deployment.
8. Verify health endpoints, core routes, logs/metrics where available, and
   rollback readiness.
9. Hand off to `sb:canary` for post-deploy watch.

## Exit Gate

Deployment passes only when the target environment, deployed artifact, health
evidence, rollback path, and residual risks are recorded. A failed deploy is a
`BLOCK` until rolled back, fixed, or explicitly converted into an incident.
