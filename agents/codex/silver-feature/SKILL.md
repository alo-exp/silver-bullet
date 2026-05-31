---
name: silver:feature
description: >
  This skill should be used for full SB-orchestrated feature development workflow: orient → clarify/decide → silver:quality-gates → GSD plan/execute/verify → ship
argument-hint: "<feature description>"
version: 0.1.0
---

# /silver:feature — Feature Development Workflow

SB Agentic Process Orchestrator for new feature development. It dynamically composes SB quality contracts around the GSD phase lifecycle. GSD remains the execution backbone; Superpowers and other dependency plugins are invoked only when a selected SB flow explicitly requires them.

Never implements features directly — orchestrates only.

## Mandatory dependency execution

SB separates pre-execution gates from post-execution gates.

Before implementation edits, the execution trace must show only the pre-execution dependency chain that unlocks GSD execution:

1. `gsd-scan` when rapid SB orientation is useful
2. `gsd-map-codebase` when the project is brownfield or deep codebase mapping is needed
3. `silver:clarify` when scope is fuzzy
4. `silver:research` when FLOW DECIDE is needed for architecture, stack, API, or data-model choices
5. `silver:quality-gates`
6. `gsd:discuss-phase`
7. `gsd:plan-phase`

After implementation, final delivery requires the post-execution chain:

1. `gsd:execute-phase` or `gsd:autonomous`
2. `gsd:verify-work`
3. `gsd-code-review` and review triage/fix steps
4. `gsd-secure-phase`
5. `gsd-validate-phase`
6. `gsd-ship`

If any required downstream skill cannot be invoked, stop immediately and notify the user. Offer install-and-retry first. Do not replace missing dependency skills with shell reconnaissance, direct edits, or other fallback work.

The `workflow-chain-guard.sh` hook enforces only the pre-execution chain at edit time. Completion hooks enforce review, security, verification, artifacts, and ship gates before final delivery.

## Pre-flight: Load Preferences

Read the **User Workflow Preferences** section of `silver-bullet.md` to load user workflow preferences before any other step. Silently apply any stored routing, skip, tool, MultAI, or mode preferences throughout this workflow.

```bash
grep -A 50 "^## [0-9]\+\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
SILVER BULLET ► FEATURE WORKFLOW

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

FLOW 0 (BOOTSTRAP) → FLOW 1 (ORIENT) → FLOW 2 (CLARIFY) → FLOW 3 (DECIDE) [if research/architecture choice needed] → FLOW 4 (SPECIFY) [skip if SPEC.md exists] → FLOW 12 (QUALITY GATE, pre-plan) → FLOW 5 (PLAN) → FLOW 6 (DESIGN CONTRACT) [include if UI] → FLOW 7 (EXECUTE) → FLOW 8 (UI QUALITY) [include if UI] → FLOW 9 (REVIEW) → FLOW 10 (SECURE) → FLOW 11 (VERIFY) → FLOW 12 (QUALITY GATE, pre-ship) → FLOW 13 (SHIP)

### 3. Display Proposal

Display the composition proposal to the user:

```
SILVER BULLET ► FLOW COMPOSED
Flows: BOOTSTRAP → ORIENT → PLAN → ...
Skipped: SPECIFY — SPEC.md exists
Phase loop: Phases {start}-{end} (from ROADMAP)
Approve composition? [Y/n]
```

### 4. Auto-Confirm in Autonomous Mode

In autonomous mode (§10e), auto-confirm the composition proposal with a log message:

```
⚡ Autonomous mode: auto-confirming composition — {flow count} flows, {skipped count} skipped
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

# Safety: the user's original request ($ARGUMENTS) must be shell-escaped before
# substitution into this command. Use printf '%q' or equivalent when constructing
# the invocation. Never interpolate $ARGUMENTS via direct string concatenation.
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
  EXECUTE FLOW 5 (PLAN) → FLOW 7 (EXECUTE) → FLOW 9 (REVIEW) → FLOW 10 (SECURE) → FLOW 11 (VERIFY) → FLOW 12 (QUALITY GATE) → FLOW 13 (SHIP)
  INSERT optional flows per composition proposal:
    - FLOW 6 (DESIGN CONTRACT) before FLOW 7 if UI discovered
    - FLOW 8 (UI QUALITY) after FLOW 7 if UI in scope
    - Internal TDD gate within FLOW 7 for behavior-changing implementation plans
    - FLOW 14 (DEBUG) dynamically on execution, CI, test, or verification failure
  TICK ROADMAP.md: update the checkbox for the completed phase from [ ] to [x]
    GSD's FLOW 13 (SHIP) handles this as part of phase completion.
    Do NOT use the Edit tool directly — planning-file-guard.sh will block it.
    If FLOW 13 did not tick the checkbox, use the override bypass:
      touch ~/.codex/.silver-bullet/planning-edit-override
      # Edit .planning/ROADMAP.md: change - [ ] **Phase {N}: ... to - [x] **Phase {N}: ... (completed {YYYY-MM-DD})
      rm ~/.codex/.silver-bullet/planning-edit-override
    After removing the override, verify it is gone:
      ls -la ~/.codex/.silver-bullet/planning-edit-override   # should: No such file
    If the session was interrupted before the rm, clean up manually:
      rm -f ~/.codex/.silver-bullet/planning-edit-override
    Session-start cleanup: if a new session starts and ~/.codex/.silver-bullet/planning-edit-override
    exists from a prior interrupted session, remove it before proceeding:
      rm -f ~/.codex/.silver-bullet/planning-edit-override
    Then include ROADMAP.md in the phase-completion commit (git add .planning/ROADMAP.md)
    NOTE: The roadmap-freshness hook will BLOCK the commit if this step is skipped.
  AFTER phase complete: advance to next phase through GSD state
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

