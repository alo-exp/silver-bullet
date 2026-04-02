# Silver Bullet — Forensics Skill Design

**Date:** 2026-04-02
**Scope:** Post-mortem investigation skill for completed or abandoned sessions
**Reference:** `docs/gsd2-vs-sb-gap-analysis.md` (Category 9 — Observability & Reporting)
**Target workflow:** `docs/workflows/full-dev-cycle.md`

---

## Problem

Silver Bullet has no structured post-mortem capability. When an autonomous session stalls, a task produces wrong output, or a completed session leaves things in a broken state, the only recourse is manually scanning session logs and git history. The existing `superpowers:systematic-debugging` skill handles live bugs during execution — it is not designed for root-cause investigation of completed sessions, abandoned sessions, or verification failures where the cause is unknown.

**Scope**: `/forensics` covers three invocation contexts:
1. **Post-session** — session completed or was abandoned; investigate what went wrong
2. **Verification failure** — `/gsd:verify-work` (step 7) fails or produces suspect output; investigate root cause before retrying
3. **Mid-session stall** — autonomous session has stalled and the operator wants to understand why before resuming

All three require the same structured investigation. The boundary with `superpowers:systematic-debugging` is the type of failure: debugging is for a live bug with an active error; forensics is for any situation where the cause is unknown and must be reconstructed from evidence.

---

## Architecture: Pure Instruction Layer

The forensics skill is a SKILL.md that guides Claude through a symptom-driven investigation. No new hooks are needed — session logs (`<project-root>/docs/sessions/`), git history, and planning artifacts already provide all necessary evidence.

**Project root**: The skill locates the project root the same way other Silver Bullet hooks do — walk up from `$PWD` until a `.silver-bullet.json` file is found. Session logs, planning artifacts, and forensics reports are all relative to this root. The plugin root (where `skills/forensics/SKILL.md` lives) is distinct and not used for evidence gathering.

| Component | Type | Purpose |
|-----------|------|---------|
| `skills/forensics/SKILL.md` | New skill | Investigation workflow — classification, three paths, post-mortem |
| `<project-root>/docs/forensics/YYYY-MM-DD-<slug>.md` | Output artifact | Saved post-mortem reports (directory created on first use by skill) |
| `CLAUDE.md` | Modify | Add `/forensics` rule alongside `/systematic-debugging` |
| `templates/CLAUDE.md.base` | Modify | Same addition |
| `docs/workflows/full-dev-cycle.md` | Modify | Add forensics invocation point in VERIFY section |
| `templates/workflows/full-dev-cycle.md` | Modify | Same addition (kept in sync with docs/ copy) |

The skill is invoked via the Skill tool as `/forensics` with an optional slug argument (e.g., `/forensics autonomous-stall-2026-04-02`). The slug defaults to `<failure-type>-<YYYY-MM-DD>` if not supplied.

**Required SKILL.md frontmatter:**
```yaml
---
name: forensics
description: Root-cause investigation for completed sessions, abandoned sessions, or verification failures — classifies failure, walks investigation path, writes report to <project-root>/docs/forensics/
---
```

**Namespace convention**: Silver Bullet's own skills use slash-only form (e.g., `/forensics`, `/quality-gates`). The `superpowers:` prefix identifies externally-published skills from the Superpowers marketplace. This distinction is intentional — it mirrors the two-source skill discovery described in the workflow.

**Boundary with `superpowers:systematic-debugging`:**
- `superpowers:systematic-debugging` — live bugs **during** execution with an active error; find root cause before applying a fix
- `/forensics` — root cause is **unknown** and must be reconstructed from evidence; covers post-session, verification failure, and mid-session stall contexts

**Autonomous mode behavior**: When invoked in autonomous mode, the user-prompt step (Step 1 of triage) is skipped. Claude uses the session log, git history, and sentinel artifacts as the sole evidence source and classifies based on those alone. If evidence is insufficient to classify (no session log, no sentinel, ambiguous git history), Claude defaults to Path 3 (General) and notes "Insufficient evidence for classification — defaulting to general path" as the first line of the post-mortem. All other steps proceed identically.

---

## Feature 1 — Failure Classification

When `/forensics` is invoked, Claude runs a two-step triage before entering any investigation path.

