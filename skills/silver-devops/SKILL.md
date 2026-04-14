---
name: silver-devops
description: "SB-orchestrated infrastructure/CI-CD workflow: intel → blast-radius → devops-skill-router → devops-quality-gates (7 dims) → plan → execute (no TDD) → review → secure → ship"
argument-hint: "<infrastructure or CI/CD change description>"
---

# /silver:devops — Infrastructure, CI/CD, IaC, Cloud Workflow

SB orchestrator for infra, CI/CD, pipelines, Terraform, IaC, Kubernetes, containers, cloud, and ops work.

**Key design principles:**
- No brainstorming phase — infrastructure changes are driven by operational requirements established upstream (in silver:feature or silver:research). Blast-radius analysis replaces the product/engineering brainstorm.
- Uses silver:devops-quality-gates (7 IaC-adapted dimensions) instead of the standard 9-dimension sweep at BOTH pre-plan and pre-ship gates.
- TDD is not applicable for infra plans — explicitly skipped.

**The 7 IaC quality dimensions:** reliability, security, scalability, modularity, testability, observability, change-safety. (Usability omitted — no user-facing interface in IaC. Extensibility omitted — IaC is declarative, not extensible.)

Never implements infra changes directly — orchestrates only.

## Pre-flight: Load Preferences

Read `silver-bullet.md §10` to load user workflow preferences before any other step.

```bash
grep -A 50 "^## 10\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► DEVOPS WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Change: {$ARGUMENTS or "(not specified)"}
Mode:   {interactive | autonomous — from §10e or session selection}
```

## Composition Proposal

Before beginning execution, read existing artifacts to determine context and propose which PATHs to include or skip.

### 1. Context Scan

Check the following artifacts and set skip/include flags:

| Artifact | Signal | Action |
|----------|--------|--------|
| `.planning/` directory exists | Project already bootstrapped | Skip PATH 0 (BOOTSTRAP) |
| `.planning/STATE.md` exists | GSD state present | Skip PATH 0 (BOOTSTRAP) |

```bash
# Check for existing planning artifacts
[ -d ".planning" ] && echo "SKIP PATH 0 — .planning/ exists" || echo "Include PATH 0"
```

Note: PATH 6 (DESIGN CONTRACT) and PATH 8 (UI QUALITY) are never included in the devops workflow — infra has no user-facing interface.

### 2. Build Path Chain

Construct the proposed path chain for infrastructure/CI-CD work. Default chain:

PATH 0 (BOOTSTRAP) [skip if .planning/ exists] → PATH 1 (ORIENT) → PATH 5 (PLAN) → PATH 7 (EXECUTE) → PATH 10 (SECURE) [always included — infra work] → PATH 11 (VERIFY) → PATH 13 (SHIP)

Note: PATH 10 (SECURE) is always included for any infrastructure engagement. PATH 6 (DESIGN CONTRACT) and PATH 8 (UI QUALITY) are never included.

### 3. Display Proposal

Display the composition proposal to the user:

```
┌─ COMPOSITION PROPOSAL ─────────────────────────
│ Paths: PATH 1 (ORIENT) → PATH 5 (PLAN) → PATH 7 (EXECUTE) → PATH 10 (SECURE) → PATH 11 (VERIFY) → PATH 13 (SHIP)
│ Skipped: PATH 0 (BOOTSTRAP) — .planning/ exists; PATH 6/8 — no UI in infra workflow
└────────────────────────────────────────────────
Approve composition? [Y/n]
```

### 4. Auto-Confirm in Autonomous Mode

In autonomous mode (§10e), auto-confirm the composition proposal with a log message:

```
⚡ Autonomous mode: auto-confirming composition — {path count} paths, {skipped count} skipped
```

### 5. Create WORKFLOW.md

If `.planning/WORKFLOW.md` does not exist, create it from `templates/workflow.md.base`:
- Populate `Intent:` with the infrastructure change description ($ARGUMENTS)
- Populate `Composed:` with the current ISO timestamp
- Populate `Composer:` with `/silver:devops`
- Populate `Mode:` with the current mode (interactive or autonomous)
- Record the confirmed path chain in the Path Log section header

