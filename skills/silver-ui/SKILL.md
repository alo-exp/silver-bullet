---
name: silver-ui
description: "Full SB-orchestrated UI/frontend workflow: intel → product-brainstorm → brainstorm → testing-strategy → gsd-ui-phase → execute+TDD → gsd-ui-review → ship"
argument-hint: "<UI feature or component description>"
---

# /silver:ui — Frontend, Component, Interface Workflow

SB orchestrator for UI, frontend, component, screen, design, interface, page, layout, animation, and responsive work. Follows the same skeleton as silver:feature but inserts gsd-ui-phase for design contract and gsd-ui-review post-execution.

**Routing note:** If an instruction matches both silver:feature and silver:ui, silver:ui wins — UI is more specific. silver:bugfix always takes precedence over both.

Never implements UI directly — orchestrates only.

## Pre-flight: Load Preferences

Read `silver-bullet.md §10` to load user workflow preferences before any other step.

```bash
grep -A 50 "^## 10\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► UI WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

UI work: {$ARGUMENTS or "(not specified)"}
Mode:    {interactive | autonomous — from §10e or session selection}
```

## Composition Proposal

Before beginning execution, read existing artifacts to determine context and propose which PATHs to include or skip.

### 1. Context Scan

Check the following artifacts and set skip/include flags:

| Artifact | Signal | Action |
|----------|--------|--------|
| `.planning/` directory exists | Project already bootstrapped | Skip FLOW 0 (BOOTSTRAP) |
| `.planning/SPEC.md` exists | Specification already written | Skip FLOW 4 (SPECIFY) |
| `.planning/PLAN.md` files exist for current phase | Planning already done | Skip FLOW 5 (PLAN) |
| UI files detected in phase scope (*.tsx, *.css, *.html, design/) | UI work in scope | Always include FLOW 6 (DESIGN CONTRACT) and FLOW 8 (UI QUALITY) — this is the UI workflow |

```bash
# Check for existing planning artifacts
[ -d ".planning" ] && echo "SKIP FLOW 0 — .planning/ exists" || echo "Include FLOW 0"
[ -f ".planning/SPEC.md" ] && echo "SKIP FLOW 4 — SPEC.md exists" || echo "Include FLOW 4"
ls .planning/phases/*/PLAN.md 2>/dev/null | head -1 && echo "SKIP FLOW 5 — PLAN.md exists" || echo "Include FLOW 5"
```

### 2. Build Path Chain

Construct the proposed flow chain for UI work. Default full chain:

FLOW 0 (BOOTSTRAP) [skip if .planning/ exists] → FLOW 1 (ORIENT) → FLOW 6 (DESIGN CONTRACT) [always in UI workflow] → FLOW 4 (SPECIFY) [skip if SPEC.md exists] → FLOW 5 (PLAN) → FLOW 7 (EXECUTE) → FLOW 8 (UI QUALITY) [always in UI workflow] → FLOW 9 (REVIEW) → FLOW 12 (QUALITY GATE) → FLOW 13 (SHIP)

Note: FLOW 6 (DESIGN CONTRACT) and FLOW 8 (UI QUALITY) are always included — this is a UI-focused workflow.

### 3. Display Proposal

Display the composition proposal to the user:

```
┌─ COMPOSITION PROPOSAL ─────────────────────────
│ Paths: FLOW 1 (ORIENT) → FLOW 6 (DESIGN CONTRACT) → FLOW 5 (PLAN) → FLOW 7 (EXECUTE) → FLOW 8 (UI QUALITY) → ...
│ Skipped: FLOW 0 (BOOTSTRAP) — .planning/ exists
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
- Populate `Intent:` with the user's original request
- Populate `Composed:` with the current ISO timestamp
- Populate `Composer:` with `/silver:ui`
- Populate `Mode:` with the current mode (interactive or autonomous)
- Record the confirmed flow chain in the Flow Log section header

After each path completes, write status to Flow Log table:

```
| {#} | FLOW {N} ({name}) | complete | {artifacts produced} | ✓ |
```

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §10b, commit both.

**Non-skippable gates:** `silver:security`, `silver:silver-quality-gates` pre-ship, `gsd-verify-work`.

## Step 0: Orient in Codebase

Invoke `silver:intel` (gsd-intel) via the Skill tool to understand existing UI patterns and component hierarchy.

If brownfield project, also invoke `silver:scan` (gsd-scan) via the Skill tool for rapid structure assessment.

## Step 1a: Fuzzy Clarification (conditional)

**Only if intent is fuzzy or $ARGUMENTS is empty:**
Invoke `silver:explore` (gsd-explore) via the Skill tool for Socratic clarification of UI intent.

## Step 1b: Product Brainstorming

Invoke `/product-brainstorming` via the Skill tool. Purpose: user flows, personas, success criteria, and scope for the UI feature.

## Step 1c: Engineering Brainstorm

Invoke `silver:brainstorm` (superpowers:brainstorming) via the Skill tool. Purpose: UI architecture, component hierarchy, interaction design, spec.

## Step 1d: MultAI UI Perspectives (conditional)

**Only for major UI systems (design system, cross-cutting UI architecture, or user request):**

Ask:
> This appears to be a major UI system. Would you like multi-AI UX pattern perspectives?
>
> A. Yes — run multai:orchestrator for multi-AI UX review
> B. No — proceed with spec as-is

If A: invoke `silver:multai` (multai:orchestrator) via the Skill tool.

## Step 2: Testing Strategy

Invoke `/testing-strategy` via the Skill tool. Purpose: define test levels for UI (component, visual, e2e) — MUST run after spec approval and before writing-plans.

## Step 2.5: Writing Plans

Invoke `silver:writing-plans` (superpowers:writing-plans) via the Skill tool. Purpose: spec + test strategy → implementation plan with frontend-design emphasis.

## Step 3: Pre-Plan Quality Gates

Invoke `silver:silver-quality-gates` via the Skill tool. Purpose: 9 dimensions with usability + testability emphasis; `silver:security` mandatory.

## Step 4: Discuss Phase

Invoke `gsd-discuss-phase` via the Skill tool. Purpose: UI phase context → CONTEXT.md with locked decisions.

## FLOW 6: DESIGN CONTRACT — UI specification (iterative)

**Prerequisite Check:** PLAN.md exists for current phase. STOP if not met.

**Note:** Always active in silver-ui (UI workflow is inherently UI work — no trigger detection needed).

**Steps** (all via Skill tool):
1. `design:design-system` (Always)
2. `design:ux-copy` (As-needed — user-facing copy requires review)
3. `gsd-ui-phase` (Always — produces UI-SPEC.md)
4. `design:accessibility-review` (As-needed — WCAG 2.1 AA compliance check)

**Iterative:** User can loop steps 1-4. Claude suggests when design contract is solid; user decides exit.

**Exit Condition:** UI-SPEC.md exists, user accepts design contract.

## Step 6: Plan Phase

Invoke `gsd-plan-phase` via the Skill tool. Purpose: implementation PLAN.md built on top of UI-SPEC.md contract.

## Step 7: Execute Phase + TDD

**Execute:**
If mode is Interactive: invoke `gsd-execute-phase` via the Skill tool.
If mode is Autonomous (§10e): invoke `gsd-autonomous` via the Skill tool.

**TDD for component logic:**
Invoke `silver:tdd` (superpowers:test-driven-development) via the Skill tool for testable component units (logic, state, interactions). Skip for pure layout/styling tasks.

## Step 8: Code Review

Run review sequence in order:
1. Invoke `silver:request-review` (superpowers:requesting-code-review) via the Skill tool.
2. Invoke `/code-review` via the Skill tool. Purpose: establish review criteria before spawning reviewer agents.
3. Invoke `gsd-code-review` via the Skill tool. If issues found: invoke `gsd-code-review-fix` via the Skill tool.
3. For architecturally significant UI systems: invoke `gsd-review --all` via the Skill tool (cross-AI adversarial review across all available CLIs).
4. Invoke `silver:receive-review` (superpowers:receiving-code-review) via the Skill tool.

## FLOW 8: UI QUALITY — Post-execution UI audit

**Prerequisite Check:** Execution complete, SUMMARY.md exists with UI deliverables. STOP if not met.

**Note:** Always active in silver-ui (no trigger detection needed).

**Steps** (all via Skill tool):
1. `design:design-critique` (Always)
2. `gsd-ui-review` (Always — 6-pillar audit: layout fidelity, accessibility, responsiveness, interaction quality, visual consistency, performance)
3. `design:accessibility-review` (Always)

**Produces:** UI-REVIEW.md. Fixes route through `gsd-execute-phase --gaps-only`.

**Review Cycle:** UI-REVIEW.md through artifact-review-assessor, fix critical via GSD, re-audit.

**Exit Condition:** UI-REVIEW.md exists with no critical findings, or user accepts.

## Step 10: Frontend Security

Invoke `gsd-secure-phase` via the Skill tool. Purpose: frontend security review — XSS, CSP, auth surface. Also invoke `silver:security` as the mandatory security gate.

## Step 11: Verify Work + Test Gap Fill

Invoke `gsd-verify-work` via the Skill tool. Non-skippable.

If coverage gaps remain after verification: invoke `gsd-add-tests` via the Skill tool.

## Step 12: Validate Phase

Invoke `gsd-validate-phase` via the Skill tool. Purpose: Nyquist gap filling.

## Step 12b: Tech Debt Review

Invoke `/tech-debt` via the Skill tool. Purpose: identify and document any technical debt introduced during this phase. Items not addressed now MUST be captured via `gsd-add-backlog`.

## Step 13: Pre-Ship Quality Gates

Invoke `silver:silver-quality-gates` via the Skill tool. Full 9-dimension sweep. Non-skippable.

## Step 14: Finishing Branch

Invoke `silver:finishing-branch` (superpowers:finishing-a-development-branch) via the Skill tool.

Ask user about PR branch:
> Would you like a clean PR branch (strips .planning/ commits)?
>
> A. Yes — run gsd-pr-branch  B. No — ship as-is  C. Save as permanent preference

If A: invoke `gsd-pr-branch` via the Skill tool.
If C: record in silver-bullet.md §10e and templates/silver-bullet.md.base §10e, commit both.

## Step 15: Ship Phase

Invoke `gsd-ship` via the Skill tool. Purpose: push branch, create PR, prepare for merge (phase-level).

## Step 16: Milestone Completion (last phase of milestone only)

Ask user:
> Is this the last phase of the current milestone?
>
> A. Yes — run milestone completion lifecycle  B. No — done

If A, run in sequence:
1. `gsd-audit-uat` → `gsd-audit-milestone` → [gaps, max 2 iterations: `gsd-plan-milestone-gaps` → `silver:feature` for gap phases] → `gsd-complete-milestone`
