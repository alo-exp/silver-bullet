---
name: silver:devops
title: Silver: /silver:devops - DevOps
description: >
  This skill should be used for SB-orchestrated infrastructure/CI-CD workflow: intel → silver:blast-radius → devops-skill-router → devops-quality-gates (7 IaC dims) → GSD plan/execute/verify → review → secure → ship
argument-hint: "<infrastructure or CI/CD change description>"
version: 0.1.0
---

# /silver:devops — Infrastructure, CI/CD, IaC, Cloud Workflow

SB Agentic Process Orchestrator for infra, CI/CD, pipelines, Terraform, IaC, Kubernetes, containers, cloud, and ops work. GSD remains the lifecycle authority for phase planning, execution, verification, and ship.

**Key design principles:**
- No brainstorming phase — infrastructure changes are driven by operational requirements established upstream (in silver:feature or silver:research). Blast-radius analysis replaces the product/engineering brainstorm.
- Uses `devops-quality-gates` (7 IaC-adapted dimensions) instead of the standard product quality sweep at BOTH pre-plan and pre-ship gates.
- Application TDD is not applicable to pure infra plans; IaC uses plan, dry-run, policy, security, drift, and rollback validation instead.

**The 7 IaC quality dimensions:** reliability, security, scalability, modularity, testability, observability, change-safety. (Usability omitted because infra has no direct user interface; reusability/extensibility are covered by modularity/change-safety in IaC.)

Never implements infra changes directly — orchestrates only.

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

## Composition Proposal

Before beginning execution, read existing artifacts to determine context and propose which flows to include or skip.

### 1. Context Scan

Check the following artifacts and set skip/include flags:

| Artifact | Signal | Action |
|----------|--------|--------|
| `.planning/` directory exists | Project already bootstrapped | Skip FLOW 0 (BOOTSTRAP) |
| `.planning/STATE.md` exists | GSD state present | Skip FLOW 0 (BOOTSTRAP) |

```bash
# Check for existing planning artifacts
[ -d ".planning" ] && echo "SKIP FLOW 0 — .planning/ exists" || echo "Include FLOW 0"
```

Note: FLOW 6 (DESIGN CONTRACT) and FLOW 8 (UI QUALITY) are never included in the devops workflow — infra has no user-facing interface.

### 2. Build Flow Chain

Construct the proposed flow chain for infrastructure/CI-CD work. Default chain:

FLOW 0 (BOOTSTRAP) [skip if .planning/ exists] → FLOW 1 (ORIENT) → FLOW 2 (CLARIFY) [if scope unclear] → FLOW 3 (DECIDE) [if IaC/tooling choice needed] → FLOW 12 (QUALITY GATE, pre-plan, DevOps dimensions) → FLOW 5 (PLAN) → FLOW 7 (EXECUTE) → FLOW 9 (REVIEW) → FLOW 10 (SECURE) [always included — infra work] → FLOW 11 (VERIFY) → FLOW 12 (QUALITY GATE, pre-ship, DevOps dimensions) → FLOW 13 (SHIP)

Note: FLOW 10 (SECURE) is always included for any infrastructure engagement. FLOW 6 (DESIGN CONTRACT) and FLOW 8 (UI QUALITY) are never included.

### 3. Display Proposal

Display the composition proposal to the user:

```
SILVER BULLET ► FLOW COMPOSED
Flows: ORIENT → PLAN → EXECUTE → SECURE → VERIFY → SHIP
Skipped: BOOTSTRAP — .planning/ exists; DESIGN/UI — infra
Approve composition? [Y/n]
```

### 4. Auto-Confirm in Autonomous Mode

In autonomous mode (§10e), auto-confirm the composition proposal with a log message:

```
⚡ Autonomous mode: auto-confirming composition — {path count} paths, {skipped count} skipped
```

