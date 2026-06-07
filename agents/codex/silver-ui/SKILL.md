---
name: "silver:ui"
title: "Silver: /silver:ui - UI"
description: >
  This skill should be used for full SB-orchestrated UI/frontend workflow: orient → clarify/decide → testing strategy → gsd-ui-phase → execute+TDD → gsd-ui-review → verify → ship
argument-hint: "<UI feature or component description>"
version: 0.1.0
---

# /silver:ui — Frontend, Component, Interface Workflow

SB orchestrator for UI, frontend, component, screen, design, interface, page, layout, animation, and responsive work. Follows the same skeleton as silver:feature but inserts gsd-ui-phase for design contract and gsd-ui-review post-execution.

**Routing note:** If an instruction matches both silver:feature and silver:ui, silver:ui wins — UI is more specific. silver:bugfix always takes precedence over both.

Never implements UI directly — orchestrates only.

## Mandatory dependency execution

Before any local UI implementation work, the execution trace must show the dependency chain for this workflow. At minimum, invoke these downstream skills in order:

1. `gsd-scan` when rapid SB orientation is useful
2. `gsd-map-codebase` when the project is brownfield or deeper UI pattern mapping is needed
3. `silver:clarify`
4. `silver:research` when FLOW DECIDE is needed for interaction, design-system, API, or architecture tradeoffs
5. `silver:quality-gates`
6. `gsd:discuss-phase`
7. `gsd:ui-phase`
8. `gsd:plan-phase`
9. `gsd:execute-phase` or `gsd:autonomous`
10. `gsd:ui-review`
11. `gsd:verify-work`

If any required downstream skill cannot be invoked, stop immediately and notify the user. Offer install-and-retry first. Do not replace missing dependency skills with shell reconnaissance, direct edits, or other fallback work.

The `workflow-chain-guard.sh` hook enforces this at edit time: once the composed workflow is active, implementation edits stay blocked until the downstream GSD markers are actually present in the workflow state. If the guard blocks you, that means the dependency chain is not complete yet.

## Pre-flight: Load Preferences

Read the **User Workflow Preferences** section of `silver-bullet.md` to load user workflow preferences before any other step.

```bash
grep -A 50 "^## [0-9]\+\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
SILVER BULLET ► UI WORKFLOW

UI work: {$ARGUMENTS or "(not specified)"}
Mode:    {interactive | autonomous — from §10e or session selection}
```

## Composition Proposal

Before beginning execution, read existing artifacts to determine context and propose which flows to include or skip.

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

### 2. Build Flow Chain

Construct the proposed flow chain for UI work. Default full chain:

FLOW 0 (BOOTSTRAP) [skip if .planning/ exists] → FLOW 1 (ORIENT) → FLOW 2 (CLARIFY) → FLOW 3 (DECIDE) [if interaction/design tradeoff needs research] → FLOW 4 (SPECIFY) [skip if SPEC.md exists] → FLOW 12 (QUALITY GATE, pre-plan) → FLOW 5 (PLAN) → FLOW 6 (DESIGN CONTRACT) [always in UI workflow] → FLOW 7 (EXECUTE) → FLOW 8 (UI QUALITY) [always in UI workflow] → FLOW 9 (REVIEW) → FLOW 10 (SECURE) → FLOW 11 (VERIFY) → FLOW 12 (QUALITY GATE, pre-ship) → FLOW 13 (SHIP)

Note: FLOW 6 (DESIGN CONTRACT) and FLOW 8 (UI QUALITY) are always included — this is a UI-focused workflow.

### 3. Display Proposal

Display the composition proposal to the user:

