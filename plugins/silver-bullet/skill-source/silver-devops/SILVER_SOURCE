---
name: "silver:devops"
title: "DevOps"
description: >
  This skill should be used for SB-owned infrastructure/CI-CD workflow: intel → silver:blast-radius → devops-skill-router → devops-quality-gates (7 IaC dims) → SB plan/execute/verify → review → secure → ship
argument-hint: "<infrastructure or CI/CD change description>"
version: 0.1.0
---

# /silver:devops — Infrastructure Composition Spec

SB **queue builder** for infra/CI/CD/IaC work. Parent orchestrator seeds the queue and spawns Task workers — does not execute inline.

**Key design principles:**
- No brainstorming phase — infrastructure changes are driven by operational requirements established upstream (in silver:feature or silver:research). Blast-radius analysis replaces the product/engineering brainstorm.
- Uses `devops-quality-gates` (7 IaC-adapted dimensions) instead of the standard product quality sweep at BOTH pre-plan and pre-ship gates.
- Application TDD is not applicable to pure infra plans; IaC uses plan, dry-run, policy, security, drift, and rollback validation instead.
- **Config alignment:** `skills.required_deploy_devops` in `templates/silver-bullet.config.json.default` intentionally omits `tdd` (present in `required_deploy` for app work). This is by design — do not add `tdd` to devops delivery gates without changing the IaC policy in this skill.

**The 7 IaC quality dimensions:** reliability, security, scalability, modularity, testability, observability, change-safety. (Usability omitted because infra has no direct user interface; reusability/extensibility are covered by modularity/change-safety in IaC.)

Never implements infra changes directly — composition spec only.

## Mandatory dependency execution

SB separates pre-execution gates from post-execution gates.

Before implementation edits, the execution trace must show the pre-execution chain:

1. `silver:scan` when rapid SB orientation is useful
2. `silver:blast-radius`
3. `devops-skill-router`
4. `devops-quality-gates` (pre-plan)
5. `security` (pre-plan infrastructure hard gate)
6. `silver:context`
7. `silver:plan`
8. `silver:validate` (pre-build gap analysis — after plan exists)

After execution, complete review → verify → secure → validate → pre-ship devops quality gates → ship.

## Pre-flight: Load Preferences

Read the **User Workflow Preferences** section of `silver-bullet.md` to load user workflow preferences before any other step.

```bash
grep -A 50 "^## [0-9]\+\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
SILVER BULLET ► DEVOPS WORKFLOW

Change: {$ARGUMENTS or "(not specified)"}
Mode:   {interactive | autonomous — from §10e or session selection}
```

### Activate devops-cycle enforcement profile

At workflow start, set the project enforcement profile so hooks use `required_deploy_devops` and DevOps planning gates:

```bash
if [[ -f .silver-bullet.json ]] && command -v jq >/dev/null 2>&1; then
  tmp="$(mktemp)"
  jq '.project.active_workflow = "devops-cycle"' .silver-bullet.json > "$tmp" && mv "$tmp" .silver-bullet.json
fi
```

This must run before the first planning skill so `completion-audit.sh` and `dev-cycle-check.sh` apply the DevOps skill lists.

## Composition Proposal

Before beginning execution, read existing artifacts to determine context and propose which flows to include or skip.

### 1. Context Scan

Check the following artifacts and set skip/include flags:

| Artifact | Signal | Action |
|----------|--------|--------|
| `.planning/` directory exists | Project already bootstrapped | Skip FLOW 1 (BOOTSTRAP) |
| `.planning/STATE.md` exists | SB state present | Skip FLOW 1 (BOOTSTRAP) |

```bash
# Check for existing planning artifacts
[ -d ".planning" ] && echo "SKIP FLOW 1 — .planning/ exists" || echo "Include FLOW 1"
```

Note: FLOW 7 (DESIGN CONTRACT) and FLOW 9 (UI QUALITY) are never included in the devops workflow — infra has no user-facing interface.

### 2. Build Flow Chain

Construct the proposed flow chain for infrastructure/CI-CD work. Default chain:

FLOW 1 (BOOTSTRAP) [skip if .planning/ exists] → FLOW 2 (ORIENT) → FLOW 3 (CLARIFY) [if scope unclear] → FLOW 4 (DECIDE) [if IaC/tooling choice needed] → FLOW 13 (QUALITY GATE, pre-plan, DevOps dimensions + domain packs) → FLOW 6 (PLAN) → FLOW 8 (EXECUTE) → FLOW 10 (REVIEW) → FLOW 12 (VERIFY) → FLOW 11 (SECURE) [always included — infra work] → FLOW 13 (QUALITY GATE, pre-ship, DevOps dimensions + domain packs) → FLOW 14 (SHIP)

