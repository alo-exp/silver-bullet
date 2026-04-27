---
name: silver-feature
description: This skill should be used for full SB-orchestrated feature development workflow: intel → product-brainstorm → brainstorm → silver-quality-gates → GSD plan/execute/verify → ship
argument-hint: "<feature description>"
version: 0.1.0
---

# /silver:feature — Feature Development Workflow

SB orchestrator for new feature development. Chains GSD (execution backbone), Superpowers (craft discipline), MultAI (multi-AI intelligence), and SB quality gates in the sequence defined in silver-bullet.md §2h.

Never implements features directly — orchestrates only.

## Pre-flight: Load Preferences

Read the **User Workflow Preferences** section of `silver-bullet.md` to load user workflow preferences before any other step. Silently apply any stored routing, skip, tool, MultAI, or mode preferences throughout this workflow.

```bash
grep -A 50 "^## [0-9]\+\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► FEATURE WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Feature: {$ARGUMENTS or "(not specified)"}
Mode:    {interactive | autonomous — from §10e or session selection}
```

## Composition Proposal

Before beginning execution, read existing artifacts to determine context and propose which flows to include or skip.

### 1. Context Scan

Check the following artifacts and set skip/include flags:

| Artifact | Signal | Action |
|----------|--------|--------|
| `.planning/SPEC.md` exists | Specification already written | Skip FLOW 4 (SPECIFY) |
| `.planning/PLAN.md` files exist for current phase | Planning already done | Skip FLOW 5 (PLAN) |
| `.planning/VERIFICATION.md` exists and passing | Verification already done | Skip FLOW 11 (VERIFY) |
| UI files detected in phase scope (*.tsx, *.css, *.html, design/) | UI work in scope | Include FLOW 6 (DESIGN CONTRACT) and FLOW 8 (UI QUALITY) |
| `STATE.md` current phase and completion status | Phase position | Set loop start/end |

```bash
# Read current phase from STATE.md
grep "^current_phase\|^current_plan" .planning/STATE.md 2>/dev/null

# Check for existing SPEC.md
[ -f ".planning/SPEC.md" ] && echo "SPEC exists — skip FLOW 4" || echo "No SPEC — include FLOW 4"

# Check ROADMAP.md for remaining phases in milestone
grep "^\-\s\[\s\]" .planning/ROADMAP.md 2>/dev/null | head -5
```

### 2. Build Flow Chain

Construct the proposed flow chain from the 18-flow catalog (FLOW 0-17), including only relevant flows based on the context scan. Standard full-feature chain:

FLOW 0 (BOOTSTRAP) → FLOW 1 (ORIENT) → FLOW 2 (INTEL) → FLOW 3 (BRAINSTORM) → FLOW 4 (SPECIFY) [skip if SPEC.md exists] → FLOW 5 (PLAN) → FLOW 6 (DESIGN CONTRACT) [include if UI] → FLOW 7 (EXECUTE) → FLOW 8 (UI QUALITY) [include if UI] → FLOW 9 (TDD) → FLOW 10 (REVIEW) → FLOW 11 (VERIFY) → FLOW 12 (SECURE) → FLOW 13 (SHIP)

### 3. Display Proposal

Display the composition proposal to the user:

```
┌──────────────────────────────────────────────────┐
│ SILVER BULLET ► FLOW COMPOSED                    │
├──────────────────────────────────────────────────┤
│ Flows: BOOTSTRAP → ORIENT → PLAN → ...           │
│ Skipped: SPECIFY — SPEC.md exists                │
│ Phase loop: Phases {start}-{end} (from ROADMAP)  │
└──────────────────────────────────────────────────┘
Approve composition? [Y/n]
```

### 4. Auto-Confirm in Autonomous Mode

In autonomous mode (§10e), auto-confirm the composition proposal with a log message:

```
⚡ Autonomous mode: auto-confirming composition — {flow count} flows, {skipped count} skipped
```

