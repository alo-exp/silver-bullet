# Silver Bullet DevOps Cycle

Silver Bullet owns the DevOps workflow lifecycle. Optional provider plugins may
extend this workflow with Terraform, Kubernetes, cloud, deployment, or monitoring
expertise, but they do not own SB context, plan, execute, verify, review, ship,
or release sequencing.

Legacy GSD, Superpowers, and Anthropic knowledge-work markers may still satisfy
hooks during migration, but new DevOps workflow execution must use SB-owned
commands.

## HOST MODEL BOUNDARY

Silver Bullet does not select models or route host subagents. Use the model and
execution primitives provided by the active host session. If an optional external
tool has its own model preferences, configure that tool outside SB workflow
instructions.

## Entry Points

| Intent | Command |
|---|---|
| Let SB classify the task | `/silver <request>` |
| Infrastructure or deployment work | `/silver:devops` |
| Blast-radius assessment | `/silver:blast-radius` |
| DevOps quality gates | `/devops-quality-gates` |
| Release infrastructure milestone | `/silver:release` |

If a request touches Terraform, Pulumi, Kubernetes, Helm, Docker, CI/CD,
cloud-provider resources, environments, secrets, monitoring, rollback, or
deployment, route through `/silver:devops`.

## Incident Fast Path

For active incidents:

1. Stabilize the system and capture the incident context.
2. Run `/silver:blast-radius` before changing infrastructure.
3. Apply the smallest safe change in the lowest affected environment.
4. Run `/silver:verify`.
5. Capture a follow-up task with `/silver:add` for the full review or permanent
   fix when the incident is over.

Emergency work does not bypass verification, rollback evidence, or post-incident
capture.

## Required Lifecycle

### 0. Orientation

Run `silver:scan` or `/silver:context` to understand current infrastructure,
state backends, environments, promotion order, and operational constraints.

### 1. Blast radius

Run `/silver:blast-radius`.

The output must identify affected systems, dependencies, failure scenarios,
rollback strategy, change window risk, and approval needs. HIGH and CRITICAL
blast radius findings require explicit user approval before execution.

### 2. Optional provider extension

Invoke optional DevOps/provider tooling only when it adds domain-specific value:
Terraform, Kubernetes, cloud-provider IAM, CI/CD, monitoring, or deployment
platform checks.

Extension output feeds SB planning and review. It does not replace SB planning.

### 3. DevOps quality gates

Run `/devops-quality-gates` before planning.

All applicable infrastructure dimensions must pass: reliability, security,
scalability, modularity, testability, observability, and change-safety.

### 4. Context

Run `/silver:context`.

Capture target environments, IaC toolchain, state backend, locking strategy,
naming and tagging conventions, secrets boundaries, rollback plan, monitoring
expectations, and promotion order.

### 5. Plan

Run `/silver:plan`.

The plan must include dependency-ordered waves, environment-specific inputs,
policy checks, validation commands, drift detection, rollback evidence, and
manual approval points.

### 6. Execute

Run `/silver:execute`.

TDD is not required for declarative infrastructure changes. Use IaC validation,
plan review, policy-as-code, smoke checks, drift detection, rollback testing, and
monitoring verification instead.

Apply in the lowest affected environment first. Promote only after verification
passes.

### 7. Verify

Run `/silver:verify`.

DevOps verification must include health checks, no unexpected drift, monitoring
and alerting evidence, rollback procedure evidence, runbook freshness, and
environment-specific acceptance criteria.

### 8. Review

Run the SB review sequence:

1. `/silver:review-request`
2. `/silver:review`
3. `/silver:review-triage`

For infrastructure, review must inspect least privilege, network exposure,
encryption, backups, tags/labels, idempotency, state handling, observability, and
plan output, not just source files.

### 9. Secure

Run `/silver:secure`.

Confirm no credentials are committed, IAM boundaries are least-privilege, network
exposure is intentional, secret references are safe, and defaults are secure.

### 10. Promote environments

Promote dev -> staging -> production only after the previous environment is
verified. Never skip staging for non-emergency production changes.

For each promoted environment:

1. Run `/silver:execute` with environment-specific inputs.
2. Run `/silver:verify` for health, drift, monitoring, and rollback evidence.

### 11. CI and deploy readiness

- Run `/verify-tests` when the repo has runnable verification commands.
- Confirm CI is green before deployment or PR/release operations.
- If CI is red, run `/silver:debug`, fix, re-run tests, and re-check CI.
- Run the SB deploy readiness path before production apply or public release.

Deploy readiness covers rollback plan, monitoring, on-call availability, change
window, incident communication, and post-deploy observation.

### 12. Ship

Run `/silver:branch-finish` on feature branches, then `/silver:ship`.

The PR body should include blast radius, environments touched, verification
evidence, rollback evidence, monitoring evidence, and known follow-ups.

### 13. Release when requested

Run `/silver:release` for milestone-level publishing. The release workflow owns
release quality gates, audits, security hard gate, docs readiness, fresh tests,
`silver:ship`, milestone archival, `/silver:create-release`, and post-release
follow-up summary.

Keep operational facts in `docs/knowledge/YYYY-MM.md` and reusable operational
lessons in `docs/learnings/YYYY-MM.md` when the release or deployment changes
what future maintainers need to know.

## Non-Skippable Gates

- `/silver:blast-radius`
- `/devops-quality-gates` before planning and before ship/release
- `/silver:verify`
- `/silver:review` and `/silver:review-triage`
- `/silver:secure`
- `/verify-tests` before PR, deploy, or release when tests exist
- SB deploy readiness before production deployment

## Optional Extension Plugins

Provider/tool plugins remain external because they extend SB into specialized
domains. Use them as evidence producers and implementation helpers under SB
control, not as lifecycle owners.

## Legacy Compatibility

Old GSD/Superpowers/Anthropic marker names may appear in existing project state
or migration tools. Hooks may count those markers as aliases for SB-owned
markers, but new workflow instructions must not invoke the old lifecycle
commands unless the user explicitly asks to run an external legacy plugin.