Note: FLOW 11 (SECURE) is always included for any infrastructure engagement. FLOW 7 (DESIGN CONTRACT) and FLOW 9 (UI QUALITY) are never included.

### 3. Display Proposal

Display the composition proposal to the user:

```
SILVER BULLET ► FLOW COMPOSED
Flows: ORIENT → BLAST-RADIUS → DEVOPS QG (pre-plan) → PLAN → EXECUTE → REVIEW → VERIFY → SECURE → VALIDATE → DEVOPS QG (pre-ship) → BRANCH-FINISH → COMPLETION-AUDIT → SHIP
Skipped: BOOTSTRAP — .planning/ exists; DESIGN/UI — infra
```

### 4. Autonomous composition (default)

Do **not** ask `Approve composition?`. Log: `SB ► devops composed {N} paths — orchestrator active`.
Workflow tracking is started by `flow-advance.sh`.

### 5. Legacy manual workflow start (fallback only)

Resolve the workflow helper, then run its start subcommand to register this composition as an active workflow.
The helper writes a per-instance file to `.planning/workflows/<id>.md` and returns the
workflow id. Capture it and export it as `SB_WORKFLOW_ID` so all child shells (including
`gh release create` / `gh pr create`) inherit it — completion-audit's strict gate uses
this to verify the active workflow is fully complete before final delivery.

```bash
# Build a comma-separated flow list from the confirmed composition (use the
# user-facing FLOW / PATH names so they match what compliance-status surfaces).
SB_FLOWS="<flow1>,<flow2>,..."   # filled in from the confirmed chain

if [[ -x scripts/workflows.sh ]]; then
  SB_WORKFLOWS_BIN="scripts/workflows.sh"
else
  SB_WORKFLOWS_BIN="$(
    for root in \
      "$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current" \
      "$HOME/.codex/plugins/cache/alo-labs/silver-bullet/current" \
      "$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet"/* \
      "$HOME/.codex/plugins/cache/alo-labs/silver-bullet"/*; do
      if [[ -x "$root/scripts/workflows.sh" ]]; then
        printf "%s\n" "$root/scripts/workflows.sh"
        break
      fi
    done
  )"
fi
if [[ -z "${SB_WORKFLOWS_BIN:-}" ]]; then
  echo "Silver Bullet workflow tracker not found. Run /silver:update or reinstall Silver Bullet, then retry." >&2
  exit 1
fi

SB_WORKFLOW_ID=$("$SB_WORKFLOWS_BIN" start /silver:devops "the user's original request" "$SB_FLOWS")
export SB_WORKFLOW_ID
echo "Workflow tracker started: $SB_WORKFLOW_ID"
```

After each flow / path completes, mark it done:

```bash
"$SB_WORKFLOWS_BIN" complete-flow "$SB_WORKFLOW_ID" "<flow-name>"
```

When the entire composition finishes (after the final SHIP / RELEASE flow lands), close
the workflow:

```bash
"$SB_WORKFLOWS_BIN" complete "$SB_WORKFLOW_ID"
```

`complete` archives the file under `.planning/workflows/.archive/<id>.md` and removes
it from the active set, so the strict final-delivery gate will not match a stale id.

> **Legacy:** the v0.22 single-file `.planning/WORKFLOW.md` mechanism is retired. The
> per-instance `.planning/workflows/<id>.md` files are the only workflow tracker as of
> v0.29.1.

After each path completes, the helper updates the Flow Log row in-place — the helper does
not edit the file directly.


## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §9b, commit both.

**Non-skippable gates:** `security` (Step 3b), `devops-quality-gates` pre-ship (Step 10), `silver:verify` (Step 9).

## Step 0: Codebase Intel

Invoke `silver:scan` through the active runtime's SB-recognized skill invocation channel. Purpose: orient in the codebase — understand current infra topology before silver:blast-radius analysis.

If no current codebase mapping exists and infra topology is non-trivial, run a deeper `silver:scan` pass focused on IaC, CI/CD, deployment, secrets, and rollback surfaces.

## Step 1: Blast Radius Analysis

