---
name: "silver:feature"
title: "Feature"
description: >
  This skill should be used for full SB-owned feature development workflow: orient → clarify/decide → silver:quality-gates → SB context/plan/execute/verify → ship
argument-hint: "<feature description>"
version: 0.1.0
---

# /silver:feature — Feature Development Workflow (composition spec)

SB **queue builder** for new feature development. The **parent orchestrator** reads this spec to seed `orchestrator.json` and spawn Task workers per atomic flow — it does not execute flows inline.

Never implements features directly — defines composition only.

## Mandatory dependency execution

SB separates pre-execution gates from post-execution gates.

Before implementation edits, the execution trace must show only the pre-execution chain that unlocks SB execution:

1. `silver:scan` when rapid SB orientation is useful
2. `silver:scan` with deeper mapping when the project is brownfield or the codebase is unfamiliar
3. `silver:clarify` when scope is fuzzy
4. `silver:research` when FLOW DECIDE is needed for architecture, stack, API, or data-model choices
5. `silver:spec` (FLOW 5) when `.planning/SPEC.md` does not yet exist (greenfield / new milestone)
6. `silver:quality-gates`
7. `silver:context`
8. `silver:plan`
9. `silver:validate` (pre-build gap analysis — runs after `silver:plan` so PLAN.md exists)

After implementation, final delivery requires the post-execution chain. **Canonical post-execution order (unified across `silver:feature`, `silver:ui`, `silver:devops`, `silver:bugfix`):** review triad → verify → secure → validate → quality-gates (pre-ship) → ship.

1. `silver:execute`
2. `silver:review-request`, `silver:review`, and `silver:review-triage` (review triad)
3. `silver:verify`
4. `security` then `silver:secure`
5. `silver:validate`
6. `silver:quality-gates` (pre-ship sweep)
7. `silver:branch-finish` on feature branches
8. `silver:ship`

If any required SB skill cannot be invoked, stop immediately and notify the user. Do not replace missing lifecycle skills with shell-only work, direct edits, or weaker fallback work.

The `workflow-chain-guard.sh` hook enforces only the pre-execution chain at edit time. Completion hooks enforce review, security, verification, artifacts, and ship gates before final delivery.

## Pre-flight: Load Preferences

Read the **User Workflow Preferences** section of `silver-bullet.md` to load user workflow preferences before any other step. Silently apply any stored routing, skip, tool, MultAI, or mode preferences throughout this workflow.

```bash
grep -A 50 "^## [0-9]\+\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner (single line — autonomous default):

```
SB ► feature: {$ARGUMENTS or "(not specified)"} [autonomous]
```

Do not display per-step flow banners or ask for composition approval — the hook
orchestrator (`flow-advance.sh`) starts the workflow tracker and chains flows.

## Composition Proposal

Before beginning execution, read existing artifacts to determine context and propose which flows to include or skip.

### 1. Context Scan

Check the following artifacts and set skip/include flags:

| Artifact | Signal | Action |
|----------|--------|--------|
| `.planning/SPEC.md` exists | Specification already written | Skip FLOW 5 (SPECIFY) |
| `.planning/PLAN.md` files exist for current phase | Planning already done | Skip FLOW 6 (PLAN) |
| `.planning/VERIFICATION.md` exists, passing, and newer than last src change | Verification already done | Skip FLOW 12 (VERIFY) |
| UI files detected in phase scope (*.tsx, *.css, *.html, design/) | UI work in scope | Include FLOW 7 (DESIGN CONTRACT) and FLOW 9 (UI QUALITY) |
| `STATE.md` current phase and completion status | Phase position | Set loop start/end |

```bash
# Read current phase from STATE.md
grep "^current_phase\|^current_plan" .planning/STATE.md 2>/dev/null

# Check for existing SPEC.md
[ -f ".planning/SPEC.md" ] && echo "SPEC exists — skip FLOW 5" || echo "No SPEC — include FLOW 5"