```
SILVER BULLET ► FLOW COMPOSED
Flows: ORIENT → DESIGN CONTRACT → PLAN → EXECUTE → UI QUALITY → ...
Skipped: BOOTSTRAP — .planning/ exists
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

SB_WORKFLOW_ID=$("$SB_WORKFLOWS_BIN" start /silver:ui "the user's original request" "$SB_FLOWS")
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

**Non-skippable gates:** `security`, `silver:quality-gates` pre-ship, `gsd-verify-work`.

## Step 0: Orient in Codebase

Invoke `gsd-scan` through the active runtime's SB-recognized skill invocation channel to understand existing UI patterns and component hierarchy.

If brownfield project and deeper mapping is needed, also invoke `gsd-map-codebase` through the active runtime's SB-recognized skill invocation channel.

## Step 1a: Fuzzy Clarification (conditional)

**Only if intent is fuzzy or $ARGUMENTS is empty:**
Invoke `silver:clarify` through the active runtime's SB-recognized skill invocation channel for Socratic framing, option comparison, and decision-ready handoff of UI intent.

## Step 1b: MultAI UI Perspectives (conditional)

**Only for major UI systems (design system, cross-cutting UI architecture, or user request):**

Ask:
> This appears to be a major UI system. Would you like multi-AI UX pattern perspectives?
>
> A. Yes — run multai:orchestrator for multi-AI UX review
> B. No — proceed with spec as-is

If A: invoke `silver:multai` (multai:orchestrator) through the active runtime's SB-recognized skill invocation channel. If the MultAI plugin is unavailable, STOP and notify the user; offer install-and-retry first.

## Step 2: Testing Strategy

Invoke `testing-strategy` through the active runtime's SB-recognized skill invocation channel when available. Purpose: define test levels for UI (component, visual, e2e) before GSD planning.

## Step 2.5: Writing Plans

Keep the authoritative implementation plan in `gsd-plan-phase`. If the selected SB flow explicitly needs Superpowers plan-writing discipline, invoke `superpowers:writing-plans` through the active runtime's SB-recognized skill invocation channel; SB does not package a local `writing-plans` skill.

## Step 3: Pre-Plan Quality Gates

Invoke `silver:quality-gates` through the active runtime's SB-recognized skill invocation channel. Purpose: 8 core dimensions with usability + testability emphasis, plus conditional AI/LLM safety where applicable; `security` mandatory.

## Step 4: Discuss Phase

Invoke `gsd-discuss-phase` through the active runtime's SB-recognized skill invocation channel. Purpose: UI phase context → CONTEXT.md with locked decisions.

## FLOW DESIGN CONTRACT — UI specification (iterative)

**Prerequisite Check:** PLAN.md exists for current phase. STOP if not met.

**Note:** Always active in silver:ui (UI workflow is inherently UI work — no trigger detection needed).

**Steps** (all through the active runtime's SB-recognized skill invocation channel):
1. `design:design-system` (Always)
2. `design:ux-copy` (As-needed — user-facing copy requires review)
3. `gsd-ui-phase` (Always — produces UI-SPEC.md)
4. `design:accessibility-review` (As-needed — WCAG 2.1 AA compliance check)

**Iterative:** User can loop steps 1-4. The helper suggests when design contract is solid; the user decides when to exit.

**Exit Condition:** UI-SPEC.md exists, user accepts design contract.

## Step 6: Plan Phase

Invoke `gsd-plan-phase` through the active runtime's SB-recognized skill invocation channel. Purpose: implementation PLAN.md built on top of UI-SPEC.md contract.

## Step 7: Execute Phase + TDD

**Execute:**
If mode is Interactive: invoke `gsd-execute-phase --tdd` through the active runtime's SB-recognized skill invocation channel for testable component units (logic, state, interactions). For pure layout/styling tasks, invoke `gsd-execute-phase` without `--tdd`.
If mode is Autonomous (§10e): invoke `gsd-autonomous` through the active runtime's SB-recognized skill invocation channel. For implementation plans, only use Autonomous when the underlying GSD TDD mode is already enabled; otherwise fall back to Interactive so the internal `tdd` gate can run before execution.

**Internal TDD gate:**
`tdd` is hidden from the picker and activates immediately before execution for component logic. It delegates to `superpowers:test-driven-development`, so the execute boundary cannot start until the failing-test-first discipline is in place.

## Step 8: Code Review

Run review sequence in order:
1. Invoke `requesting-code-review` (superpowers:requesting-code-review) through the active runtime's SB-recognized skill invocation channel.
2. Invoke `gsd-code-review` through the active runtime's SB-recognized skill invocation channel. This creates the authoritative REVIEW.md artifact; optional external review helpers must feed into this artifact rather than replace it. If issues found: invoke `gsd-code-review-fix` through the active runtime's SB-recognized skill invocation channel.
3. For architecturally significant UI systems: invoke `gsd-review --all` through the active runtime's SB-recognized skill invocation channel (cross-AI adversarial review across all available CLIs).
3. Invoke `receiving-code-review` (superpowers:receiving-code-review) through the active runtime's SB-recognized skill invocation channel.

## FLOW UI QUALITY — Post-execution UI audit

**Prerequisite Check:** Execution complete, SUMMARY.md exists with UI deliverables. STOP if not met.

**Note:** Always active in silver:ui (no trigger detection needed).

**Steps** (all through the active runtime's SB-recognized skill invocation channel):
1. `design:design-critique` (Always)
2. `gsd-ui-review` (Always — 6-pillar audit: layout fidelity, accessibility, responsiveness, interaction quality, visual consistency, performance)
3. `design:accessibility-review` (Always)

**Produces:** UI-REVIEW.md. Fixes route through `gsd-execute-phase --gaps-only`.

**Review Cycle:** UI-REVIEW.md through artifact-review-assessor, fix critical via GSD, re-audit.

**Exit Condition:** UI-REVIEW.md exists with no critical findings, or user accepts.

## Step 10: Frontend Security

Invoke `gsd-secure-phase` through the active runtime's SB-recognized skill invocation channel. Purpose: frontend security review — XSS, CSP, auth surface. Also invoke `security` as the mandatory security gate.

## Step 11: Verify Work + Test Gap Fill

Invoke `gsd-verify-work` through the active runtime's SB-recognized skill invocation channel. Non-skippable.

If coverage gaps remain after verification: invoke `gsd-add-tests` through the active runtime's SB-recognized skill invocation channel.

## Step 12: Validate Phase

Invoke `gsd-validate-phase` through the active runtime's SB-recognized skill invocation channel. Purpose: Nyquist gap filling.

## Step 12b: Tech Debt Review

Invoke `tech-debt` through the active runtime's SB-recognized skill invocation channel when available. Purpose: identify and document any technical debt introduced during this phase. Items not addressed now MUST be captured via `/silver:add`.

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

## Step 13: Pre-Ship Quality Gates

Invoke `silver:quality-gates` through the active runtime's SB-recognized skill invocation channel. Run the 8 core dimensions plus any conditional gates that apply. Non-skippable.

## Step 13b: Doc-Scheme Compliance (conditional)

**Only if `docs/doc-scheme.md` exists in the project:**

```bash
[ -f "docs/doc-scheme.md" ] && [ -f "docs/doc-scheme.json" ] && echo "Doc-scheme gate required" || echo "Doc scheme missing/incomplete — run /silver:ensure-docs --recover-scheme"
```

Before raising the PR, verify documentation is up to date per the scheme:

1. **`docs/CHANGELOG.md`** — must have an entry for the phase just completed (newest-first). If missing, write it now: one entry summarising what shipped.
2. **`docs/knowledge/YYYY-MM.md`** (current month) — append task-specific patterns, gotchas, and key decisions.
3. **`docs/lessons/YYYY-MM.md`** (current month) — append portable lessons learned.
4. Update any additional docs changed by the phase (`ARCHITECTURE.md`, `TESTING.md`, runbooks, workflows, etc.) so content matches current behavior.
5. **`docs/task-doc-checklist.json`** — must include `task_granularity` and full status coverage for every key in `docs/doc-scheme.json -> required_docs`, plus any required section entries declared under `required_sections`.

**Gate:** Do NOT proceed to Step 14 until all checklist/doc checks pass. Missing checklist keys or stale `updated` claims are pre-ship defects.

If `docs/doc-scheme.md`/`docs/doc-scheme.json` are missing, recover via `/silver:ensure-docs --recover-scheme`, then complete this step before proceeding to Step 14.

## Step 14: Finishing Branch

Invoke `superpowers:finishing-a-development-branch` through the active runtime's SB-recognized skill invocation channel; SB does not package a local `finishing-branch` skill.

Ask user about PR branch:
> Would you like a clean PR branch (strips .planning/ commits)?
>
> A. Yes — run gsd-pr-branch  B. No — ship as-is  C. Save as permanent preference

If A: invoke `gsd-pr-branch` through the active runtime's SB-recognized skill invocation channel.
If C: record in silver-bullet.md §10e and templates/silver-bullet.md.base §9e, commit both.

## Step 15: Ship Phase

Invoke `gsd-ship` through the active runtime's SB-recognized skill invocation channel. Purpose: push branch, create PR, prepare for merge (phase-level).

## Step 16: Milestone Completion (last phase of milestone only)

Ask user:
> Is this the last phase of the current milestone?
>
> A. Yes — run milestone completion lifecycle  B. No — done

If A, run in sequence:
1. `gsd-audit-uat` → `gsd-audit-milestone` → [gaps, max 2 iterations: `gsd-plan-milestone-gaps` → `silver:feature` for gap phases] → `gsd-complete-milestone`
