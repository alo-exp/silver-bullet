---
name: silver-feature
description: "Full SB-orchestrated feature development workflow: intel → product-brainstorm → brainstorm → quality-gates → GSD plan/execute/verify → ship"
argument-hint: "<feature description>"
---

# /silver:feature — Feature Development Workflow

SB orchestrator for new feature development. Chains GSD (execution backbone), Superpowers (craft discipline), MultAI (multi-AI intelligence), and SB quality gates in the sequence defined in silver-bullet.md §2h.

Never implements features directly — orchestrates only.

## Pre-flight: Load Preferences

Read `silver-bullet.md §10` to load user workflow preferences before any other step. Silently apply any stored routing, skip, tool, MultAI, or mode preferences throughout this workflow.

```bash
grep -A 50 "^## 10\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► FEATURE WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Feature: {$ARGUMENTS or "(not specified)"}
Mode:    {interactive | autonomous — from §10e or session selection}
```

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §10b, then commit both files.

**Non-skippable gates:** `silver:security`, `silver:quality-gates` pre-ship, `gsd-verify-work`. Refuse skip requests for these regardless of §10.

## Step 0: Complexity Triage

Before proceeding, classify the request:

| Classification | Signals | Action |
|----------------|---------|--------|
| Trivial | ≤3 files, typo, config, rename | STOP — route to `silver:fast` instead |
| Fuzzy | Vague intent, unclear scope | Continue to Step 1b (silver:explore) |
| Simple | Clear scope, ≤1 phase | Skip Step 1b, go to Step 1a |
| Complex | Multi-phase, cross-cutting | Full workflow including Step 1b |

If trivial: invoke `silver:fast` via the Skill tool and exit this workflow.

## Step 1a: Codebase Intel

Invoke `silver:intel` (gsd-intel) via the Skill tool to orient planning in the codebase.

If no intel files exist and this is a brownfield project, also invoke `silver:scan` (gsd-scan) via the Skill tool for rapid structure assessment.

## Step 1b: Fuzzy Scope Clarification (conditional)

**Only if complexity triage found fuzzy intent or $ARGUMENTS is empty:**

Invoke `silver:explore` (gsd-explore) via the Skill tool for Socratic clarification before structured brainstorming.

## Step 1c: Brainstorm

Run both brainstorm tools in sequence:

**1c-i: Product brainstorming**
Invoke `/product-brainstorming` via the Skill tool. Purpose: PM lens — problem definition, user value, personas, success metrics, scope boundaries.

**1c-ii: Engineering brainstorm**
Invoke `silver:brainstorm` (superpowers:brainstorming) via the Skill tool. Purpose: engineering lens — architecture, approaches, spec, design doc, spec-review loop.

## Step 1d: MultAI Pre-Spec Review (conditional)

**Trigger condition:** Architecture-significant change OR user requested OR any of these auto-trigger signals apply:
- Choosing between 2+ fundamentally different architectures
- Selecting a technology stack from scratch
- Domain is novel (no prior intel in .planning/)
- Change affects public API or data model fundamentally

If condition met, ask:

> This appears to be an architecturally significant change. Would you like 7-AI perspectives on the architecture/approach before locking the spec?
>
> A. Yes — run MultAI pre-spec review (multai:orchestrator)
> B. No — proceed with spec as-is

If A: invoke `silver:multai` (multai:orchestrator) via the Skill tool. Note: this step informs the spec PRE-implementation. Step 9c (gsd-review --multi-ai) reviews completed code POST-execution. Both are independent.

## Step 2: Testing Strategy

Invoke `/testing-strategy` via the Skill tool. Purpose: define test levels, tooling, coverage targets — MUST run after spec approval and before writing-plans so test requirements are baked into the implementation plan.

## Step 2.5: Writing Plans

Invoke `silver:writing-plans` (superpowers:writing-plans) via the Skill tool. Purpose: convert approved spec + test strategy → structured implementation plan.

## Step 2.7: Pre-Build Validation

**NON-SKIPPABLE GATE.** (VALD-03 compliance)

Invoke `silver:validate` via the Skill tool.

If silver-validate reports any BLOCK findings:
- STOP. Do not proceed to Step 3.
- Display: "Pre-build validation found BLOCK findings. Resolve them before continuing."
- Offer: A. Return to /silver:spec  B. Re-run /silver:validate after fixes

Only proceed to Step 3 (quality-gates) when silver-validate reports zero BLOCK findings.

WARN findings are recorded in .planning/VALIDATION.md and will appear in the PR description (VALD-04).

## PATH 12 (pre-plan): QUALITY GATE — Design-time checklist

**Mode:** design-time checklist (PLAN.md does NOT yet exist)

### Prerequisite Check

CONTEXT.md must exist. If not, STOP and run PATH 5 (PLAN) first.