# Check for stale verification (invalidate skip when src changed after VERIFICATION.md)
if [ -f ".planning/VERIFICATION.md" ]; then
  src_pattern=$(jq -r '.project.src_pattern // "/src/"' .silver-bullet.json 2>/dev/null || echo "/src/")
  if find . -type f 2>/dev/null | grep -qE "$src_pattern"; then
    ver_mtime=$(stat -f %m .planning/VERIFICATION.md 2>/dev/null || stat -c %Y .planning/VERIFICATION.md 2>/dev/null || echo 0)
    newer_src=$(find . -type f 2>/dev/null | grep -E "$src_pattern" | while read -r f; do
      stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0
    done | awk -v v="$ver_mtime" '$1 > v { found=1; exit } END { exit !found }')
    if [ "${newer_src:-1}" -eq 0 ]; then
      echo "VERIFICATION.md is stale relative to src changes — include FLOW 12 (VERIFY)"
    fi
  fi
fi

# Check ROADMAP.md for remaining phases in milestone
grep "^\-\s\[\s\]" .planning/ROADMAP.md 2>/dev/null | head -5
```

### 2. Build Flow Chain

Construct the proposed flow chain from the 18-flow catalog (FLOW 1-18), including only relevant flows based on the context scan. Standard full-feature chain:

FLOW 1 (BOOTSTRAP) → FLOW 2 (ORIENT) → FLOW 3 (CLARIFY) → FLOW 4 (DECIDE) [if research/architecture choice needed] → FLOW 5 (SPECIFY) [skip if SPEC.md exists] → FLOW 13 (QUALITY GATE, pre-plan) → FLOW 6 (PLAN) → FLOW 7 (DESIGN CONTRACT) [include if UI] → FLOW 8 (EXECUTE) → FLOW 9 (UI QUALITY) [include if UI] → FLOW 10 (REVIEW) → FLOW 12 (VERIFY) → FLOW 11 (SECURE) → FLOW 13 (QUALITY GATE, pre-ship) → FLOW 14 (SHIP)

Post-execution flows follow the **canonical order**: REVIEW (triad) → VERIFY → SECURE → VALIDATE → QUALITY GATE (pre-ship) → SHIP. This order is identical across `silver:feature`, `silver:ui`, `silver:devops`, and `silver:bugfix`.

### 3. Autonomous composition (default)

The orchestrator auto-confirms composition — **do not** ask `Approve composition?`.
Log one status line only:

```
SB ► composed {N} flows ({skipped} skipped) — orchestrator active
```

Workflow tracking is started by `flow-advance.sh` (not manual bash). If you must
run `workflows.sh` manually, export `SB_WORKFLOW_ID` from its output.

### 6. Legacy manual workflow start (fallback only)

```bash
# Build a comma-separated flow list from the confirmed composition (use the
# user-facing FLOW / PATH names so they match what compliance-status surfaces).
SB_FLOWS="<flow1>,<flow2>,..."   # filled in from the confirmed chain

# Safety: the user's original request ($ARGUMENTS) must be shell-escaped before
# substitution into this command. Use printf '%q' or equivalent when constructing
# the invocation. Never interpolate $ARGUMENTS via direct string concatenation.
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

SB_WORKFLOW_ID=$("$SB_WORKFLOWS_BIN" start /silver:feature "the user's original request" "$SB_FLOWS")
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
  EXECUTE FLOW 6 (PLAN) → FLOW 8 (EXECUTE) → FLOW 10 (REVIEW) → FLOW 12 (VERIFY) → FLOW 11 (SECURE) → FLOW 13 (QUALITY GATE) → FLOW 14 (SHIP)
  INSERT optional flows per composition proposal:
    - FLOW 7 (DESIGN CONTRACT) before FLOW 8 if UI discovered
    - FLOW 9 (UI QUALITY) after FLOW 8 if UI in scope
    - Internal TDD gate within FLOW 8 for behavior-changing implementation plans
    - FLOW 15 (DEBUG) dynamically on execution, CI, test, or verification failure
  TICK ROADMAP.md: update the checkbox for the completed phase from [ ] to [x]
    SB's FLOW 14 (SHIP) handles this as part of phase completion.
    Do NOT edit planning artifacts directly through generic file edits — planning-file-guard.sh will block it.
    If FLOW 14 did not tick the checkbox, use the override bypass:
      touch $HOME/.codex/.silver-bullet/planning-edit-override
      # Edit .planning/ROADMAP.md: change - [ ] **Phase {N}: ... to - [x] **Phase {N}: ... (completed {YYYY-MM-DD})
      rm $HOME/.codex/.silver-bullet/planning-edit-override
    After removing the override, verify it is gone:
      ls -la $HOME/.codex/.silver-bullet/planning-edit-override   # should: No such file
    If the session was interrupted before the rm, clean up manually:
      rm -f $HOME/.codex/.silver-bullet/planning-edit-override
    Session-start cleanup: if a new session starts and $HOME/.codex/.silver-bullet/planning-edit-override
    exists from a prior interrupted session, remove it before proceeding:
      rm -f $HOME/.codex/.silver-bullet/planning-edit-override
    Then include ROADMAP.md in the phase-completion commit (git add .planning/ROADMAP.md)
    NOTE: The roadmap-freshness hook will BLOCK the commit if this step is skipped.
  AFTER phase complete: advance to next phase through SB state
