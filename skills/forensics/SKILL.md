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
3. Presence of `/tmp/.silver-bullet-timeout` (was sentinel triggered?)
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
2. Check sentinel artifacts: was `/tmp/.silver-bullet-timeout` set? What was the last
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