**Non-skippable gates:** `security`, `silver:quality-gates` pre-ship, `gsd-verify-work`. Refuse skip requests for these regardless of §10.

## Step 0: Complexity Triage

Before proceeding, classify the request:

| Classification | Signals | Action |
|----------------|---------|--------|
| Trivial | ≤3 files, typo, config, rename | STOP — route to `silver:fast` instead |
| Fuzzy | Vague intent, unclear scope | Continue to Step 1b (silver:clarify) |
| Simple | Clear scope, ≤1 phase | Skip Step 1b, go to Step 1a |
| Complex | Multi-phase, cross-cutting | Full workflow including Step 1b |

If trivial: invoke `silver:fast` via the Skill tool and exit this workflow.

## Step 1a: Codebase Intel

Invoke `gsd-scan` via the Skill tool for rapid SB orientation.

If no current codebase intel exists and this is a brownfield project, invoke `gsd-map-codebase` via the Skill tool for deeper GSD-managed mapping.

## Step 1b: Fuzzy Scope Clarification (conditional)

**Only if complexity triage found fuzzy intent or $ARGUMENTS is empty:**

Invoke `silver:clarify` via the Skill tool for Socratic framing, option comparison, and decision-ready handoff before planning.

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

If A: invoke the installed multi-AI research/orchestration skill if available. Note: this step informs the spec PRE-implementation. Step 9c (`gsd:review --all`) reviews completed code POST-execution. Both are independent. If no multi-AI skill is installed, continue only if the user approves the degraded path.

## Step 2: Testing Strategy

Invoke `testing-strategy` via the Skill tool when the dependency is installed. Purpose: define test levels, tooling, coverage targets before GSD planning. If unavailable, capture test strategy in GSD discuss/plan artifacts instead of inventing an untracked substitute.

## Step 2.5: Writing Plans

Keep implementation planning inside `gsd:plan-phase` by default. If the selected SB flow explicitly needs Superpowers plan-writing discipline, invoke `superpowers:writing-plans` via the Skill tool; SB does not package a local `writing-plans` skill.

## Step 2.7: Pre-Build Validation

**NON-SKIPPABLE GATE.** (VALD-03 compliance)

Invoke `silver:validate` via the Skill tool.

If silver:validate reports any BLOCK findings:
- STOP. Do not proceed to Step 3.
- Display: "Pre-build validation found BLOCK findings. Resolve them before continuing."
- Offer: A. Return to /silver:spec  B. Re-run /silver:validate after fixes

Only proceed to Step 3 (silver:quality-gates) when silver:validate reports zero BLOCK findings.

WARN findings are recorded in .planning/VALIDATION.md and will appear in the PR description (VALD-04).

## Step 3: Pre-Plan Quality Gates (8 core dimensions + conditional gates)

Invoke `silver:quality-gates` via the Skill tool. Purpose: 8 core dimensions — reliability, security, scalability, usability, testability, modularity, reusability, extensibility — plus conditional AI/LLM safety when the phase includes AI behavior and `devops-quality-gates` for infra-touching changes.

`security` is always mandatory regardless of §10 preferences. `testability` is embedded in silver:quality-gates (one of the core dimensions — not a separate step).

## Step 4: Discuss Phase

Invoke `gsd-discuss-phase` via the Skill tool. Purpose: adaptive questioning → CONTEXT.md with locked decisions for the planner.

## Step 5: Analyze Dependencies

Invoke `gsd-analyze-dependencies` via the Skill tool. Purpose: map phase dependencies before GSD creates the plan.

## Step 6: Plan Phase

Invoke `gsd-plan-phase` via the Skill tool. Purpose: PLAN.md with verification loop.

## Step 7: Execute Phase

**If mode is Interactive (default):**
- For implementation plans, invoke `gsd-execute-phase --tdd` via the Skill tool.
- For config-only, docs-only, or infra-only plans, invoke `gsd-execute-phase` without `--tdd`.

**If mode is Autonomous (§10e):** invoke `gsd-autonomous` via the Skill tool. For implementation plans, only use Autonomous when the underlying GSD TDD mode is already enabled; otherwise fall back to Interactive so the internal `tdd` gate can run before execution.