END FOR
```

### 4. Flow Delegation

The existing Step 0 through Step 17 sections below serve as the implementation of each flow in the loop. The supervision loop (next section) runs BETWEEN each flow execution.

## Supervision Loop

The supervision loop runs BETWEEN each flow completion. It checks exit conditions, evaluates composition changes, detects stall, advances, and reports progress. Implement as inline logic at each flow boundary.

Six steps per boundary: **SL-1** exit-condition check → **SL-2** composition re-evaluation (debug/UI insertion triggers) → **SL-3** 4-tier anti-stall detection → **SL-4** advance → **SL-5** progress report → **SL-6** workflow tracker update via the resolved workflow helper.

For full details on each step including stall-detection tiers, heartbeat sentinel, and workflow tracker formats, see **`references/supervision-loop.md`**.

---

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §9b, then commit both files.

**Non-skippable gates:** `security`, `silver:quality-gates` pre-ship, `silver:verify`. Refuse skip requests for these regardless of §10.

## Step 0: Complexity Triage

Before proceeding, classify the request:

| Classification | Signals | Action |
|----------------|---------|--------|
| Trivial | ≤3 files, typo, config, rename | STOP — route to `silver:fast` instead |
| Fuzzy | Vague intent, unclear scope | Continue to Step 1b (silver:clarify) |
| Simple | Clear scope, ≤1 phase | Skip Step 1b, go to Step 1a |
| Complex | Multi-phase, cross-cutting | Full workflow including Step 1b |

If trivial: invoke `silver:fast` through the active runtime's SB-recognized skill invocation channel and exit this workflow.

## Step 1a: Codebase Intel

Invoke `silver:scan` through the active runtime's SB-recognized skill invocation channel for rapid SB orientation.

If no current codebase intel exists and this is a brownfield project, run a deeper `silver:scan` pass focused on architecture, dependencies, tests, and likely blast radius.

## Step 1b: Fuzzy Scope Clarification (conditional)

**Only if complexity triage found fuzzy intent or $ARGUMENTS is empty:**

Invoke `silver:clarify` through the active runtime's SB-recognized skill invocation channel for Socratic framing, option comparison, and decision-ready handoff before planning.

## Step 1c: MultAI Pre-Spec Review (conditional)

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

If A: invoke the installed multi-AI research/orchestration skill if available. Note: this step informs the spec PRE-implementation. Step 8c external second-opinion review reviews completed code POST-execution. Both are independent. If no multi-AI skill is installed, continue only if the user approves the degraded path.

## Step 1d: Specify (FLOW 5 — greenfield / missing SPEC)

**Conditional gate — only when `.planning/SPEC.md` does not exist for the current milestone (greenfield, or a new milestone without a spec).** Skip when SPEC.md already exists (matches the FLOW 5 skip signal in the Composition Proposal).

```bash
[ -f ".planning/SPEC.md" ] && echo "SPEC exists — skip FLOW 5 (Step 1d)" || echo "No SPEC — run FLOW 5 (Step 1d)"
```

Invoke `silver:spec` through the active runtime's SB-recognized skill invocation channel. Purpose: AI-guided Socratic spec elicitation producing `.planning/SPEC.md` (and `.planning/REQUIREMENTS.md`) before quality gates, context, and planning. This makes the FLOW 5 (SPECIFY) node in the composition an explicit, invokable step rather than an implicit one — a greenfield feature must not proceed to planning without a written spec.

After silver:spec completes, the spec is the authoritative input for Step 3 (quality gates), Step 4 (context), and Step 6 (plan).

## Step 2: Testing Strategy

Capture test levels, tooling, and coverage targets inside `silver:plan`. Use `verify-tests` when fresh suite execution is needed. Do not require the old Engineering `testing-strategy` plugin.

## Step 2.5: Writing Plans

Keep implementation planning inside `silver:plan`. SB planning owns task shape, dependencies, verification criteria, and execution handoff.

## Step 3: Pre-Plan Quality Gates (8 core dimensions + conditional gates)

Invoke `silver:quality-gates` through the active runtime's SB-recognized skill invocation channel. Purpose: 8 core dimensions — reliability, security, scalability, usability, testability, modularity, reusability, extensibility — plus conditional AI/LLM safety when the phase includes AI behavior and `devops-quality-gates` for infra-touching changes.

`security` is always mandatory regardless of §10 preferences. `testability` is embedded in silver:quality-gates (one of the core dimensions — not a separate step).

## Step 4: Discuss Phase

Invoke `silver:context` through the active runtime's SB-recognized skill invocation channel. Purpose: adaptive questioning, locked decisions, assumptions, dependencies, and CONTEXT.md handoff for the planner.

## Step 5: Analyze Dependencies

Dependency analysis is part of `silver:plan`. Before invoking it, gather dependency signals from SPEC.md, CONTEXT.md, ROADMAP.md, prior SUMMARY.md files, package manifests, schema/migration files, API boundaries, and touched services.

## Step 6: Plan Phase

Invoke `silver:plan` through the active runtime's SB-recognized skill invocation channel. Purpose: PLAN.md with assumptions, dependencies, task waves, TDD policy, acceptance criteria traceability, and verification loop.

## Step 6b: Pre-Build Validation

**NON-SKIPPABLE GATE.** (VALD-03 compliance)

This runs **after** Step 6 (Plan Phase) because `silver:validate` performs pre-build gap analysis by checking SPEC.md coverage in `.planning/PLAN.md` — the plan must exist first. (Previously this gate was misordered before planning, when no PLAN.md existed yet.)

Invoke `silver:validate` through the active runtime's SB-recognized skill invocation channel.

If silver:validate reports any BLOCK findings:
- STOP. Do not proceed to Step 7 (Execute).
- Display: "Pre-build validation found BLOCK findings. Resolve them before continuing."
- Offer: A. Return to `silver:plan` to revise the plan  B. Re-run `silver:validate` after fixes

Only proceed to Step 7 (Execute Phase) when silver:validate reports zero BLOCK findings.

WARN findings are recorded in `.planning/VALIDATION.md` and will appear in the PR description (VALD-04).

## Step 7: Execute Phase

**If mode is Interactive (default):**
- For implementation plans, invoke `silver:execute` through the active runtime's SB-recognized skill invocation channel. The `tdd` gate runs before code edits.
- For config-only, docs-only, or infra-only plans, invoke `silver:execute` with the non-application-TDD rationale recorded in SUMMARY.md.

**If mode is Autonomous (§10e):** invoke `silver:execute` with autonomous mode context. Autonomous execution still obeys the same TDD, verification, deferred-item, and artifact gates.

**Internal TDD gate:** `tdd` is hidden from the picker and activates immediately before the execution wave for implementation plans. It is now an SB-owned TDD policy skill.

**Error path:** If execution fails mid-wave, do NOT mark the phase complete. Route to `silver:bugfix` through the active runtime's SB-recognized skill invocation channel for triage (Step 0 classification). Return here only after bugfix confirms the root cause is resolved.

**During-execution deferred capture:** While executing, any item that is skipped, descoped, or explicitly deferred (e.g., "skipping X for now", "out of scope", "future optimization") MUST be added to the backlog before moving to the next task — not at the end of the session. Do not accumulate deferred items silently.

**Deferred item routing:** File immediately via `/silver:add`:

```
Skill(skill="silver:add", args="<description of deferred item>")
```

> **Canonical post-execution order:** review triad (Steps 8a–8e) → verify (Step 9) → security + secure (Steps 10–11) → validate (Step 12) → pre-ship quality gates (Step 13) → ship (Step 15). This sequence is identical across `silver:feature`, `silver:ui`, `silver:devops`, and `silver:bugfix`.

## Step 8a: Request Code Review

Invoke `silver:review-request` through the active runtime's SB-recognized skill invocation channel. Purpose: frame review scope, risks, artifacts, and blocker criteria before review begins.

## Step 8b: Run Code Review

Invoke `silver:review` through the active runtime's SB-recognized skill invocation channel. Purpose: create or update REVIEW.md. This is the authoritative project code-review artifact; optional external review helpers must feed into this artifact rather than replace it.

If issues are found in REVIEW.md: fix BLOCK findings through `silver:execute` or the active implementation workflow, then re-run `silver:review`.

## Step 8c: Cross-AI Review (conditional)

**Only for architecturally significant changes or user request:**

Invoke the configured external second-opinion review mechanism only if available and explicitly selected. Purpose: cross-AI adversarial peer review of completed code. Distinct from Step 1d (pre-spec MultAI) — this reviews post-execution code and feeds findings back into REVIEW.md.

## Step 8d: Receive Review

Invoke `silver:review-triage` through the active runtime's SB-recognized skill invocation channel. Purpose: disciplined response to findings — no blind agreement and no silent dismissal.

## Step 8e: Backlog capture from review

After receiving review findings, scan REVIEW.md for any low-priority, deferred, or advisory items that were not fixed. **Every such item must be added to the SB backlog immediately** — do not silently drop them.

For each unfixed non-blocking finding:
```
Skill(skill="silver:add", args="<finding description from REVIEW.md>")
```

If all findings were fixed or no advisory items exist, output: "No deferred review items to capture."

## Step 9: Verify Work

Invoke `silver:verify` through the active runtime's SB-recognized skill invocation channel. Purpose: UAT, must-haves, artifact checks, test freshness, and completion evidence. Phase is NOT complete until this passes. Non-skippable.

## Step 9b: Test Gap Fill + Fresh Test Run

**Test gap fill (conditional):** If `silver:verify` surfaces coverage gaps, return to `silver:execute` with a test-gap task to add tests from UAT criteria.

**Fresh test execution (required before delivery):** Invoke `verify-tests` to run the project's test gate and record the freshness marker. `verify-tests` is part of `required_deploy`, so the completion-audit deploy gate blocks PR/release/deploy until a fresh run is recorded. This is also re-confirmed at Step 15b (`silver:ship`); run it here so the verify→ship chain has a fresh marker on the shipped tree.

## Step 10: Security Review

Invoke `security` through the active runtime's SB-recognized skill invocation channel. Non-skippable gate.

## Step 11: Secure Phase

Invoke `silver:secure` through the active runtime's SB-recognized skill invocation channel. Purpose: retroactive threat mitigation verification and security artifact update.

## Step 12: Validate Phase

Invoke `silver:validate` through the active runtime's SB-recognized skill invocation channel. Purpose: validation gap filling and pre-ship consistency check.

## Step 12b: Tech Debt Review

Invoke `tech-debt` through the active runtime's SB-recognized skill invocation channel when available. Purpose: identify and document any technical debt introduced during this phase — decisions made for speed, known shortcuts, deferred refactors. Items that cannot be addressed now MUST be captured via `/silver:add`.

## Step 13: Pre-Ship Quality Gates (8 core dimensions + conditional gates)

Invoke `silver:quality-gates` through the active runtime's SB-recognized skill invocation channel. Purpose: full 8-core-dimension sweep, plus conditional AI/LLM and DevOps gates where applicable, before shipping. Non-skippable gate.

## Step 13b: Doc-Scheme Compliance (conditional)

**Only if `docs/doc-scheme.md` exists in the project:**

```bash
[ -f "docs/doc-scheme.md" ] && [ -f "docs/doc-scheme.json" ] && echo "Doc-scheme gate required" || echo "Doc scheme missing/incomplete — run /silver:ensure-docs --recover-scheme"
```

Before raising the PR, verify documentation is up to date per the scheme:

1. **`docs/CHANGELOG.md`** — must have an entry for the phase just completed (newest-first). If missing, write it now: one entry summarising what shipped.
2. **`docs/knowledge/YYYY-MM.md`** (current month) — append task-specific patterns, gotchas, and key decisions.
3. **`docs/learnings/YYYY-MM.md`** (current month) — append portable learnings.
4. Update any additional docs changed by the phase (`ARCHITECTURE.md`, `TESTING.md`, runbooks, workflows, etc.) so content matches current behavior.
5. **`docs/task-doc-checklist.json`** — must include `task_granularity` and full status coverage for every key in `docs/doc-scheme.json -> required_docs`, plus any required section entries declared under `required_sections`.

**Gate:** Do NOT proceed to Step 14 until all checklist/doc checks pass. Missing checklist keys or stale `updated` claims are pre-ship defects.

If `docs/doc-scheme.md`/`docs/doc-scheme.json` are missing, recover via `/silver:ensure-docs --recover-scheme`, then complete this step before proceeding to Step 14.

## Step 14: Finishing Branch

Invoke `silver:branch-finish` through the active runtime's SB-recognized skill invocation channel. Purpose: merge / PR / cleanup decision, branch hygiene, and gate readiness.

## Step 15a: PR Branch (ask user)

Ask user:

> Would you like a clean PR branch (strips .planning/ commits)?
>
> A. Yes — ask `silver:ship` to prepare a clean PR branch  B. No — ship as-is  C. Save as permanent preference

If A: pass the clean-PR-branch preference to `silver:ship`.
If C: record preference in silver-bullet.md §10e and templates/silver-bullet.md.base §9e, commit both.

## Step 15b: Ship Phase

Invoke `silver:ship` through the active runtime's SB-recognized skill invocation channel. Purpose: push branch, create PR, prepare for merge (phase-level). This is phase-level merge — not milestone-level publish (that is `silver:release`).

## Step 16: Episodic Memory

Invoke `episodic-memory:remembering-conversations` through the active runtime's SB-recognized skill invocation channel to record key decisions and learnings from this feature.

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

Write `.planning/UAT.md` using the active runtime file-writing mechanism.

### Step 17.0a: Review UAT.md

Invoke `/artifact-reviewer .planning/UAT.md --reviewer review-uat` through the active runtime's SB-recognized skill invocation channel.

Do NOT proceed to `silver:release` until /artifact-reviewer reports 2 consecutive clean passes. If issues are found, /artifact-reviewer will apply fixes and re-review automatically. If /artifact-reviewer surfaces an unresolvable issue after 5 rounds, STOP and present it to the user.

### Step 17.0b: Cross-Artifact Consistency Review

Invoke `/artifact-reviewer --reviewer review-cross-artifact --artifacts .planning/SPEC.md .planning/REQUIREMENTS.md .planning/ROADMAP.md` (add `.planning/DESIGN.md` if it exists).

Do NOT proceed to `silver:release` until cross-artifact review reports clean pass. If ISSUES_FOUND, the orchestrator applies fixes and re-reviews per the review loop. If unresolvable after 5 rounds, STOP and present to the user.

**Why here:** Cross-artifact alignment must be confirmed before milestone audit begins — auditing against misaligned artifacts wastes effort.

Invoke `silver:release` with milestone-completion context. It owns UAT audit, milestone audit, gap planning, gap phases, archive, changelog, and release publication decisions.

## Step 18: Post-work backlog capture (mandatory)

After all work for this feature/phase is complete, perform a final deferred-item sweep:

1. Review all CONTEXT.md `<deferred>` sections from phases worked on in this session
2. Review any items marked "future", "TODO", "later", or "out of scope" in SUMMARYs, PLANs, or discussion
3. Review any items explicitly deferred during execution (e.g., "skipping X for now")

**Every deferred item that has not yet been captured must be added now** via `/silver:add`:
```
Skill(skill="silver:add", args="<deferred item description>")
```

If no items were deferred during this session, output: "Post-work sweep: no deferred items to capture."

**This step is non-negotiable.** Items deferred during execution and not captured here are permanently lost.

## Additional Resources

### Reference Files

- **`references/supervision-loop.md`** — Full supervision loop step details (SL-1 through SL-6), anti-stall tiers, heartbeat sentinel, workflow tracker formats
