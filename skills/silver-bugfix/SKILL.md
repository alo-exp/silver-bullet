---
name: silver-bugfix
description: "SB-orchestrated bug investigation and fix: triage → path A/B/C → TDD regression test → plan → execute → review → verify → ship"
argument-hint: "<description of the bug or failure>"
---

# /silver:bugfix — Bug, Regression, Test Failure Workflow

SB orchestrator for bugs, regressions, crashes, errors, and failing tests. Enforces triage-first discipline: classify the failure type before any investigation begins.

Never implements fixes directly — orchestrates only.

## Pre-flight: Load Preferences

Read `silver-bullet.md §10` to load user workflow preferences before any other step.

```bash
grep -A 50 "^## 10\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► BUGFIX WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Symptom: {$ARGUMENTS or "(not specified)"}
```

## Composition Proposal

Before beginning execution, read existing artifacts to determine context and propose which PATHs to include or skip.

### 1. Context Scan

Check the following artifacts and set skip/include flags:

| Artifact | Signal | Action |
|----------|--------|--------|
| `.planning/` directory exists | Project already bootstrapped | Skip PATH 0 (BOOTSTRAP) |
| `.planning/STATE.md` exists | GSD state present | Skip PATH 0 (BOOTSTRAP) |

```bash
# Check for existing planning artifacts
[ -d ".planning" ] && echo "SKIP PATH 0 — .planning/ exists" || echo "Include PATH 0"
```

### 2. Build Path Chain

Construct the proposed path chain for bugfix triage. Bugfix is single-phase by design — no per-phase loop. Default chain:

PATH 1 (ORIENT) → PATH 14 (DEBUG) [always included — this is a bugfix] → PATH 5 (PLAN) → PATH 7 (EXECUTE) → PATH 11 (VERIFY) → PATH 13 (SHIP)

Note: PATH 14 (DEBUG) is always included for any bugfix engagement. PATH 0 (BOOTSTRAP) is skipped when `.planning/` already exists.

### 3. Display Proposal

Display the composition proposal to the user:

```
┌─ COMPOSITION PROPOSAL ─────────────────────────
│ Paths: PATH 1 (ORIENT) → PATH 14 (DEBUG) → PATH 5 (PLAN) → PATH 7 (EXECUTE) → PATH 11 (VERIFY) → PATH 13 (SHIP)
│ Skipped: PATH 0 (BOOTSTRAP) — .planning/ exists
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
- Populate `Intent:` with the bug description ($ARGUMENTS)
- Populate `Composed:` with the current ISO timestamp
- Populate `Composer:` with `/silver:bugfix`
- Populate `Mode:` with the current mode (interactive or autonomous)
- Record the confirmed path chain in the Path Log section header

After each path completes, write status to Path Log table:

```
| {#} | PATH {N} ({name}) | complete | {artifacts produced} | ✓ |
```

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §10b, commit both.

**Non-skippable gates:** `silver:security`, `silver:quality-gates` pre-ship, `gsd-verify-work`.

## Step 0: Triage — Classify Failure Type

Use AskUserQuestion:

> What best describes this failure?
>
> A. Known symptom, unknown fix — I can observe the bug but don't know the root cause
> B. Unknown cause — session history is unclear, need to reconstruct what happened
> C. Failed GSD workflow specifically — a plan, execution phase, or GSD command failed

Wait for selection, then route to the corresponding path below.

## Path 1A: Known Symptom, Unknown Fix

Invoked when: triage selects A, OR after Path 1B/1C forensics completes and hands off here.

**1A.1 — Systematic debugging hypothesis**
Invoke `superpowers:systematic-debugging` via the Skill tool. Purpose: structure the debugging hypothesis before executing investigation — ensures systematic approach before diving into code.

**1A.2 — Persistent debugging investigation**
Invoke `gsd-debug` via the Skill tool. Purpose: execute investigation with persistent state across context resets.

After gsd-debug completes, proceed to Step 2 (TDD).

## Path 1B: Unknown Cause, Needs Reconstruction

Invoked when: triage selects B.

**1B.1 — Forensic cause reconstruction**
Invoke `silver:forensics` via the Skill tool. Purpose: SB-owned forensics skill (skills/forensics/SKILL.md) — reconstructs cause from git history, artifacts, and state. Outputs a cause classification report.

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

Invoke `silver:tdd` (superpowers:test-driven-development) via the Skill tool. Purpose: write a failing regression test first — RED must appear before writing any fix. This ensures the fix is verifiable and the bug cannot silently regress.

**Enforcement:** Do not proceed to Step 3 until the test is red (failing for the right reason).

## Step 3: Plan the Fix

Invoke `gsd-plan-phase` via the Skill tool (lightweight, 1-2 tasks only — this is a fix, not a feature).

## Step 4: Execute Fix + Verify Green

Invoke `gsd-execute-phase` via the Skill tool. After execution, verify the regression test from Step 2 is now green.

## Step 5: Code Review

Run the full review sequence in order:

1. Invoke `silver:request-review` (superpowers:requesting-code-review) via the Skill tool.
2. Invoke `gsd-code-review` via the Skill tool.
3. Invoke `silver:receive-review` (superpowers:receiving-code-review) via the Skill tool.

## Step 6: Verify Work

Invoke `gsd-verify-work` via the Skill tool. Purpose: confirm fix, zero regression. Non-skippable.

## Step 7: Security Review

Invoke `silver:security` via the Skill tool. Non-skippable.

## Step 7b: Quality Gates

Invoke `silver:quality-gates` via the Skill tool (affected quality dimensions for the changed code). Non-skippable.

## Step 8: Ship

Invoke `gsd-ship` via the Skill tool. Purpose: push branch, create PR.