Invoke `silver:blast-radius` through the active runtime's SB-recognized skill invocation channel. Purpose: map change scope, downstream dependencies, failure modes, and rollback plan. This step replaces the product/engineering brainstorm for devops workflows.

## Step 2: DevOps Skill Router

Invoke `devops-skill-router` through the active runtime's SB-recognized skill invocation channel. Purpose: route to the right IaC/cloud skill — Terraform, Pulumi, AWS CDK, k8s, or other tooling appropriate for the change.

## Step 3: Pre-Plan DevOps Quality Gates (7 IaC dimensions)

Invoke `devops-quality-gates` through the active runtime's SB-recognized skill invocation channel. Purpose: 7 IaC-adapted quality dimensions (reliability, security, scalability, modularity, testability, observability, change-safety) as the pre-plan gate.

Note: this is NOT the standard product `silver:quality-gates` sweep. The devops workflow uses `devops-quality-gates` exclusively at both quality gate positions.

Also invoke or apply `silver:domain-audit` with the affected DevOps packs:
`ci-workflow`, `environment-secrets`, `runtime-release`, `dependency-supply`,
and `performance-resource` as applicable. These packs provide specialized
evidence rows that feed into the DevOps gate result.

## Step 3b: Infrastructure Security (mandatory, non-skippable)

Invoke `security` through the active runtime's SB-recognized skill invocation channel. Purpose: infrastructure security hard gate — mandatory independent of §10 preferences. Checks secrets, IAM permissions, network exposure, and data handling.

## Step 4: Discuss Phase

Invoke `silver:context` through the active runtime's SB-recognized skill invocation channel. Purpose: DevOps phase context, assumptions, rollback expectations, and locked decisions for the planner.

## Step 5: Plan Phase

Invoke `silver:plan` through the active runtime's SB-recognized skill invocation channel. Purpose: PLAN.md for the infrastructure change, including validation, rollback, policy, and observability evidence.

## Step 5b: Pre-Build Validation

**NON-SKIPPABLE GATE.** (VALD-03 compliance)

This runs **after** Step 5 (Plan Phase) because `silver:validate` performs pre-build gap analysis against `.planning/PLAN.md`. `workflow-chain-guard` blocks implementation edits until this marker is recorded.

Invoke `silver:validate` through the active runtime's SB-recognized skill invocation channel.

If silver:validate reports any BLOCK findings:
- STOP. Do not proceed to Step 6 (Execute).
- Display: "Pre-build validation found BLOCK findings. Resolve them before continuing."
- Offer: A. Return to `silver:plan` to revise the plan  B. Re-run `silver:validate` after fixes

Only proceed to Step 6 (Execute Phase) when silver:validate reports zero BLOCK findings.

WARN findings are recorded in `.planning/VALIDATION.md` and will appear in the PR description (VALD-04).

## Step 6: Execute Phase (IaC validation, not app TDD)

If mode is Interactive: invoke `silver:execute` through the active runtime's SB-recognized skill invocation channel.
If mode is Autonomous (§10e): invoke `silver:execute` with autonomous mode context.

**Application TDD is explicitly skipped for pure infra plans.** Infrastructure and configuration work is declarative; use provider plan/dry-run, policy-as-code, security scans, drift checks, and rollback verification. Do not invoke `tdd` unless the DevOps phase includes behavior-changing application code.

## Step 7: Code Review (IaC review)

Run review sequence in order:
1. Invoke `silver:review-request` through the active runtime's SB-recognized skill invocation channel.
2. Invoke `silver:review` through the active runtime's SB-recognized skill invocation channel. If issues are found, fix through `silver:execute` and re-review.
3. For architecturally significant infra changes: invoke configured external second-opinion review only when available and explicitly selected; findings feed into REVIEW.md.
4. Invoke `silver:review-triage` through the active runtime's SB-recognized skill invocation channel.

> **Canonical post-execution order:** review (Step 7) → verify (Step 8) → secure (Step 9) → validate (Step 9b) → pre-ship quality gates (Step 10) → ship (Step 11). This sequence matches `silver:feature`, `silver:ui`, and `silver:bugfix`. Pre-plan infrastructure security remains mandatory at Step 3b; Step 9 is the retroactive secure sweep.

## Step 8: Deployment Verification

Invoke `silver:verify` through the active runtime's SB-recognized skill invocation channel. Purpose: deployment verification and UAT. Non-skippable gate.