```bash
ls .planning/phases/*/CONTEXT.md 2>/dev/null || echo "MISSING: CONTEXT.md — run PATH 5 first"
```

### Steps

1. `quality-gates` — 9 dimensions (Always — standard projects) OR `devops-quality-gates` — 7 dimensions (As-needed — IaC/infra-touching changes)
2. Individual dimension deep-dive (As-needed — specific dimension failure)

**Non-skippable gate.** `silver:security` is always mandatory regardless of §10 preferences. All dimensions must pass before proceeding to PATH 6 or PATH 7.

### Exit Condition

All quality gate dimensions pass in design-time checklist mode.

## Step 4: Discuss Phase

Invoke `gsd-discuss-phase` via the Skill tool. Purpose: adaptive questioning → CONTEXT.md with locked decisions for the planner.

## Step 5: Analyze Dependencies

Invoke `gsd-analyze-dependencies` via the Skill tool. Purpose: map phase dependencies before GSD creates the plan.

## Step 6: Plan Phase

Invoke `gsd-plan-phase` via the Skill tool. Purpose: PLAN.md with verification loop.

## Step 7: Execute Phase

**If mode is Interactive (default):** invoke `gsd-execute-phase` via the Skill tool.
**If mode is Autonomous (§10e):** invoke `gsd-autonomous` via the Skill tool.

**Error path:** If execution fails mid-wave, do NOT mark the phase complete. Insert PATH 14 (DEBUG) dynamically. Return to PATH 7 only after PATH 14 confirms the root cause is resolved and fix plan validated.

## Step 7a: TDD Gate (implementation plans only)

**Only for implementation plans — skip for config/infra/doc plans:**
Heuristic: if the PLAN.md modifies source files containing business logic or application code, it is an implementation plan. Config-only, docs-only, or infra-only plans skip this step.

Invoke `silver:tdd` (superpowers:test-driven-development) via the Skill tool. Purpose: TDD red-green-refactor discipline per implementation task.

## Step 8: Verify Work

Invoke `gsd-verify-work` via the Skill tool. Purpose: UAT, must-haves, artifact checks. Phase is NOT complete until this passes. Non-skippable.

## Step 8b: Test Gap Fill (conditional)

**Only if gsd-verify-work surfaces coverage gaps:**

Invoke `gsd-add-tests` via the Skill tool. Purpose: generate tests from UAT criteria to fill gaps identified by verification — runs after gsd-verify-work so gap targets are known.

## PATH 9: REVIEW — Three-layer code review cycle

### Prerequisite Check

PATH 7 (EXECUTE) completed: SUMMARY.md must exist for all plans in this phase. If not, STOP and complete PATH 7 first.

```bash
ls .planning/phases/*-SUMMARY.md 2>/dev/null || echo "MISSING: SUMMARY.md — complete PATH 7 first"
```

### Steps

Run all three layers. Each layer runs independently:

**Layer A: Automated review**
1. `gsd-code-review` (Always — spawn reviewer agents → REVIEW.md)
2. `superpowers:receiving-code-review` (Always — disciplined response to findings)
3. `gsd-code-review-fix` (Always — auto-fix findings atomically)

**Layer B: Re-review**
1. `superpowers:requesting-code-review` (Always — frame review scope rigorously)
2. `superpowers:receiving-code-review` (Always — disciplined response)
3. `gsd-code-review-fix` (Always — fix findings)

**Layer C: Engineering review**
1. `engineering:code-review` (Always — engineering lens)
2. `superpowers:receiving-code-review` (Always — disciplined response)
3. `gsd-code-review-fix` (Always — fix findings)

**Layer D: Cross-AI review (As-needed — architecturally significant changes or user request)**
1. `gsd-review --multi-ai` (As-needed — cross-AI adversarial peer review of completed code; distinct from PATH 3 pre-spec MultAI)
2. `superpowers:receiving-code-review` (As-needed)
3. `gsd-code-review-fix` (As-needed)

### Review Cycle

After all layers complete, the entire cycle iterates until **2 consecutive clean passes across all layers**.

### Exit Condition

2 consecutive clean passes across all layers. REVIEW.md produced.

---

## PATH 10: SECURE — Security verification

### Prerequisite Check

PATH 9 completed: REVIEW.md must exist with 2 consecutive clean passes. If not, STOP and complete PATH 9 first.

```bash
ls REVIEW.md 2>/dev/null || echo "MISSING: REVIEW.md — complete PATH 9 first"
```

### Steps

1. `security/SENTINEL` (As-needed — software is a Claude/AI plugin or skill)
2. `gsd-secure-phase` (Always — retroactive threat mitigation verification)
3. `gsd-validate-phase` (Always — Nyquist validation gap filling)
4. `ai-llm-safety` (As-needed — LLM agents/prompts/AI content)