After each path completes, write status to Path Log table:

```
| {#} | PATH {N} ({name}) | complete | {artifacts produced} | ✓ |
```

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §10b, commit both.

**Non-skippable gates:** `silver:security` (Step 3b), `silver:devops-quality-gates` pre-ship (Step 10), `gsd-verify-work` (Step 9).

## Step 0: Codebase Intel

Invoke `silver:intel` (gsd-intel) via the Skill tool. Purpose: orient in the codebase — understand current infra topology before blast-radius analysis.

If no intel files exist: invoke `silver:scan` (gsd-scan) via the Skill tool for rapid structure assessment.

## Step 1: Blast Radius Analysis

Invoke `silver:blast-radius` via the Skill tool. Purpose: map change scope, downstream dependencies, failure modes, and rollback plan. This step replaces the product/engineering brainstorm for devops workflows.

## Step 2: DevOps Skill Router

Invoke `silver:devops-skill-router` via the Skill tool. Purpose: route to the right IaC/cloud skill — Terraform, Pulumi, AWS CDK, k8s, or other tooling appropriate for the change.

## Step 3: Pre-Plan DevOps Quality Gates (7 IaC dimensions)

Invoke `silver:devops-quality-gates` via the Skill tool. Purpose: 7 IaC-adapted quality dimensions (reliability, security, scalability, modularity, testability, observability, change-safety) as the pre-plan gate.

Note: this is NOT the standard 9-dimension silver:quality-gates. The devops workflow uses silver:devops-quality-gates exclusively at both quality gate positions.

## Step 3b: Infrastructure Security (mandatory, non-skippable)

Invoke `silver:security` via the Skill tool. Purpose: infrastructure security hard gate — mandatory independent of §10 preferences. Checks secrets, IAM permissions, network exposure, and data handling.

## Step 4: Discuss Phase

Invoke `gsd-discuss-phase` via the Skill tool. Purpose: DevOps phase context → CONTEXT.md with locked decisions for the planner.

## Step 5: Plan Phase

Invoke `gsd-plan-phase` via the Skill tool. Purpose: PLAN.md for the infrastructure change.

## Step 6: Execute Phase (TDD skipped)

If mode is Interactive: invoke `gsd-execute-phase` via the Skill tool.
If mode is Autonomous (§10e): invoke `gsd-autonomous` via the Skill tool.

**TDD is explicitly skipped for infra plans — not applicable.** Infrastructure and configuration work is declarative; there is no red-green-refactor cycle that applies to IaC resources. No silver:tdd invocation.

## Step 7: Code Review (IaC review)

Run review sequence in order:
1. Invoke `silver:request-review` (superpowers:requesting-code-review) via the Skill tool.
2. Invoke `gsd-code-review` via the Skill tool. If issues found: invoke `gsd-code-review-fix`.
3. For architecturally significant infra changes: invoke `gsd-review --multi-ai` via the Skill tool.
4. Invoke `silver:receive-review` (superpowers:receiving-code-review) via the Skill tool.

## Step 8: IaC Security + Secrets Verification

Invoke `gsd-secure-phase` via the Skill tool. Purpose: IaC security and secrets verification — confirm no credentials in code, correct IAM boundaries, secure defaults.

## Step 9: Deployment Verification

Invoke `gsd-verify-work` via the Skill tool. Purpose: deployment verification and UAT. Non-skippable gate.

## Step 10: Pre-Ship DevOps Quality Gates (7 IaC dimensions)

Invoke `silver:devops-quality-gates` via the Skill tool again. Purpose: final 7-dimension sweep before deploy — same gate as Step 3, applied post-implementation. Non-skippable.

## Step 11: Ship / Deploy

Invoke `gsd-ship` via the Skill tool. Purpose: push branch, deploy, create PR.
