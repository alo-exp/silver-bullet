---
name: "silver:bugfix"
title: "Bugfix"
description: >
  This skill should be used for SB-orchestrated bug investigation and fix: triage → path A/B/C → plan → TDD regression test → execute → review → verify → ship
argument-hint: "<description of the bug or failure>"
version: 0.1.0
---

# /silver:bugfix — Bugfix Composition Spec

SB **queue builder** for bugs and regressions. Parent orchestrator spawns Task workers per flow — does not fix inline.

Never implements fixes directly — composition spec only.

## Pre-flight: Load Preferences

Read the **User Workflow Preferences** section of `silver-bullet.md` to load user workflow preferences before any other step.

```bash
grep -A 50 "^## [0-9]\+\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
SILVER BULLET ► BUGFIX WORKFLOW

Symptom: {$ARGUMENTS or "(not specified)"}
```

## Composition Proposal

Before beginning execution, read existing artifacts to determine context and propose which flows to include or skip.

### 1. Context Scan

Check the following artifacts and set skip/include flags:

| Artifact | Signal | Action |
|----------|--------|--------|
| `.planning/` directory exists | Project already bootstrapped | Skip FLOW 1 (BOOTSTRAP) |
| `.planning/STATE.md` exists | SB state present | Skip FLOW 1 (BOOTSTRAP) |

```bash
# Check for existing planning artifacts
[ -d ".planning" ] && echo "SKIP FLOW 1 — .planning/ exists" || echo "Include FLOW 1"
```

### 2. Build Flow Chain

Construct the proposed flow chain for bugfix triage. Bugfix is single-phase by design — no per-phase loop. Default chain:

FLOW 2 (ORIENT) → FLOW 15 (DEBUG) [always included — this is a bugfix] → FLOW 6 (PLAN) → FLOW 8 (EXECUTE) → FLOW 10 (REVIEW) → FLOW 11 (SECURE) → FLOW 12 (VERIFY) → FLOW 13 (QUALITY GATE) → FLOW 14 (SHIP)

Note: FLOW 15 (DEBUG) is always included for any bugfix engagement. FLOW 1 (BOOTSTRAP) is skipped when `.planning/` already exists.

### 3. Display Proposal

Display the composition proposal to the user:

```
SILVER BULLET ► FLOW COMPOSED
Flows: ORIENT → DEBUG → PLAN → EXECUTE → REVIEW → VERIFY → SECURITY → SECURE → VALIDATE → QUALITY GATE → BRANCH-FINISH → COMPLETION-AUDIT → SHIP
Skipped: BOOTSTRAP — .planning/ exists
```

### 4. Autonomous composition (default)

Do **not** ask `Approve composition?`. Log: `SB ► bugfix composed {N} paths — orchestrator active`.
Workflow tracking is started by `flow-advance.sh`.

### 5. Legacy manual workflow start (fallback only)

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

SB_WORKFLOW_ID=$("$SB_WORKFLOWS_BIN" start /silver:bugfix "the bug description ($ARGUMENTS)" "$SB_FLOWS")
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

**Non-skippable gates:** `security`, `silver:quality-gates` pre-ship, `silver:verify`.

## Step 0: Triage — Classify Failure Type

Ask the user directly:

> What best describes this failure?
>
> A. Known symptom, unknown fix — I can observe the bug but don't know the root cause
> B. Unknown cause — session history is unclear, need to reconstruct what happened
> C. Failed SB lifecycle workflow specifically — a plan, execution phase, or SB workflow failed

Wait for selection, then route to the corresponding path below.

## Path 1A: Known Symptom, Unknown Fix

Invoked when: triage selects A, OR after Path 1B/1C silver:forensics completes and hands off here.

**1A.1 — Systematic debugging hypothesis**
Invoke `silver:debug` through the active runtime's SB-recognized skill invocation channel. Purpose: structure the debugging hypothesis before executing investigation — ensures systematic approach before diving into code.

**1A.2 — Persistent debugging investigation**
Continue in `silver:debug` until root cause, reproduction, and regression guard are evidenced.

After `silver:debug` completes, proceed to Step 2 (TDD).

## Path 1B: Unknown Cause, Needs Reconstruction

Invoked when: triage selects B.

**1B.1 — Forensic cause reconstruction**
Invoke `silver:forensics` through the active runtime's SB-recognized skill invocation channel. Purpose: SB-owned silver:forensics skill (skills/silver-forensics/SKILL.md) — reconstructs cause from git history, artifacts, and state. Outputs a cause classification report.

After silver:forensics completes and outputs the cause classification:
→ Hand off to Path 1A (start at Step 1A.1 with the reconstructed context).

## Path 1C: Failed SB Lifecycle Workflow

Invoked when: triage selects C.

**1C.1 — SB lifecycle post-mortem**
Invoke `silver:forensics` through the active runtime's SB-recognized skill invocation channel. Purpose: SB-owned post-mortem for failed lifecycle workflows (failed plans, broken state, incomplete phases). Outputs diagnosis.

After `silver:forensics` completes and outputs diagnosis:
→ Hand off to Path 1A (start at Step 1A.1 with the diagnosis context).