### Step 1 — User prompt

> "Briefly describe what went wrong. (e.g., 'autonomous session stalled after 20 min', 'task 3 produced wrong output', 'session completed but tests are failing')"

### Step 2 — Evidence quick-scan (parallel reads)

- Most recent session log in `<project-root>/docs/sessions/` (today's if available, otherwise most recent — glob `docs/sessions/*.md`, sort by name descending, take first)
- `git log --oneline -10`
- Presence of `/tmp/.silver-bullet-timeout` (was sentinel triggered?)
- `.planning/` directory — any incomplete phase markers

### Classification

From the user description + quick-scan, Claude classifies into one of three paths:

| Path | Triggered when |
|------|---------------|
| **Session-level** | Timeout flag present; session log shows incomplete outcome; autonomous decisions log shows stall pattern; user describes stall/timeout/hang |
| **Task-level** | A specific task or phase is named; git history shows commits from the session but output is wrong; tests failing after recent commits |
| **General** | Does not fit neatly into the above — open-ended investigation |

Classification is logged as the first line of the post-mortem document.

---

## Feature 2 — Three Investigation Paths

### Path 1 — Session-level (stall / timeout / incomplete)

1. Read full session log from `<project-root>/docs/sessions/` — extract Mode, Autonomous decisions, Needs human review, Outcome
2. Check sentinel artifacts: was `/tmp/.silver-bullet-timeout` set? What was the last tool use before stall?
3. Run `git log --oneline` scoped to session date — how many commits landed vs. planned?
4. Read `.planning/ROADMAP.md` — which phases completed, which did not?
5. Identify: last confirmed progress point, where execution diverged, whether it was a blocker, stall, or external kill
6. Classify root cause as one of:
   - *Pre-answer gap* — a decision point was reached with no pre-answer and no autonomous fallback
   - *Anti-stall trigger* — per-step budget exceeded, counter not reset
   - *Genuine blocker* — missing credential, ambiguous destructive operation
   - *External kill* — terminal closed, session interrupted
   - *Unknown* — insufficient evidence to determine

### Path 2 — Task-level (wrong output)

1. Read the session log — find the relevant task in Files changed and Approach
2. Run `git show <commit>` for each commit from that task — what exactly changed?
3. Read the plan — glob `.planning/{phase}-*-PLAN.md` (plans are numbered `{phase}-{N}-PLAN.md`; if phase is unknown, glob `.planning/*-PLAN.md`) — what was the task supposed to do?
4. Compare plan intent vs. actual diff — find the divergence point
5. Run tests if available (`npm test` / `pytest` / `cargo test` / `go test ./...`) — confirm which assertions fail
6. Classify root cause as one of:
   - *Plan ambiguity* — task was underspecified, Claude made a best-judgment call that was wrong
   - *Implementation drift* — Claude deviated from the plan without logging an autonomous decision
   - *Upstream dependency* — an earlier task produced bad input that propagated
   - *Verification gap* — tests did not catch the failure at the time of the commit

### Path 3 — General (open-ended)

1. Read most recent session log fully from `<project-root>/docs/sessions/`
2. Run `git log --oneline -20` + `git status`
3. Read any `.planning/` files modified in the last session
4. Ask one targeted follow-up question based on what the evidence shows
5. Proceed with the most applicable sub-path from Path 1 or Path 2 based on findings

### Root cause statement format (all paths)

All three paths end with a root cause statement in this format:

```
ROOT CAUSE: <one sentence> — <path taken> — <confidence: high/medium/low>
```

---

## Feature 3 — Post-mortem Document

Saved to `<project-root>/docs/forensics/YYYY-MM-DD-<slug>.md` after the investigation completes.

```markdown
# Forensics Report — <slug>

**Date:** YYYY-MM-DD
**Session log:** docs/sessions/<filename>.md
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

The `<project-root>/docs/forensics/` directory is created on first use: the SKILL.md instructs Claude to run `mkdir -p <project-root>/docs/forensics/` via a Bash tool call before writing the report. No hook handles this — it is an inline instruction in the skill. The slug defaults to `<failure-type>-<YYYY-MM-DD>` if not supplied as an argument.

---

## Feature 4 — Workflow Integration

### CLAUDE.md

In Section 3 (rules), the existing line is **modified** (qualifier added) and a **new line is added** below it:

**Before (exact current text — one line):**
```
- Always use /systematic-debugging + /debug for ANY bug
```

**After (two lines — first line modified, second line new):**
```
- Always use /systematic-debugging + /debug for ANY bug encountered during execution
- Always use /forensics for root-cause investigation of completed sessions, abandoned sessions, or verification failures
```

Note: the workflow's enforcement section (`docs/workflows/full-dev-cycle.md` line 301) also uses `/gsd:debug` for bugs during execution. This is not changed by this spec — `/gsd:debug` and `/systematic-debugging + /debug` are both valid references to GSD's debugging flow; the forensics line is additive and does not conflict with either.

### templates/CLAUDE.md.base

In Section 3 (rules), the existing line is kept unchanged and a **new line is added** below it:

**Before (exact current text — one line):**
```
- Always use `/gsd:debug` for ANY bug encountered during execution
```

**After (two lines — first line unchanged, second line new):**
```
- Always use `/gsd:debug` for ANY bug encountered during execution
- Always use `/forensics` for root-cause investigation of completed sessions, abandoned sessions, or verification failures
```

### docs/workflows/full-dev-cycle.md + templates/workflows/full-dev-cycle.md

In the VERIFY section, insert immediately after the closing line of the step 7 block
(`→ Produces: .planning/{phase}-VERIFICATION.md, .planning/{phase}-UAT.md`) and
before the `**Agent Team scope for steps 8 + 10**` note. Exact before/after:

**Before (exact text — the blank line between step 7's produces line and the Agent Team note):**
```
   → Produces: `.planning/{phase}-VERIFICATION.md`, `.planning/{phase}-UAT.md`

   **Agent Team scope for steps 8 + 10**: Steps 8 and 10 may use parallel agents
```

**After (insert the forensics gate block between the produces line and the Agent Team note):**
```
   → Produces: `.planning/{phase}-VERIFICATION.md`, `.planning/{phase}-UAT.md`

   **If step 7 fails or output is suspect:** invoke `/forensics` before retrying.
   Identify root cause first, then re-run the failing phase from the beginning.
   Do not advance to step 8 until step 7 passes. Blind retries compound failures.

   **Agent Team scope for steps 8 + 10**: Steps 8 and 10 may use parallel agents
```

The same before/after applies to both `docs/workflows/full-dev-cycle.md` and
`templates/workflows/full-dev-cycle.md` — both files are kept in sync.

---

## Implementation Scope

| Component | Type | Change |
|-----------|------|--------|
| `skills/forensics/SKILL.md` | New | Full skill with classification, three paths, post-mortem template |
| `<project-root>/docs/forensics/` | New directory | Created by skill on first use via `mkdir -p`; output artifact |
| `CLAUDE.md` | Modify | Modify existing debug line + add `/forensics` rule in Section 3 |
| `templates/CLAUDE.md.base` | Modify | Add `/forensics` rule below existing debug line in Section 3 |
| `docs/workflows/full-dev-cycle.md` | Modify | Add forensics gate in VERIFY section after step 7 |
| `templates/workflows/full-dev-cycle.md` | Modify | Same — kept in sync with docs/ copy |

No new hooks. No new tests (skill is pure markdown instruction; behaviour is verified by reading the skill content).

---

## Edge Cases

- **No session log found**: Skip session log step; proceed with git history + user description only. Note absence in post-mortem.
- **No planning artifacts**: Skip `.planning/` step; note absence.
- **Forensics invoked for a live bug**: The skill cannot reliably distinguish a live bug (active error with known cause) from a verification failure (cause unknown). This is a user responsibility — the SKILL.md includes a note at the top: "If you have an active error with a known cause, use `superpowers:systematic-debugging` instead. Use `/forensics` when the cause is unknown and must be reconstructed." No programmatic check is performed.
- **`docs/forensics/` directory absent**: Create it before writing the post-mortem.
- **Slug collision (same slug, same date)**: Append `-2`, `-3` etc.

---

*Generated: 2026-04-02 | Silver Bullet v0.2.0*
