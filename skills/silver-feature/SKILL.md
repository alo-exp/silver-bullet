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
| Fuzzy | Vague intent, unclear scope | Continue to PATH 2 exploration steps |
| Simple | Clear scope, ≤1 phase | Skip exploration, go to PATH 1 |
| Complex | Multi-phase, cross-cutting | Full workflow including exploration |

If trivial: invoke `silver:fast` via the Skill tool and exit this workflow.

---

## PATH 0: BOOTSTRAP — Project/milestone lifecycle

### Prerequisite Check

None — entry point. Run this path when no `.planning/` exists, a prior milestone is complete, or the user signals a new project or milestone.

### Steps

1. `episodic-memory:remembering-conversations` (Always — recall prior context before any new work)
2. `gsd-new-project` (As-needed — no `.planning/` exists)
3. `gsd-map-codebase` (As-needed — brownfield project, no `.planning/` yet)
4. `gsd-new-milestone` (As-needed — prior milestone complete)
5. `gsd-resume-work` (As-needed — continuing a prior session)
6. `gsd-progress` (As-needed — check current project state)

Invoke each applicable step via the Skill tool.

### Review Cycle

ROADMAP.md and REQUIREMENTS.md through artifact-review-assessor per the Reviewer → Assessor → fix MUST-FIX → Reviewer cycle until 2 consecutive clean passes:

- `ROADMAP.md` → invoke `/artifact-reviewer .planning/ROADMAP.md --reviewer review-roadmap` via the Skill tool
- `REQUIREMENTS.md` → invoke `/artifact-reviewer .planning/REQUIREMENTS.md --reviewer review-requirements` via the Skill tool

### Exit Condition

STATE.md exists with valid Current Position.

Verify: `grep -c "Current Position" .planning/STATE.md` returns 1.

---

## PATH 1: ORIENT — Codebase awareness

### Prerequisite Check

PATH 0 completed: `.planning/STATE.md` must exist. If not, STOP and run PATH 0 first.

### Steps

1. `gsd-intel` (Always — orient planning in the codebase)
2. `gsd-scan` (As-needed — brownfield project with no intel files)
3. `gsd-map-codebase` (As-needed — first time, deep structural analysis needed)

Invoke each applicable step via the Skill tool.

### Exit Condition

Intel files exist in `.planning/intel/` OR scan complete.

---

## PATH 2: EXPLORE — Problem space understanding

### Prerequisite Check

PATH 1 completed: intel files must exist in `.planning/intel/` OR scan complete. If not, STOP and run PATH 1 first.

```bash
ls .planning/intel/ 2>/dev/null | grep -q . || echo "STOP: Intel files missing — run PATH 1 first"
```

**Trigger note:** Activated when complexity triage (Step 0) classifies work as fuzzy or complex. Skipped for simple work.

### Steps

1. `gsd-explore` (Always)
2. `product-management:product-brainstorming` (Always)
3. `design:user-research` (As-needed — user-facing work)
4. `product-management:synthesize-research` (As-needed — prior research exists)
5. `product-management:competitive-brief` (As-needed — competitive landscape relevant)

Invoke each applicable step via the Skill tool.

### Exit Condition

Problem space clarified, scope boundaries established.

---

## PATH 3: IDEATE — Convergent ideation + structural shaping

### Prerequisite Check

PATH 2 completed. If not, STOP and run PATH 2 first.

**Skip condition:** Skipped for simple/clear-scope work (same classification as Step 0 "simple").

### Steps

1. `superpowers:brainstorming` (Always)
2. `engineering:architecture` (As-needed — new service, cross-cutting concern, ADR-worthy)
3. `engineering:system-design` (As-needed — new service boundary, major component)
4. `design:design-system` (As-needed — UI phase, new component type)

Invoke each applicable step via the Skill tool.

**Conditional sub-step: MultAI Pre-Spec Review**

After step 4, evaluate the trigger condition:
- Choosing between 2+ fundamentally different architectures
- Selecting a technology stack from scratch
- Domain is novel (no prior intel in .planning/)
- Change affects public API or data model fundamentally
- User requested OR architecture-significant change

If any trigger applies, ask:

> This appears to be an architecturally significant change. Would you like 7-AI perspectives on the architecture/approach before locking the spec?
>
> A. Yes — run MultAI pre-spec review (multai:orchestrator)
> B. No — proceed with spec as-is