**Fresh test execution (required before delivery):** Invoke `verify-tests` to run the project's gate (IaC validation / plan-check commands) and record the freshness marker — it is part of `required_deploy`, so the completion-audit deploy gate blocks deploy until a fresh run is recorded.

## Step 9: IaC Security + Secrets Verification

Invoke `silver:secure` through the active runtime's SB-recognized skill invocation channel. Purpose: IaC security and secrets verification — confirm no credentials in code, correct IAM boundaries, secure defaults.

## Step 9b: Validate Phase

Invoke `silver:validate` through the active runtime's SB-recognized skill invocation channel. Purpose: post-implementation validation gap filling and pre-ship consistency check.

### Deferred-Item Capture (mandatory)

During and after execution, any item that is skipped, descoped, out of scope, explicitly deferred, or identified for future work MUST be filed immediately via `/silver:add` — do not accumulate silently.

```
Skill(skill="silver:add", args="<description of deferred item>")
```

**Classification quick-reference:**
- Bug, regression, broken behavior, blocking question, unfinished work → files as **issue**
- Feature request, tech debt, advisory finding, informational question, housekeeping → files as **backlog**
- When ambiguous → files as **backlog** (do not over-alarm with issues)

**Minimum bar:** Only file items with distinct impact OR that block future work OR represent a conscious deferred decision. Do not file transient notes or items already addressed this session.

## Step 10: Pre-Ship DevOps Quality Gates (7 IaC dimensions)

Invoke `devops-quality-gates` through the active runtime's SB-recognized skill invocation channel again. Purpose: final 7-dimension sweep before deploy — same gate as Step 3, applied post-implementation. Non-skippable.

Re-run the affected `silver:domain-audit` DevOps packs when CI, environment,
deployment, rollback, secrets, or performance evidence changed during execution.
Unresolved `BLOCK` pack findings stop ship.

## Step 10b: Doc-Scheme Compliance (conditional)

**Only if `docs/doc-scheme.md` exists in the project:**

```bash
[ -f "docs/doc-scheme.md" ] && [ -f "docs/doc-scheme.json" ] && echo "Doc-scheme gate required" || echo "Doc scheme missing/incomplete — run /silver:ensure-docs --recover-scheme"
```

Before deploying, verify documentation is up to date per the scheme:

1. **`docs/CHANGELOG.md`** — must have an entry for the infrastructure change (newest-first). If missing, write it now.
2. **`docs/knowledge/YYYY-MM.md`** (current month) — append IaC patterns, provider quirks, and config gotchas encountered.
3. **`docs/learnings/YYYY-MM.md`** (current month) — append portable DevOps learnings.
4. Update any additional docs changed by the work (`ARCHITECTURE.md`, `TESTING.md`, runbooks, workflows, etc.) so content matches current behavior.
5. **`docs/task-doc-checklist.json`** — must include `task_granularity` and full status coverage for every key in `docs/doc-scheme.json -> required_docs`, plus any required section entries declared under `required_sections`.

**Gate:** Do NOT proceed to Step 11 until all checklist/doc checks pass. Missing checklist keys or stale `updated` claims are pre-ship defects.

If `docs/doc-scheme.md`/`docs/doc-scheme.json` are missing, recover via `/silver:ensure-docs --recover-scheme`, then complete this step before proceeding to Step 11.

## Step 11: Ship / Deploy

Invoke `silver:ship` through the active runtime's SB-recognized skill invocation channel. Purpose: push branch, deploy, create PR.

Before ship, invoke `silver:branch-finish` on feature branches and `silver:completion-audit` immediately before `silver:ship` (both are in `required_deploy_devops`).

**Reset enforcement profile:** After devops ship completes, restore application workflow gates:

```bash
if [[ -f .silver-bullet.json ]] && command -v jq >/dev/null 2>&1; then
  tmp="$(mktemp)"
  jq '.project.active_workflow = "full-dev-cycle"' .silver-bullet.json > "$tmp" && mv "$tmp" .silver-bullet.json
fi
```

If this workflow performs or prepares an environment rollout, invoke
`silver:deploy` before or inside ship according to the release plan. The deploy
artifact must record platform detection, command safety, artifact identity,
health checks, rollback readiness, and monitoring evidence.

If the rollout reaches a live runtime, invoke `silver:canary` after deployment
or record why canary evidence is unavailable. Runtime confidence requires live
or post-deploy evidence; green CI alone is insufficient.
