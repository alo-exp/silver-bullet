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

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §10b, commit both.

**Non-skippable gates:** `silver:security`, `silver:quality-gates` pre-ship, `gsd-verify-work`.

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

Invoke `silver:quality-gates` via the Skill tool. Purpose: 9 dimensions with usability + testability emphasis; `silver:security` mandatory.

## Step 4: Discuss Phase

Invoke `gsd-discuss-phase` via the Skill tool. Purpose: UI phase context → CONTEXT.md with locked decisions.

## Step 5: UI Phase — Design Contract

Invoke `gsd-ui-phase` via the Skill tool. Purpose: create UI-SPEC.md design contract — component API, layout rules, interaction spec. This step is the key differentiator from silver:feature.

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
2. Invoke `gsd-code-review` via the Skill tool. If issues found: invoke `gsd-code-review-fix` via the Skill tool.
3. For architecturally significant UI systems: invoke `gsd-review --multi-ai` via the Skill tool (cross-AI adversarial review).
4. Invoke `silver:receive-review` (superpowers:receiving-code-review) via the Skill tool.

## Step 9: UI Visual Audit

Invoke `gsd-ui-review` via the Skill tool. Purpose: 6-pillar visual audit of implemented UI — layout fidelity, accessibility, responsiveness, interaction quality, visual consistency, performance. This step is unique to the UI workflow.

## Step 10: Frontend Security

Invoke `gsd-secure-phase` via the Skill tool. Purpose: frontend security review — XSS, CSP, auth surface. Also invoke `silver:security` as the mandatory security gate.

## Step 11: Verify Work + Test Gap Fill

Invoke `gsd-verify-work` via the Skill tool. Non-skippable.

If coverage gaps remain after verification: invoke `gsd-add-tests` via the Skill tool.

## Step 12: Validate Phase

Invoke `gsd-validate-phase` via the Skill tool. Purpose: Nyquist gap filling.

## Step 13: Pre-Ship Quality Gates

Invoke `silver:quality-gates` via the Skill tool. Full 9-dimension sweep. Non-skippable.

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