If A: invoke `silver:multai` (multai:orchestrator) via the Skill tool. Note: this step informs the spec PRE-implementation. Step 9c (gsd-review --multi-ai) reviews completed code POST-execution. Both are independent.

### Exit Condition

Architectural direction chosen, design approach locked.

---

## PATH 4: SPECIFY — Requirements convergence

### Prerequisite Check

PATH 3 completed OR user has external spec to ingest. If neither, STOP.

**Skip condition:** May be skipped ONLY when REQUIREMENTS.md already exists (from PATH 0). If REQUIREMENTS.md does not exist and PATH 4 is excluded, the composer MUST insert it.

```bash
[ -f ".planning/REQUIREMENTS.md" ] && echo "REQUIREMENTS.md exists — PATH 4 may be skipped" || echo "REQUIREMENTS.md missing — PATH 4 is required"
```

### Steps

1. `silver-ingest` (As-needed — JIRA/Figma/Google Docs)
2. `product-management:write-spec` (As-needed — scaffold)
3. `silver-spec` (Always — Socratic elicitation)
4. `silver-validate` (Always — gap analysis)

Invoke each applicable step via the Skill tool.

If `silver-validate` reports any BLOCK findings: STOP, do not proceed. Display: "Pre-build validation found BLOCK findings. Resolve them before continuing." Offer: A. Return to silver-spec  B. Re-run silver-validate after fixes.

### Review Cycle

Artifact review through artifact-review-assessor per the Reviewer → Assessor → fix MUST-FIX → Reviewer cycle until 2 consecutive clean passes:

- `SPEC.md` → invoke `/artifact-reviewer .planning/SPEC.md --reviewer review-spec` via the Skill tool
- `REQUIREMENTS.md` → invoke `/artifact-reviewer .planning/REQUIREMENTS.md --reviewer review-requirements` via the Skill tool
- `DESIGN.md` → invoke `/artifact-reviewer .planning/DESIGN.md --reviewer review-design` via the Skill tool (if it exists)
- `INGESTION_MANIFEST.md` → invoke `/artifact-reviewer --reviewer review-ingestion-manifest` via the Skill tool (if ingest was run)

### Exit Condition

SPEC.md + REQUIREMENTS.md exist, silver-validate shows zero BLOCK findings.

---

## PATH 5: PLAN — Execution planning

### Prerequisite Check

All three must exist. Check each and STOP with a specific message if missing:

```bash
[ -f ".planning/ROADMAP.md" ]       || echo "STOP: ROADMAP.md missing — run PATH 0 first"
[ -f ".planning/REQUIREMENTS.md" ]  || echo "STOP: REQUIREMENTS.md missing — run PATH 0 first"
ls .planning/phases/ 2>/dev/null | grep -q . || echo "STOP: phase directory missing — run gsd-new-milestone first"
```

### Steps

1. `gsd-discuss-phase` (Always — adaptive questioning → CONTEXT.md)
2. `superpowers:writing-plans` (Always — spec-to-plan bridge)
3. `engineering:testing-strategy` (Always — test requirements baked in before planning)
4. `gsd-list-phase-assumptions` (As-needed — surface hidden assumptions)
5. `gsd-analyze-dependencies` (Always — map phase dependencies)
6. `gsd-plan-phase` (Always — produce PLAN.md with verification loop)

Invoke each applicable step via the Skill tool.

### Review Cycle

Artifact review through artifact-review-assessor per the Reviewer → Assessor → fix MUST-FIX → Reviewer cycle until 2 consecutive clean passes:

- `CONTEXT.md` → invoke `/artifact-reviewer .planning/phases/{phase}/CONTEXT.md --reviewer review-context` via the Skill tool
- `RESEARCH.md` → invoke `/artifact-reviewer .planning/phases/{phase}/RESEARCH.md --reviewer review-research` via the Skill tool (if it exists)
- `PLAN.md` → invoke `/artifact-reviewer` with `--reviewer gsd-plan-checker` via the Skill tool (max 3 iterations, 2 consecutive clean passes required)

### Exit Condition

PLAN.md exists with plan-checker PASS (2 consecutive clean passes).

---

## PATH 7: EXECUTE — GSD wave-based implementation

### Prerequisite Check

