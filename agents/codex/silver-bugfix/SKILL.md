---
name: silver:bugfix
title: Silver: /silver:bugfix - Bugfix
description: >
  This skill should be used for SB-orchestrated bug investigation and fix: triage → path A/B/C → TDD regression test → plan → execute → review → verify → ship
argument-hint: "<description of the bug or failure>"
version: 0.1.0
---

# /silver:bugfix — Bug, Regression, Test Failure Workflow

SB orchestrator for bugs, regressions, crashes, errors, and failing tests. Enforces triage-first discipline: classify the failure type before any investigation begins.

Never implements fixes directly — orchestrates only.

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
| `.planning/` directory exists | Project already bootstrapped | Skip FLOW 0 (BOOTSTRAP) |
| `.planning/STATE.md` exists | GSD state present | Skip FLOW 0 (BOOTSTRAP) |

```bash
# Check for existing planning artifacts
[ -d ".planning" ] && echo "SKIP FLOW 0 — .planning/ exists" || echo "Include FLOW 0"
```

### 2. Build Flow Chain

Construct the proposed flow chain for bugfix triage. Bugfix is single-phase by design — no per-phase loop. Default chain:

FLOW 1 (ORIENT) → FLOW 14 (DEBUG) [always included — this is a bugfix] → FLOW 5 (PLAN) → FLOW 7 (EXECUTE) → FLOW 9 (REVIEW) → FLOW 10 (SECURE) → FLOW 11 (VERIFY) → FLOW 12 (QUALITY GATE) → FLOW 13 (SHIP)

Note: FLOW 14 (DEBUG) is always included for any bugfix engagement. FLOW 0 (BOOTSTRAP) is skipped when `.planning/` already exists.

### 3. Display Proposal

Display the composition proposal to the user:

```
SILVER BULLET ► FLOW COMPOSED
Flows: ORIENT → DEBUG → PLAN → EXECUTE → REVIEW → SECURE → VERIFY → SHIP
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

**Non-skippable gates:** `security`, `silver:quality-gates` pre-ship, `gsd-verify-work`.

## Step 0: Triage — Classify Failure Type

Ask the user directly:

> What best describes this failure?
>
> A. Known symptom, unknown fix — I can observe the bug but don't know the root cause
> B. Unknown cause — session history is unclear, need to reconstruct what happened
> C. Failed GSD workflow specifically — a plan, execution phase, or GSD command failed

Wait for selection, then route to the corresponding path below.

## Path 1A: Known Symptom, Unknown Fix

Invoked when: triage selects A, OR after Path 1B/1C silver:forensics completes and hands off here.

**1A.1 — Systematic debugging hypothesis**
Invoke `superpowers:systematic-debugging` via the Skill tool. Purpose: structure the debugging hypothesis before executing investigation — ensures systematic approach before diving into code.

**1A.2 — Persistent debugging investigation**
Invoke `gsd-debug` via the Skill tool. Purpose: execute investigation with persistent state across context resets.

After gsd-debug completes, proceed to Step 2 (TDD).

## Path 1B: Unknown Cause, Needs Reconstruction

Invoked when: triage selects B.

**1B.1 — Forensic cause reconstruction**
Invoke `silver:forensics` via the Skill tool. Purpose: SB-owned silver:forensics skill (skills/silver-forensics/SKILL.md) — reconstructs cause from git history, artifacts, and state. Outputs a cause classification report.

After silver:forensics completes and outputs the cause classification:
→ Hand off to Path 1A (start at Step 1A.1 with the reconstructed context).

## Path 1C: Failed GSD Workflow

Invoked when: triage selects C.

**1C.1 — GSD-specific post-mortem**
Invoke `gsd-forensics` via the Skill tool. Purpose: GSD-owned post-mortem for failed GSD workflows (failed plans, broken state, incomplete phases). Outputs diagnosis.

After gsd-forensics completes and outputs diagnosis:
→ Hand off to Path 1A (start at Step 1A.1 with the GSD diagnosis context).

## Step 2: TDD — Write Regression Test First

All paths converge here. Before writing any fix code:

Invoke `tdd` via the Skill tool. Purpose: write a failing regression test first — RED must appear before writing any fix. This satisfies the hidden TDD gate before any fix code is written and ensures the bug cannot silently regress. `tdd` delegates to Superpowers only at this explicit SB-required execution boundary.

**Enforcement:** Do not proceed to Step 3 until the test is red (failing for the right reason).

## Step 3: Plan the Fix

Invoke `gsd-plan-phase` via the Skill tool (lightweight, 1-2 tasks only — this is a fix, not a feature).

## Step 4: Execute Fix + Verify Green

Invoke `gsd-execute-phase --tdd` via the Skill tool. Host aliases may expose this as `gsd:execute-phase --tdd`; the required behavior is the same. After execution, verify the regression test from Step 2 is now green.

## Step 5: Code Review

Run the full review sequence in order:

1. Invoke `requesting-code-review` (superpowers:requesting-code-review) via the Skill tool.
2. Invoke `gsd-code-review` via the Skill tool. This creates the authoritative REVIEW.md artifact; optional external review helpers must feed into this artifact rather than replace it.
3. Invoke `receiving-code-review` (superpowers:receiving-code-review) via the Skill tool.

## Step 6: Verify Work

Invoke `gsd-verify-work` via the Skill tool. Purpose: confirm fix, zero regression. Non-skippable.

## Step 7: Security Review

Invoke `security` via the Skill tool. Non-skippable.

## Step 7a: Tech Debt Review

Invoke `tech-debt` via the Skill tool when available. Purpose: identify and document any technical debt introduced by the fix. Items not addressed now MUST be captured via `/silver:add`.

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

Invoke `silver:quality-gates` via the Skill tool (affected quality dimensions for the changed code). Non-skippable.

## Step 7c: Doc-Scheme Compliance (conditional)

**Only if `docs/doc-scheme.md` exists in the project:**

```bash
[ -f "docs/doc-scheme.md" ] && [ -f "docs/doc-scheme.json" ] && echo "Doc-scheme gate required" || echo "Doc scheme missing/incomplete — run /silver:ensure-docs --recover-scheme"
```

Before raising the PR, verify documentation is up to date per the scheme:

1. **`docs/CHANGELOG.md`** — must have an entry for this fix (newest-first). If missing, write it now.
2. **`docs/knowledge/YYYY-MM.md`** (current month) — append root-cause patterns, gotchas, and decisions found during diagnosis.
3. **`docs/lessons/YYYY-MM.md`** (current month) — append portable lessons learned during diagnosis.
4. Update any additional docs changed by the fix (`ARCHITECTURE.md`, `TESTING.md`, runbooks, workflows, etc.) so content matches current behavior.
5. **`docs/task-doc-checklist.json`** — must include `task_granularity` and full status coverage for every key in `docs/doc-scheme.json -> required_docs`, plus any required section entries declared under `required_sections`.

**Gate:** Do NOT proceed to Step 8 until all checklist/doc checks pass. Missing checklist keys or stale `updated` claims are pre-ship defects.

If `docs/doc-scheme.md`/`docs/doc-scheme.json` are missing, recover via `/silver:ensure-docs --recover-scheme`, then complete this step before proceeding to Step 8.

## Step 8: Ship

Invoke `gsd-ship` via the Skill tool. Purpose: push branch, create PR.