**Internal TDD gate:** `tdd` is hidden from the picker and activates immediately before the execution wave for implementation plans. It delegates to `superpowers:test-driven-development`, so Superpowers is used only at this explicit SB execution boundary.

**Error path:** If execution fails mid-wave, do NOT mark the phase complete. Route to `silver:bugfix` via the Skill tool for triage (Step 0 classification). Return here only after bugfix confirms the root cause is resolved.

**During-execution deferred capture:** While executing, any item that is skipped, descoped, or explicitly deferred (e.g., "skipping X for now", "out of scope", "future optimization") MUST be added to the backlog before moving to the next task — not at the end of the session. Do not accumulate deferred items silently.

**Deferred item routing:** File immediately via `/silver:add`:

```
Skill(skill="silver:add", args="<description of deferred item>")
```

## Step 8: Verify Work

Invoke `gsd-verify-work` via the Skill tool. Purpose: UAT, must-haves, artifact checks. Phase is NOT complete until this passes. Non-skippable.

## Step 8b: Test Gap Fill (conditional)

**Only if gsd-verify-work surfaces coverage gaps:**

Invoke `gsd-add-tests` via the Skill tool. Purpose: generate tests from UAT criteria to fill gaps identified by verification — runs after gsd-verify-work so gap targets are known.

## Step 9a: Request Code Review

Invoke `requesting-code-review` (superpowers:requesting-code-review) via the Skill tool. Purpose: frame review scope and focus rigorously before spawning reviewers.

## Step 9b: Run Code Review

Invoke `gsd-code-review` via the Skill tool. Purpose: spawn reviewer agents → REVIEW.md. This is the authoritative project code-review artifact; optional external review helpers must feed into this artifact rather than replace it.

If issues found in REVIEW.md: invoke `gsd-code-review-fix` via the Skill tool to auto-fix findings atomically before human review.

## Step 9c: Cross-AI Review (conditional)

**Only for architecturally significant changes or user request:**

Invoke `gsd-review --all` via the Skill tool. Purpose: cross-AI adversarial peer review of completed code. Distinct from Step 1d (pre-spec MultAI) — this reviews post-execution code. The `--all` flag fans out to every available external CLI (Gemini, Claude, Codex, OpenCode, Qwen, Cursor).

## Step 9d: Receive Review

Invoke `receiving-code-review` (superpowers:receiving-code-review) via the Skill tool. Purpose: disciplined response to findings — no blind agreement.

## Step 9e: Backlog capture from review

After receiving review findings, scan REVIEW.md for any low-priority, deferred, or advisory items that were not fixed. **Every such item must be added to the GSD backlog immediately** — do not silently drop them.

For each unfixed non-blocking finding:
```
Skill(skill="silver:add", args="<finding description from REVIEW.md>")
```

If all findings were fixed or no advisory items exist, output: "No deferred review items to capture."

## Step 10: Security Review

Invoke `security` via the Skill tool. Non-skippable gate.

## Step 11: Secure Phase

Invoke `gsd-secure-phase` via the Skill tool. Purpose: retroactive threat mitigation verification.

## Step 12: Validate Phase

Invoke `gsd-validate-phase` via the Skill tool. Purpose: Nyquist validation gap filling.

## Step 12b: Tech Debt Review

Invoke `tech-debt` via the Skill tool when available. Purpose: identify and document any technical debt introduced during this phase — decisions made for speed, known shortcuts, deferred refactors. Items that cannot be addressed now MUST be captured via `/silver:add`.

## Step 13: Pre-Ship Quality Gates (8 core dimensions + conditional gates)

Invoke `silver:quality-gates` via the Skill tool. Purpose: full 8-core-dimension sweep, plus conditional AI/LLM and DevOps gates where applicable, before shipping. Non-skippable gate.

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

Invoke `superpowers:finishing-a-development-branch` via the Skill tool. Purpose: merge / PR / cleanup decision; SB does not package a local `finishing-branch` skill.

## Step 15a: PR Branch (ask user)

Ask user:

> Would you like a clean PR branch (strips .planning/ commits)?
>
> A. Yes — run gsd-pr-branch  B. No — ship as-is  C. Save as permanent preference

If A: invoke `gsd-pr-branch` via the Skill tool.
If C: record preference in silver-bullet.md §10e and templates/silver-bullet.md.base §9e, commit both.

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

**Every deferred item that has not yet been captured must be added now** via `/silver:add`:
```
Skill(skill="silver:add", args="<deferred item description>")
```

If no items were deferred during this session, output: "Post-work sweep: no deferred items to capture."

**This step is non-negotiable.** Items deferred during execution and not captured here are permanently lost.

## Additional Resources

### Reference Files

- **`references/supervision-loop.md`** — Full supervision loop step details (SL-1 through SL-6), anti-stall tiers, heartbeat sentinel, workflow tracker formats
