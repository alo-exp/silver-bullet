# Forensics Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the `/forensics` skill and wire it into CLAUDE.md and the full-dev-cycle workflow so Silver Bullet has structured post-mortem investigation capability.

**Architecture:** Pure instruction layer — one new SKILL.md file guides Claude through symptom classification, three investigation paths, and post-mortem report generation. Four existing files are edited to integrate the skill: CLAUDE.md, templates/CLAUDE.md.base, docs/workflows/full-dev-cycle.md, and templates/workflows/full-dev-cycle.md. No hooks, no code.

**Tech Stack:** Markdown only. All changes are file edits verified by grep.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `skills/forensics/SKILL.md` | Full forensics workflow — classification, three paths, post-mortem template |
| Modify | `CLAUDE.md` | Add `/forensics` rule in Section 3; qualify existing debug line with "during execution" |
| Modify | `templates/CLAUDE.md.base` | Add `/forensics` rule below existing `/gsd:debug` line |
| Modify | `docs/workflows/full-dev-cycle.md` | Insert forensics gate after step 7 produces line in VERIFY section |
| Modify | `templates/workflows/full-dev-cycle.md` | Same insert — kept in sync with docs/ copy |

---

## Task 1: Create `skills/forensics/SKILL.md`

**Files:**
- Create: `skills/forensics/SKILL.md`

- [ ] **Step 1.1: Create the skill file**

Create `skills/forensics/SKILL.md` with this exact content:

```markdown
---
name: forensics
description: Root-cause investigation for completed sessions, abandoned sessions, verification failures, or mid-session stalls — classifies failure, walks investigation path, writes report to <project-root>/docs/forensics/
---

# /forensics — Post-mortem Investigation

Use this skill when the root cause of a failure is **unknown and must be reconstructed
from evidence**. This covers: completed sessions that left things broken, abandoned or
timed-out sessions, step 7 verification failures, and mid-session stalls.

**If you have an active error with a known cause**, use `superpowers:systematic-debugging`
instead. `/forensics` is for reconstruction, not live debugging.

**In autonomous mode**: skip the user prompt in Step 1 of triage. Classify from evidence
alone. If evidence is insufficient, default to Path 3 (General) and note
"Insufficient evidence for classification — defaulting to general path" as the first
line of the post-mortem.

---

## Step 1 — Locate the project root

Walk up from `$PWD` until a `.silver-bullet.json` file is found. All evidence paths
(`docs/sessions/`, `.planning/`, `docs/forensics/`) are relative to this root.
The plugin root (where this SKILL.md lives) is irrelevant for evidence gathering.

---

## Step 2 — Triage

### Step 2a — User prompt (skip in autonomous mode)

> "Briefly describe what went wrong. (e.g., 'autonomous session stalled after 20 min',
> 'task 3 produced wrong output', 'session completed but tests are failing')"

### Step 2b — Evidence quick-scan (run in parallel)

1. Most recent session log in `<project-root>/docs/sessions/` — glob `docs/sessions/*.md`,
   sort by name descending, take first
2. `git log --oneline -10`
3. Presence of `~/.claude/.silver-bullet/timeout` (was sentinel triggered?)
4. `.planning/` directory — any incomplete phase markers

### Step 2c — Classification

From the user description (or evidence alone in autonomous mode), classify into one path:

| Path | Triggered when |
|------|----------------|
| **Session-level** | Timeout flag present; session log shows incomplete outcome; stall/timeout/hang described |
| **Task-level** | Specific task or phase named; commits present but output is wrong; tests failing after recent commits |
| **General** | Does not fit neatly into the above; open-ended |

Log the classification as the first line of the post-mortem document.

---

## Path 1 — Session-level (stall / timeout / incomplete)

1. Read full session log from `<project-root>/docs/sessions/` — extract Mode, Autonomous
   decisions, Needs human review, Outcome
2. Check sentinel artifacts: was `~/.claude/.silver-bullet/timeout` set? What was the last
   tool use before stall? If the sentinel file is absent, note "No sentinel detected"
   in Evidence Gathered and proceed — absence does not rule out stall; rely on session
   log and git history.
3. Run `git log --oneline` scoped to session date — how many commits landed vs. planned?
4. Read `.planning/ROADMAP.md` to enumerate planned phases. For each phase listed, check
   whether `.planning/{phase}-VERIFICATION.md` exists — its presence indicates the phase
   completed verification; its absence indicates the phase did not complete.
   (If `.planning/ROADMAP.md` is absent, note this in Evidence Gathered and skip
   phase-completion checks.)
5. Identify: last confirmed progress point, where execution diverged, whether it was a
   blocker, stall, or external kill
6. Classify root cause as one of:
   - *Pre-answer gap* — a decision point was reached with no pre-answer and no autonomous fallback
   - *Anti-stall trigger* — per-step budget exceeded, counter not reset
   - *Genuine blocker* — missing credential, ambiguous destructive operation
   - *External kill* — terminal closed, session interrupted
   - *Unknown* — insufficient evidence to determine

---

## Path 2 — Task-level (wrong output)

1. Read the session log — find the relevant task in Files changed and Approach
2. Run `git show <commit>` for each commit from that task — what exactly changed?
3. Read the plan — glob `.planning/{phase}-*-PLAN.md` (plans are numbered
   `{phase}-{N}-PLAN.md`; if phase is unknown, glob `.planning/*-PLAN.md`) —
   what was the task supposed to do?
4. Compare plan intent vs. actual diff — find the divergence point
5. Run tests if available (`npm test` / `pytest` / `cargo test` / `go test ./...`) —
   confirm which assertions fail. If no supported test runner is detected, skip this
   step and note "No test runner detected" in Evidence Gathered.
6. Classify root cause as one of:
   - *Plan ambiguity* — task was underspecified, Claude made a best-judgment call that was wrong
   - *Implementation drift* — Claude deviated from the plan without logging an autonomous decision
   - *Upstream dependency* — an earlier task produced bad input that propagated
   - *Verification gap* — tests did not catch the failure at the time of the commit

---

## Path 3 — General (open-ended)

1. Read most recent session log fully from `<project-root>/docs/sessions/`
2. Run `git log --oneline -20` + `git status`
3. Read any `.planning/` files modified in the last session
4. Ask one targeted follow-up question based on what the evidence shows. In autonomous
   mode, skip this question and proceed directly to step 5 using best-judgment
   classification from the evidence gathered.
5. Proceed with the most applicable sub-path from Path 1 or Path 2 based on findings

---

## Root cause statement format (all paths)

End every investigation with:

```
ROOT CAUSE: <one sentence> — <path taken> — <confidence: high/medium/low>
```

---

## Post-mortem Report

1. Run `mkdir -p <project-root>/docs/forensics/` via Bash before writing.
2. Determine slug:
   - If user supplied a slug argument, use it verbatim; replace spaces, forward slashes,
     and colons with hyphens.
   - If no argument, default to `<failure-type>-<YYYY-MM-DD>`.
3. Check for collision: glob `<project-root>/docs/forensics/<slug>*.md`; if a match
   exists, append `-2`, `-3`, etc. until unique.
4. Write to `<project-root>/docs/forensics/YYYY-MM-DD-<slug>.md`:

```markdown
# Forensics Report — <slug>

**Date:** YYYY-MM-DD
**Session log:** <project-root>/docs/sessions/<filename>.md
**Path taken:** session-level | task-level | general
**Confidence:** high | medium | low

---

## Symptom

<user's original description>

## Evidence Gathered

- Session log: <key findings>
- Git history: <relevant commits>
- Planning artifacts: <phase status>
- Test output: <pass/fail summary if applicable>
- Sentinel/timeout flags: <present/absent>

## Root Cause

<one-sentence root cause statement>

## Contributing Factors

- <factor 1>
- <factor 2>

## Recommended Next Steps

- [ ] <action 1>
- [ ] <action 2>

## Prevention

<one sentence on how to avoid this class of failure in future>
```

---

## Edge Cases

- **No session log found**: Skip session log step; proceed with git history + user
  description only. Note absence in post-mortem.
- **No planning artifacts**: Skip `.planning/` step; note absence.
- **`docs/forensics/` directory absent**: Create it with `mkdir -p` before writing.
- **Slug collision**: glob `<project-root>/docs/forensics/<slug>*.md`; increment suffix.
```

- [ ] **Step 1.2: Verify frontmatter is present**

```bash
head -5 /path/to/project/skills/forensics/SKILL.md
```

Expected: lines show `---`, `name: forensics`, `description: Root-cause investigation...`

- [ ] **Step 1.3: Verify all three paths are present**

```bash
grep -n "## Path" skills/forensics/SKILL.md
```

Expected output (3 lines):
```
## Path 1 — Session-level
## Path 2 — Task-level
## Path 3 — General
```

- [ ] **Step 1.4: Verify post-mortem section is present**

```bash
grep -c "Post-mortem Report" skills/forensics/SKILL.md
```

Expected: `1`

- [ ] **Step 1.5: Commit**

```bash
git add skills/forensics/SKILL.md
git commit -m "feat: add forensics skill — post-mortem investigation workflow

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Modify `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md` (Section 3 rules block)

The spec requires:
- Modify the existing debug line to add "during execution" qualifier
- Add a new `/forensics` line immediately below it

**Before (exact current text in CLAUDE.md):**
```
- Always use /systematic-debugging + /debug for ANY bug
```

**After (two lines):**
```
- Always use /systematic-debugging + /debug for ANY bug encountered during execution
- Always use /forensics for root-cause investigation of completed sessions, abandoned sessions, or verification failures
```

- [ ] **Step 2.1: Verify the before-text exists exactly**

```bash
grep -n "Always use /systematic-debugging" CLAUDE.md
```

Expected: one matching line without "during execution" at the end.

- [ ] **Step 2.2: Apply the edit**

In `CLAUDE.md`, find the line:
```
- Always use /systematic-debugging + /debug for ANY bug
```
Replace it with these two lines:
```
- Always use /systematic-debugging + /debug for ANY bug encountered during execution
- Always use /forensics for root-cause investigation of completed sessions, abandoned sessions, or verification failures
```

- [ ] **Step 2.3: Verify both lines are present**

```bash
grep -A1 "systematic-debugging.*during execution" CLAUDE.md
```

Expected:
```
- Always use /systematic-debugging + /debug for ANY bug encountered during execution
- Always use /forensics for root-cause investigation of completed sessions, abandoned sessions, or verification failures
```

- [ ] **Step 2.4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add /forensics rule to CLAUDE.md Section 3

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Modify `templates/CLAUDE.md.base`

**Files:**
- Modify: `templates/CLAUDE.md.base` (Section 3 rules block)

The spec requires adding one new line below the existing `/gsd:debug` line, leaving that line unchanged.

**Before (exact current text in templates/CLAUDE.md.base):**
```
- Always use `/gsd:debug` for ANY bug encountered during execution
```

**After (two lines — first unchanged, second new):**
```
- Always use `/gsd:debug` for ANY bug encountered during execution
- Always use `/forensics` for root-cause investigation of completed sessions, abandoned sessions, or verification failures
```

- [ ] **Step 3.1: Verify the before-text exists exactly**

```bash
grep -n "Always use.*gsd:debug.*during execution" templates/CLAUDE.md.base
```

Expected: one matching line.

- [ ] **Step 3.2: Apply the edit**

In `templates/CLAUDE.md.base`, find the line:
```
- Always use `/gsd:debug` for ANY bug encountered during execution
```
Insert this new line immediately after it:
```
- Always use `/forensics` for root-cause investigation of completed sessions, abandoned sessions, or verification failures
```

- [ ] **Step 3.3: Verify both lines are present**

```bash
grep -A1 "gsd:debug.*during execution" templates/CLAUDE.md.base
```

Expected:
```
- Always use `/gsd:debug` for ANY bug encountered during execution
- Always use `/forensics` for root-cause investigation of completed sessions, abandoned sessions, or verification failures
```

- [ ] **Step 3.4: Commit**

```bash
git add templates/CLAUDE.md.base
git commit -m "docs: add /forensics rule to templates/CLAUDE.md.base Section 3

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Modify workflow files (docs/ and templates/)

**Files:**
- Modify: `docs/workflows/full-dev-cycle.md`
- Modify: `templates/workflows/full-dev-cycle.md`

Both files are identical — apply the same edit to each. The anchor text appears exactly once in each file, in the VERIFY section.

**Before (exact text — produces line + blank line + Agent Team note):**
```
   → Produces: `.planning/{phase}-VERIFICATION.md`, `.planning/{phase}-UAT.md`

   **Agent Team scope for steps 8 + 10**: Steps 8 and 10 may use parallel agents
```

**After (forensics gate block inserted between produces line and Agent Team note):**
```
   → Produces: `.planning/{phase}-VERIFICATION.md`, `.planning/{phase}-UAT.md`

   **If step 7 fails or output is suspect:** invoke `/forensics` before retrying.
   Identify root cause first, then re-run the failing phase from the beginning.
   Do not advance to step 8 until step 7 passes. Blind retries compound failures.

   **Agent Team scope for steps 8 + 10**: Steps 8 and 10 may use parallel agents
```

- [ ] **Step 4.1: Verify the anchor text exists in docs/workflows/full-dev-cycle.md**

```bash
grep -n "Agent Team scope for steps 8" docs/workflows/full-dev-cycle.md
```

Expected: one matching line.

- [ ] **Step 4.2: Apply the edit to docs/workflows/full-dev-cycle.md**

Find the blank line between the produces line and the Agent Team note (in the VERIFY section). Insert these three lines in that blank-line gap:

```
   **If step 7 fails or output is suspect:** invoke `/forensics` before retrying.
   Identify root cause first, then re-run the failing phase from the beginning.
   Do not advance to step 8 until step 7 passes. Blind retries compound failures.
```

The blank line becomes a separator before these lines; add a trailing blank line after them before the Agent Team note.

- [ ] **Step 4.3: Verify the forensics gate is present in docs/workflows/full-dev-cycle.md**

```bash
grep -n "step 7 fails or output is suspect" docs/workflows/full-dev-cycle.md
```

Expected: one matching line.

- [ ] **Step 4.4: Verify anchor text still present (not accidentally deleted)**

```bash
grep -n "Agent Team scope for steps 8" docs/workflows/full-dev-cycle.md
```

Expected: one matching line (same as before).

- [ ] **Step 4.5: Apply the same edit to templates/workflows/full-dev-cycle.md**

Same insert as Step 4.2, targeting `templates/workflows/full-dev-cycle.md`.

- [ ] **Step 4.6: Verify both files match**

```bash
grep -c "step 7 fails or output is suspect" docs/workflows/full-dev-cycle.md templates/workflows/full-dev-cycle.md
```

Expected:
```
docs/workflows/full-dev-cycle.md:1
templates/workflows/full-dev-cycle.md:1
```

- [ ] **Step 4.7: Commit**

```bash
git add docs/workflows/full-dev-cycle.md templates/workflows/full-dev-cycle.md
git commit -m "docs: add forensics gate after step 7 in full-dev-cycle workflow

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Final Verification

- [ ] **Step 5.1: Confirm all 5 components are in place**

```bash
# Skill exists
ls skills/forensics/SKILL.md

# CLAUDE.md has both lines
grep "during execution" CLAUDE.md
grep "/forensics" CLAUDE.md

# templates/CLAUDE.md.base has the new line
grep "/forensics" templates/CLAUDE.md.base

# Both workflow files have the gate
grep "step 7 fails" docs/workflows/full-dev-cycle.md
grep "step 7 fails" templates/workflows/full-dev-cycle.md
```

Expected: all commands produce output (no "No such file" errors, no empty grep results).