### Review Cycle

2 consecutive clean passes before this path is complete.

### Exit Condition

Security findings resolved (2 consecutive clean passes). SECURITY.md produced. Validation gaps filled.

## PATH 12 (pre-ship): QUALITY GATE — Adversarial audit

**Mode:** adversarial audit (PATH 11 VERIFY completed)

**4-state disambiguation:**
- PLAN.md does NOT exist → design-time checklist mode (see PATH 12 pre-plan above)
- PATH 11 completed (VERIFICATION.md with status: passed) → adversarial audit mode (this section)

### Prerequisite Check

PATH 11 completed: VERIFICATION.md must exist with `status: passed`. If not, STOP and complete PATH 11 first.

```bash
grep "status: passed" VERIFICATION.md 2>/dev/null || echo "MISSING: PATH 11 not complete — VERIFICATION.md required"
```

### Steps

1. `quality-gates` — 9 dimensions (Always — standard projects) OR `devops-quality-gates` — 7 dimensions (As-needed — IaC/infra-touching changes)
2. Individual dimension deep-dive (As-needed — specific dimension failure)

**Non-skippable gate.** All dimensions must pass before proceeding to PATH 13 (SHIP). Gate itself is the review — no separate review cycle.

### Exit Condition

All quality gate dimensions pass in adversarial audit mode.

---

## PATH 13: SHIP — Push branch and create PR

### Prerequisite Check

PATH 12 pre-ship passed, PATH 11 completed (VERIFICATION.md with status: passed), clean git tree, on feature branch. If not, STOP and complete prerequisites first.

### Steps

1. `superpowers:finishing-a-development-branch` (Always — merge / PR / cleanup decision)
2. `gsd-pr-branch` (As-needed — user requests clean PR branch stripping .planning/ commits)
3. `gsd-ship` (Always — push branch, create PR, prepare for merge; phase-level, not milestone-level)

### Exit Condition

PR created, CI green.

---

## PATH 14: DEBUG — Dynamic insertion on failure

> **DYNAMIC INSERTION PATH** — Not part of normal sequence. Inserted at any point when execution fails.

### Prerequisite Check

None — inserted on failure at any point in the workflow.

**Trigger:** execution failure, CI red, verification failure, unknown error.

### Steps

1. `superpowers:systematic-debugging` (Always — structured root cause analysis)
2. `gsd-debug` (Always — GSD-assisted debugging)
3. `engineering:debug` (As-needed — deeper engineering analysis)
4. `forensics` (As-needed — unknown root cause)
5. `gsd-forensics` (As-needed — failed GSD workflow)
6. `engineering:incident-response` (As-needed — production incident)

### Resume Semantics

After PATH 14 completes, execution resumes from the interrupted path. Fix plan must be validated before re-entering the interrupted path. Fixes route through `gsd-execute-phase --gaps-only`.

### Exit Condition

Root cause identified, fix plan validated. Return to interrupted path.

---

## PATH 16: DOCUMENT — Post-ship documentation

### Prerequisite Check

PATH 13 completed: PR created and CI green. If not, STOP and complete PATH 13 first.

### Steps

1. `gsd-docs-update` (Always — verify and update docs/)
2. `engineering:documentation` (Always — documentation quality review)
3. `engineering:tech-debt` (Always — record tech debt discovered during phase)
4. `gsd-milestone-summary` (As-needed — milestone narrative when all phases shipped)
5. `episodic-memory:remembering-conversations` (Always — record key decisions and lessons)
6. `gsd-session-report` (As-needed — session report when relevant)

### Exit Condition

docs/ updated, session log completed.

---

## PATH 17: RELEASE — Milestone completion

### Prerequisite Check

All phases shipped (PATH 13 completed for every phase in milestone). Trigger: user signals milestone complete, or last phase shipped.

```bash
# Confirm all phases have PRs / are shipped before proceeding
```

### Steps

1. `gsd-audit-uat` (Always — UAT audit across all phases)
2. `gsd-audit-milestone` (Always — milestone completeness audit)
3. `PATH 15 DESIGN HANDOFF` (As-needed — if milestone has UI phases, inserted here between steps 2 and 4)
4. `gsd-plan-milestone-gaps` (As-needed — gaps found in audit; gap closure is Claude-suggested, user-decided depth)
5. `create-release` (Always — create GitHub Release)
6. `gsd-complete-milestone` (Always — archive .planning/, reset STATE.md)

### Review Cycle

Cross-artifact review → artifact-review-assessor → fix → pass (runs before create-release). Gap closure: Claude-suggested, user-decided depth.

### Exit Condition

GitHub Release created, milestone archived.

> **Note:** PATH 17 also exists in silver-release/SKILL.md (primary location for standalone release flows). This silver-feature version handles milestone completion at the end of the feature workflow.