### 5. Create WORKFLOW.md

If `.planning/WORKFLOW.md` does not exist, create it from `templates/workflow.md.base`:
- Populate `Intent:` with the user's original request
- Populate `Composed:` with the current ISO timestamp
- Populate `Composer:` with `/silver:feature`
- Populate `Mode:` with the current mode (interactive or autonomous)
- Record the confirmed flow chain in the Flow Log section header

## Per-Phase Loop

After composition proposal is confirmed, execute flows across phases using STATE.md for phase advancement.

### 1. Read Current Phase

```bash
grep "^current_phase\|^current_plan\|^status" .planning/STATE.md 2>/dev/null
```

### 2. Read Remaining Phases

```bash
# Extract incomplete phases from ROADMAP.md (unchecked items)
grep "^\-\s\[\s\]" .planning/ROADMAP.md 2>/dev/null
```

### 3. Phase Iteration

For each remaining phase in the current milestone:

```
FOR each phase in remaining_phases:
  EXECUTE FLOW 5 (PLAN) → FLOW 7 (EXECUTE) → FLOW 11 (VERIFY) → FLOW 13 (SHIP)
  INSERT optional flows per composition proposal:
    - FLOW 6 (DESIGN CONTRACT) before FLOW 7 if UI discovered
    - FLOW 8 (UI QUALITY) after FLOW 7 if UI in scope
    - FLOW 9 (TDD) within FLOW 7 for implementation plans
    - FLOW 10 (REVIEW) after FLOW 7
    - FLOW 12 (SECURE) after FLOW 11
  TICK ROADMAP.md: update the checkbox for the completed phase from [ ] to [x]
    Use Edit tool to change:  - [ ] **Phase {N}: ...
    To:                       - [x] **Phase {N}: ... (completed {YYYY-MM-DD})
    Then include ROADMAP.md in the phase-completion commit (git add .planning/ROADMAP.md)
    NOTE: The roadmap-freshness hook will BLOCK the commit if this step is skipped.
  AFTER phase complete: advance to next phase
  UPDATE WORKFLOW.md Phase Iterations table
END FOR
```

### 4. Update WORKFLOW.md After Each Phase

After completing all flows for a phase, write to WORKFLOW.md Phase Iterations table:

```
| Phase {N} | FLOW 5 ✓ → FLOW 7 ✓ → FLOW 11 ✓ → FLOW 13 ✓ |
```

### 5. Flow Delegation

The existing Step 0 through Step 17 sections below serve as the implementation of each flow in the loop. The supervision loop (next section) runs BETWEEN each flow execution.

## Supervision Loop

The supervision loop runs BETWEEN each flow completion. It checks exit conditions, evaluates composition changes, detects stall, advances, and reports progress. Implement as inline logic at each flow boundary.

Six steps per boundary: **SL-1** exit-condition check → **SL-2** composition re-evaluation (debug/UI insertion triggers) → **SL-3** 4-tier anti-stall detection → **SL-4** advance → **SL-5** progress report → **SL-6** WORKFLOW.md update.

For full details on each step including stall-detection tiers, heartbeat sentinel, and WORKFLOW.md table formats, see **`references/supervision-loop.md`**.

---

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §10b, then commit both files.

**Non-skippable gates:** `silver:security`, `silver:silver-quality-gates` pre-ship, `gsd-verify-work`. Refuse skip requests for these regardless of §10.

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

If A: invoke `silver:multai` (multai:orchestrator) via the Skill tool. Note: this step informs the spec PRE-implementation. Step 9c (gsd-review --all) reviews completed code POST-execution. Both are independent.

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

Only proceed to Step 3 (silver-quality-gates) when silver-validate reports zero BLOCK findings.

WARN findings are recorded in .planning/VALIDATION.md and will appear in the PR description (VALD-04).

## Step 3: Pre-Plan Quality Gates (9 dimensions)