## Step 2: Plan the Fix

All paths converge here. Invoke `silver:plan` through the active runtime's SB-recognized skill invocation channel (lightweight, 1-2 tasks only — this is a fix, not a feature).

Planning precedes the regression test so the pre-execution chain (DEBUG → PLAN) is
recorded before the first edit — this is exactly what `workflow-chain-guard.sh`
enforces for the bugfix composition.

## Step 3: TDD — Write Regression Test First

Before writing any fix code:

Invoke `tdd` through the active runtime's SB-recognized skill invocation channel. Purpose: write a failing regression test first — RED must appear before writing any fix. This satisfies the hidden SB TDD gate before any fix code is written and ensures the bug cannot silently regress.

**Enforcement:** Do not proceed to Step 4 until the test is red (failing for the right reason).

## Step 4: Execute Fix + Verify Green

Invoke `silver:execute` through the active runtime's SB-recognized skill invocation channel. After execution, verify the regression test from Step 3 is now green.

## Step 5: Code Review

Run the full review sequence in order:

1. Invoke `silver:review-request` through the active runtime's SB-recognized skill invocation channel.
2. Invoke `silver:review` through the active runtime's SB-recognized skill invocation channel. This creates the authoritative REVIEW.md artifact; optional external review helpers must feed into this artifact rather than replace it.
3. Invoke `silver:review-triage` through the active runtime's SB-recognized skill invocation channel.

## Step 6: Verify Work

Invoke `silver:verify` through the active runtime's SB-recognized skill invocation channel. Purpose: confirm fix, zero regression. Non-skippable.

**Fresh test execution (required before delivery):** Invoke `verify-tests` to run the project's test gate and record the freshness marker — it is part of `required_deploy`, so the completion-audit deploy gate blocks ship until a fresh run is recorded. The regression test written in Step 3 must be green.

## Step 7: Security Review

Invoke `security` through the active runtime's SB-recognized skill invocation channel. Non-skippable. Then invoke `silver:secure` for retroactive threat-mitigation verification — both `security` and `silver-secure` are part of `required_deploy`, so the completion-audit deploy gate blocks ship until both are recorded.

> **Canonical post-execution order:** review (Step 5) → verify (Step 6) → security + secure (Step 7) → quality gates (Step 7b) → validate (Step 7c) → branch-finish (Step 7d) → completion-audit (Step 7e) → ship (Step 8). This sequence matches `silver:feature`, `silver:ui`, and `silver:devops`.

## Step 7a: Tech Debt Review

Invoke `tech-debt` through the active runtime's SB-recognized skill invocation channel when available. Purpose: identify and document any technical debt introduced by the fix. Items not addressed now MUST be captured via `/silver:add`.

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

## Step 7b: Quality Gates

Invoke `silver:quality-gates` through the active runtime's SB-recognized skill invocation channel (affected quality dimensions for the changed code). Non-skippable.

## Step 7c: Validate Phase

Invoke `silver:validate` through the active runtime's SB-recognized skill invocation channel. Purpose: pre-ship validation gap filling and consistency check.

## Step 7d: Finishing Branch

On non-main branches, invoke `silver:branch-finish` through the active runtime's SB-recognized skill invocation channel before ship.

## Step 7e: Completion Audit

Invoke `silver:completion-audit` through the active runtime's SB-recognized skill invocation channel immediately before ship. Purpose: verify completion claims and evidence are substantive — required by `required_deploy` and must be recorded before `gh pr create`.

## Step 7f: Doc-Scheme Compliance (conditional)

**Only if `docs/doc-scheme.md` exists in the project:**

```bash
[ -f "docs/doc-scheme.md" ] && [ -f "docs/doc-scheme.json" ] && echo "Doc-scheme gate required" || echo "Doc scheme missing/incomplete — run /silver:ensure-docs --recover-scheme"
```

Before raising the PR, verify documentation is up to date per the scheme:

1. **`docs/CHANGELOG.md`** — must have an entry for this fix (newest-first). If missing, write it now.
2. **`docs/knowledge/YYYY-MM.md`** (current month) — append root-cause patterns, gotchas, and decisions found during diagnosis.
3. **`docs/learnings/YYYY-MM.md`** (current month) — append portable learnings during diagnosis.
4. Update any additional docs changed by the fix (`ARCHITECTURE.md`, `TESTING.md`, runbooks, workflows, etc.) so content matches current behavior.
5. **`docs/task-doc-checklist.json`** — must include `task_granularity` and full status coverage for every key in `docs/doc-scheme.json -> required_docs`, plus any required section entries declared under `required_sections`.

**Gate:** Do NOT proceed to Step 8 until all checklist/doc checks pass. Missing checklist keys or stale `updated` claims are pre-ship defects.

If `docs/doc-scheme.md`/`docs/doc-scheme.json` are missing, recover via `/silver:ensure-docs --recover-scheme`, then complete this step before proceeding to Step 8.

## Step 8: Ship

Invoke `silver:ship` through the active runtime's SB-recognized skill invocation channel. Purpose: push branch, create PR.