Both must pass. If either fails, STOP with specific message:

```bash
[ -f ".planning/phases/{phase}/{plan}-PLAN.md" ] || echo "STOP: PLAN.md missing — run PATH 5 first"
grep "Current Position.*{phase}" .planning/STATE.md  || echo "STOP: STATE.md position does not match current phase — check STATE.md"
```

### Steps

1. `superpowers:test-driven-development` (As-needed — implementation plans only, per D-09; skip for config/infra/doc plans)
2. `gsd-execute-phase` (Interactive mode, Always) OR `gsd-autonomous` (Autonomous mode per §10e, Always) — these are the sole execution engines; do not implement features directly
3. `context7-plugin:context7-mcp` (Ambient — available during execution for library documentation lookups, per D-11)

Invoke each applicable step via the Skill tool.

### Failure Path

If execution fails mid-wave, do NOT mark the phase complete. Route to `silver:bugfix` via the Skill tool for triage. Return here only after bugfix confirms the root cause is resolved.

(PATH 14 DEBUG dynamic insertion will be implemented in Phase 24, per D-10.)

### Exit Condition

All PLAN.md files for the current phase have SUMMARY.md, STATE.md advanced.

---

## Non-core path steps: Review, Security, Quality
<!-- These steps map to PATH 9 (REVIEW), PATH 10 (SECURE), PATH 8 (UI QUALITY), and PATH 12 pre-ship quality gate. They will become full composable paths in Phase 23-24. -->

### Step 9a: Request Code Review — PATH 9 (REVIEW) [future]

Invoke `silver:request-review` (superpowers:requesting-code-review) via the Skill tool. Purpose: frame review scope and focus rigorously before spawning reviewers.

### Step 9b: Run Code Review — PATH 9 (REVIEW) [future]

Invoke `gsd-code-review` via the Skill tool. Purpose: spawn reviewer agents → REVIEW.md.

If issues found in REVIEW.md: invoke `gsd-code-review-fix` via the Skill tool to auto-fix findings atomically before human review.

### Step 9c: Cross-AI Review — PATH 9 (REVIEW) [future, conditional]

**Only for architecturally significant changes or user request:**

Invoke `gsd-review --multi-ai` via the Skill tool. Purpose: cross-AI adversarial peer review of completed code. Distinct from Step 1d (pre-spec MultAI) — this reviews post-execution code.

### Step 9d: Receive Review — PATH 9 (REVIEW) [future]

Invoke `silver:receive-review` (superpowers:receiving-code-review) via the Skill tool. Purpose: disciplined response to findings — no blind agreement.

### Step 10: Security Review — PATH 10 (SECURE) [future]

Invoke `silver:security` via the Skill tool. Non-skippable gate.

### Step 11: Secure Phase — PATH 10 (SECURE) [future]

Invoke `gsd-secure-phase` via the Skill tool. Purpose: retroactive threat mitigation verification.

### Step 12: Validate Phase — PATH 10 (SECURE) [future]

Invoke `gsd-validate-phase` via the Skill tool. Purpose: Nyquist validation gap filling.

### Step 13: Pre-Ship Quality Gates (9 dimensions) — PATH 12 pre-ship [future]

Invoke `silver:quality-gates` via the Skill tool. Purpose: full 9-dimension sweep before shipping. Non-skippable gate.

---

## PATH 11: VERIFY — Non-skippable verification

### Prerequisite Check

PATH 7 completed: at least one SUMMARY.md must exist for the current phase. If not, STOP and complete PATH 7 first.

```bash
ls .planning/phases/{phase}/*-SUMMARY.md 2>/dev/null | grep -q . || echo "STOP: No SUMMARY.md found — PATH 7 must complete first"
```

### NON-SKIPPABLE

This path cannot be skipped regardless of §10 preferences. Refuse all skip requests for this path and its steps.

### Steps

1. `gsd-verify-work` (Always — NON-SKIPPABLE; produces UAT.md and VERIFICATION.md; phase is NOT complete until this passes)
2. `gsd-add-tests` (As-needed — only if gsd-verify-work surfaces coverage gaps; generates tests from UAT criteria)
3. `superpowers:verification-before-completion` (Always — structured verification discipline before declaring done)

Invoke each applicable step via the Skill tool.

### Review Cycle