Invoke `silver:silver-quality-gates` via the Skill tool. Purpose: all 9 dimensions — reliability, security, scalability, usability, testability, modularity, reusability, extensibility, plus devops-quality-gates for infra-touching changes.

`silver:security` is always mandatory regardless of §10 preferences. `silver:testability` is embedded in silver-quality-gates (one of the 9 dimensions — not a separate step).

## Step 4: Discuss Phase

Invoke `gsd-discuss-phase` via the Skill tool. Purpose: adaptive questioning → CONTEXT.md with locked decisions for the planner.

## Step 5: Analyze Dependencies

Invoke `gsd-analyze-dependencies` via the Skill tool. Purpose: map phase dependencies before GSD creates the plan.

## Step 6: Plan Phase

Invoke `gsd-plan-phase` via the Skill tool. Purpose: PLAN.md with verification loop.

## Step 7: Execute Phase

**If mode is Interactive (default):** invoke `gsd-execute-phase` via the Skill tool.
**If mode is Autonomous (§10e):** invoke `gsd-autonomous` via the Skill tool.

**Error path:** If execution fails mid-wave, do NOT mark the phase complete. Route to `silver:bugfix` via the Skill tool for triage (Step 0 classification). Return here only after bugfix confirms the root cause is resolved.

**During-execution deferred capture:** While executing, any item that is skipped, descoped, or explicitly deferred (e.g., "skipping X for now", "out of scope", "future optimization") MUST be added to the backlog before moving to the next task — not at the end of the session. Do not accumulate deferred items silently.

**Deferred item routing:** File immediately via `/silver-add`:

```
Skill(skill="silver-add", args="<description of deferred item>")
```

## Step 7a: TDD Gate (implementation plans only)

**Only for implementation plans — skip for config/infra/doc plans:**
Heuristic: if the PLAN.md modifies source files containing business logic or application code, it is an implementation plan. Config-only, docs-only, or infra-only plans skip this step.

Invoke `silver:tdd` (superpowers:test-driven-development) via the Skill tool. Purpose: TDD red-green-refactor discipline per implementation task.

## Step 8: Verify Work

Invoke `gsd-verify-work` via the Skill tool. Purpose: UAT, must-haves, artifact checks. Phase is NOT complete until this passes. Non-skippable.

## Step 8b: Test Gap Fill (conditional)

**Only if gsd-verify-work surfaces coverage gaps:**

Invoke `gsd-add-tests` via the Skill tool. Purpose: generate tests from UAT criteria to fill gaps identified by verification — runs after gsd-verify-work so gap targets are known.

## Step 9a: Request Code Review

Invoke `silver:request-review` (superpowers:requesting-code-review) via the Skill tool. Purpose: frame review scope and focus rigorously before spawning reviewers.

## Step 9a2: Code Review Criteria

Invoke `/code-review` via the Skill tool. Purpose: establish review criteria and checklist before spawning reviewer agents — ensures reviewers have explicit quality bar to evaluate against.

## Step 9b: Run Code Review

Invoke `gsd-code-review` via the Skill tool. Purpose: spawn reviewer agents → REVIEW.md.

If issues found in REVIEW.md: invoke `gsd-code-review-fix` via the Skill tool to auto-fix findings atomically before human review.

## Step 9c: Cross-AI Review (conditional)

**Only for architecturally significant changes or user request:**

Invoke `gsd-review --all` via the Skill tool. Purpose: cross-AI adversarial peer review of completed code. Distinct from Step 1d (pre-spec MultAI) — this reviews post-execution code. The `--all` flag fans out to every available external CLI (Gemini, Claude, Codex, OpenCode, Qwen, Cursor).

## Step 9d: Receive Review

Invoke `silver:receive-review` (superpowers:receiving-code-review) via the Skill tool. Purpose: disciplined response to findings — no blind agreement.

## Step 9e: Backlog capture from review

After receiving review findings, scan REVIEW.md for any low-priority, deferred, or advisory items that were not fixed. **Every such item must be added to the GSD backlog immediately** — do not silently drop them.