### 5. Start workflow tracking (Pass 2 — workflows.sh)

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
      "~/.codex/plugins/cache/alo-labs/silver-bullet/current" \
      "$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet"/* \
      "~/.codex/plugins/cache/alo-labs/silver-bullet"/*; do
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

**Non-skippable gates:** `security` (Step 3b), `devops-quality-gates` pre-ship (Step 10), `gsd-verify-work` (Step 9).

## Step 0: Codebase Intel

Invoke `gsd-scan` via the Skill tool. Purpose: orient in the codebase — understand current infra topology before silver:blast-radius analysis.

If no current codebase mapping exists and infra topology is non-trivial, invoke `gsd-map-codebase` via the Skill tool.

## Step 1: Blast Radius Analysis

Invoke `silver:blast-radius` via the Skill tool. Purpose: map change scope, downstream dependencies, failure modes, and rollback plan. This step replaces the product/engineering brainstorm for devops workflows.

## Step 2: DevOps Skill Router

Invoke `devops-skill-router` via the Skill tool. Purpose: route to the right IaC/cloud skill — Terraform, Pulumi, AWS CDK, k8s, or other tooling appropriate for the change.

## Step 3: Pre-Plan DevOps Quality Gates (7 IaC dimensions)

Invoke `devops-quality-gates` via the Skill tool. Purpose: 7 IaC-adapted quality dimensions (reliability, security, scalability, modularity, testability, observability, change-safety) as the pre-plan gate.

Note: this is NOT the standard product `silver:quality-gates` sweep. The devops workflow uses `devops-quality-gates` exclusively at both quality gate positions.

## Step 3b: Infrastructure Security (mandatory, non-skippable)

Invoke `security` via the Skill tool. Purpose: infrastructure security hard gate — mandatory independent of §10 preferences. Checks secrets, IAM permissions, network exposure, and data handling.

## Step 4: Discuss Phase

Invoke `gsd-discuss-phase` via the Skill tool. Purpose: DevOps phase context → CONTEXT.md with locked decisions for the planner.

## Step 5: Plan Phase

Invoke `gsd-plan-phase` via the Skill tool. Purpose: PLAN.md for the infrastructure change.

## Step 6: Execute Phase (IaC validation, not app TDD)

If mode is Interactive: invoke `gsd-execute-phase` via the Skill tool.
If mode is Autonomous (§10e): invoke `gsd-autonomous` via the Skill tool.

**Application TDD is explicitly skipped for pure infra plans.** Infrastructure and configuration work is declarative; use provider plan/dry-run, policy-as-code, security scans, drift checks, and rollback verification. Do not invoke `tdd` unless the DevOps phase includes behavior-changing application code.

## Step 7: Code Review (IaC review)

Run review sequence in order:
1. Invoke `requesting-code-review` (superpowers:requesting-code-review) via the Skill tool.
2. Invoke `gsd-code-review` via the Skill tool. If issues found: invoke `gsd-code-review-fix`.
3. For architecturally significant infra changes: invoke `gsd-review --all` via the Skill tool (fans out to all available external CLIs for cross-AI review).
4. Invoke `receiving-code-review` (superpowers:receiving-code-review) via the Skill tool.

## Step 8: IaC Security + Secrets Verification

Invoke `gsd-secure-phase` via the Skill tool. Purpose: IaC security and secrets verification — confirm no credentials in code, correct IAM boundaries, secure defaults.

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

## Step 9: Deployment Verification

Invoke `gsd-verify-work` via the Skill tool. Purpose: deployment verification and UAT. Non-skippable gate.

## Step 10: Pre-Ship DevOps Quality Gates (7 IaC dimensions)

Invoke `devops-quality-gates` via the Skill tool again. Purpose: final 7-dimension sweep before deploy — same gate as Step 3, applied post-implementation. Non-skippable.

## Step 10b: Doc-Scheme Compliance (conditional)

**Only if `docs/doc-scheme.md` exists in the project:**

```bash
[ -f "docs/doc-scheme.md" ] && [ -f "docs/doc-scheme.json" ] && echo "Doc-scheme gate required" || echo "Doc scheme missing/incomplete — run /silver:ensure-docs --recover-scheme"
```

Before deploying, verify documentation is up to date per the scheme:

1. **`docs/CHANGELOG.md`** — must have an entry for the infrastructure change (newest-first). If missing, write it now.
2. **`docs/knowledge/YYYY-MM.md`** (current month) — append IaC patterns, provider quirks, and config gotchas encountered.
3. **`docs/lessons/YYYY-MM.md`** (current month) — append portable DevOps lessons learned.
4. Update any additional docs changed by the work (`ARCHITECTURE.md`, `TESTING.md`, runbooks, workflows, etc.) so content matches current behavior.
5. **`docs/task-doc-checklist.json`** — must include `task_granularity` and full status coverage for every key in `docs/doc-scheme.json -> required_docs`, plus any required section entries declared under `required_sections`.

**Gate:** Do NOT proceed to Step 11 until all checklist/doc checks pass. Missing checklist keys or stale `updated` claims are pre-ship defects.

If `docs/doc-scheme.md`/`docs/doc-scheme.json` are missing, recover via `/silver:ensure-docs --recover-scheme`, then complete this step before proceeding to Step 11.

## Step 11: Ship / Deploy

Invoke `gsd-ship` via the Skill tool. Purpose: push branch, deploy, create PR.