UAT.md through artifact-review-assessor per the Reviewer → Assessor → fix MUST-FIX → Reviewer cycle until 2 consecutive clean passes:

- `UAT.md` → invoke `/artifact-reviewer .planning/UAT.md --reviewer review-uat` via the Skill tool

### Exit Condition

VERIFICATION.md exists with `status: passed` (2 consecutive clean passes).

---

## PATH 13: SHIP — Deliver

### Prerequisite Check

All four must pass. If any fail, STOP with the specific message. Per D-14:

```bash
# PATH 12 pre-ship quality gates must have passed (Step 13 above completed)
# PATH 11 completed: VERIFICATION.md with status: passed
grep -q "status: passed" .planning/VERIFICATION.md || echo "STOP: PATH 11 not complete — VERIFICATION.md must show status: passed"
# Clean working tree
git status --porcelain | grep -q . && echo "STOP: Working tree is not clean — commit or stash changes" || true
# On a feature branch (not main/master)
git rev-parse --abbrev-ref HEAD | grep -qE "^(main|master)$" && echo "STOP: Must be on a feature branch, not main/master" || true
```

### Steps

1. `superpowers:finishing-a-development-branch` (Always — merge / PR / cleanup decision; skip only when current branch is main, per project convention)
2. `gsd-pr-branch` (As-needed — user chooses clean PR branch that strips .planning/ commits)
3. `engineering:deploy-checklist` (As-needed — production deployment required)
4. `gsd-ship` (Always — push branch, create PR, prepare for merge at phase level)

Invoke each applicable step via the Skill tool.

**PR branch choice:** Ask the user before gsd-pr-branch:

> Would you like a clean PR branch (strips .planning/ commits)?
>
> A. Yes — run gsd-pr-branch  B. No — ship as-is  C. Save as permanent preference

If C: record preference in silver-bullet.md §10e and templates/silver-bullet.md.base §10e, commit both.

### Exit Condition

PR created, CI green. Per D-15.

---

## Step 16: Episodic Memory

Invoke `episodic-memory:remembering-conversations` via the Skill tool to record key decisions and lessons from this feature.

## Step 17: Milestone Completion (last phase of milestone only)

Ask user:

> Is this the last phase of the current milestone?
>
> A. Yes — run milestone completion lifecycle  B. No — done

If A, run in sequence:

### Step 17.0: Generate UAT.md from SPEC.md

Read `.planning/SPEC.md` `## Acceptance Criteria` section. For each criterion, create a row in `.planning/UAT.md` with Result = NOT-RUN and Evidence = empty.

UAT.md format:
- Frontmatter: spec-version (from SPEC.md), uat-date (today), milestone (from STATE.md)
- Table: # | Criterion | Result | Evidence
- Summary section: Total, PASS, FAIL, NOT-RUN counts

Write `.planning/UAT.md` using the Write tool.

### Step 17.0a: Review UAT.md

Invoke `/artifact-reviewer .planning/UAT.md --reviewer review-uat` via the Skill tool.

Do NOT proceed to gsd-audit-uat until /artifact-reviewer reports 2 consecutive clean passes. If issues are found, /artifact-reviewer will apply fixes and re-review automatically. If /artifact-reviewer surfaces an unresolvable issue after 5 rounds, STOP and present it to the user.

### Step 17.0b: Cross-Artifact Consistency Review

Invoke `/artifact-reviewer --reviewer review-cross-artifact --artifacts .planning/SPEC.md .planning/REQUIREMENTS.md .planning/ROADMAP.md` (add `.planning/DESIGN.md` if it exists).

Do NOT proceed to gsd-audit-uat until cross-artifact review reports clean pass. If ISSUES_FOUND, the orchestrator applies fixes and re-reviews per the review loop. If unresolvable after 5 rounds, STOP and present to the user.

**Why here:** Cross-artifact alignment must be confirmed before milestone audit begins — auditing against misaligned artifacts wastes effort.

1. Invoke `gsd-audit-uat` via the Skill tool
2. Invoke `gsd-audit-milestone` via the Skill tool
3. If gaps found (max 2 gap-closure iterations): invoke `gsd-plan-milestone-gaps` → invoke `silver:feature` for gap phases → return to Step 0 of the gap phases. After 2 iterations if gaps remain, surface to user with options.
4. Invoke `gsd-complete-milestone` via the Skill tool