For each unfixed non-blocking finding:
```
Skill(skill="silver-add", args="<finding description from REVIEW.md>")
```

If all findings were fixed or no advisory items exist, output: "No deferred review items to capture."

## Step 10: Security Review

Invoke `silver:security` via the Skill tool. Non-skippable gate.

## Step 11: Secure Phase

Invoke `gsd-secure-phase` via the Skill tool. Purpose: retroactive threat mitigation verification.

## Step 12: Validate Phase

Invoke `gsd-validate-phase` via the Skill tool. Purpose: Nyquist validation gap filling.

## Step 12b: Tech Debt Review

Invoke `/tech-debt` via the Skill tool. Purpose: identify and document any technical debt introduced during this phase — decisions made for speed, known shortcuts, deferred refactors. Items that cannot be addressed now MUST be captured via `/silver-add`.

## Step 13: Pre-Ship Quality Gates (9 dimensions)

Invoke `silver:silver-quality-gates` via the Skill tool. Purpose: full 9-dimension sweep before shipping. Non-skippable gate.

## Step 13b: Doc-Scheme Compliance (conditional)

**Only if `docs/doc-scheme.md` exists in the project:**

```bash
[ -f "docs/doc-scheme.md" ] && echo "Doc-scheme gate required" || echo "No doc-scheme — skip"
```

Before raising the PR, verify documentation is up to date per the scheme:

1. **`docs/CHANGELOG.md`** — must have an entry for the phase just completed (newest-first). If missing, write it now: one entry summarising what shipped.
2. **`docs/ARCHITECTURE.md`** — must NOT say "in progress" for completed phases. If stale, update §Current State to reflect completed state.
3. **`docs/knowledge/YYYY-MM.md`** (current month) — if architectural patterns, API gotchas, or key decisions were encountered, append them now.
4. **`docs/lessons/YYYY-MM.md`** (current month) — if portable lessons were learned, append them now.

**Gate:** Do NOT proceed to Step 14 until all four checks pass. Missing doc entries are a pre-ship defect — write them before continuing.

If no `docs/doc-scheme.md` exists: skip this step entirely and proceed to Step 14.

## Step 14: Finishing Branch

Invoke `silver:finishing-branch` (superpowers:finishing-a-development-branch) via the Skill tool. Purpose: merge / PR / cleanup decision.

## Step 15a: PR Branch (ask user)

Ask user:

> Would you like a clean PR branch (strips .planning/ commits)?
>
> A. Yes — run gsd-pr-branch  B. No — ship as-is  C. Save as permanent preference

If A: invoke `gsd-pr-branch` via the Skill tool.
If C: record preference in silver-bullet.md §10e and templates/silver-bullet.md.base §10e, commit both.

## Step 15b: Ship Phase

Invoke `gsd-ship` via the Skill tool. Purpose: push branch, create PR, prepare for merge (phase-level). This is phase-level merge — not milestone-level publish (that is `silver:release`).

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

## Step 18: Post-work backlog capture (mandatory)

After all work for this feature/phase is complete, perform a final deferred-item sweep:

1. Review all CONTEXT.md `<deferred>` sections from phases worked on in this session
2. Review any items marked "future", "TODO", "later", or "out of scope" in SUMMARYs, PLANs, or discussion
3. Review any items explicitly deferred during execution (e.g., "skipping X for now")

**Every deferred item that has not yet been captured must be added now** via `/silver-add`:
```
Skill(skill="silver-add", args="<deferred item description>")
```

If no items were deferred during this session, output: "Post-work sweep: no deferred items to capture."

**This step is non-negotiable.** Items deferred during execution and not captured here are permanently lost.

## Additional Resources

### Reference Files

- **`references/supervision-loop.md`** — Full supervision loop step details (SL-1 through SL-6), anti-stall tiers, heartbeat sentinel, WORKFLOW.md formats
