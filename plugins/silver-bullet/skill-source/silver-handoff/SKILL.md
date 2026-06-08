---
name: "silver:handoff"
title: "Silver: /silver:handoff - Handoff"
description: This skill should be used when ending a session and needing a reusable, project-level handoff prompt for the next session. It summarizes project state, active milestone, key docs, constraints, verification/release status, and open follow-ups without defaulting to task-specific detail unless explicitly requested.
argument-hint: "[optional focus area or 'include task details']"
version: 0.1.0
---

# /silver-handoff — Generate Project-Level Session Handoff Prompt

Use this skill at session wrap-up when work will continue later on the same project. The output is a concise, reusable prompt that helps the next session resume safely without rereading the full repo.

Default behavior is project-level. Include task-specific detail only if the user explicitly asks (for example: "include task details", "include current task", "include branch diff").

---

## Step 1 — Locate project root and execution context

1. Walk up from `$PWD` until you find `.silver-bullet.json` or `.git`.
2. If both are absent, use `$PWD` as root.
3. Determine:
- project/repo name
- current branch (or detached HEAD)
- clean/dirty working tree
- origin URL if available

If any value is unavailable, include `unknown` rather than guessing.

---

## Step 2 — Capture project goal and milestone status

Gather high-level status from available sources (in this order):

1. `.planning/STATE.md` — current phase/plan/progress markers
2. `.planning/ROADMAP.md` — active milestone name and phase sequence
3. `README.md` — project purpose when planning artifacts are absent

Summarize in 2-4 bullets:
- current project goal
- active milestone/phase (or `none detected`)
- current execution posture (active, paused, release-prep, etc.)

---

## Step 3 — Identify "read first" documents

Build a short prioritized list (3-6 paths max) from existing files, preferring:

1. `README.md`
2. `docs/ARCHITECTURE.md`
3. `docs/TESTING.md`
4. `docs/CHANGELOG.md`
5. `docs/knowledge/INDEX.md`
6. latest monthly knowledge/lessons files (`docs/knowledge/YYYY-MM*.md`, `docs/lessons/YYYY-MM*.md`)
7. `docs/doc-scheme.md` (if docs governance matters)

Only include files that actually exist.

---

## Step 4 — Extract constraints, decisions, and invariants

Collect stable constraints from project docs and planning artifacts:

- architecture constraints/invariants
- enforced workflow rules and non-skippable gates
- notable known gotchas or key decisions

Keep this section compact (3-8 bullets). Prefer durable rules over transient implementation notes.

---

## Step 5 — Capture verification and release posture

Summarize recent quality/release state from what is available:

- latest verification signal (tests, audit, or known unverified status)
- branch posture (ahead/behind/clean/dirty)
- most recent release marker (tag/changelog entry) if present
- notable blockers impacting safe continuation

If no evidence is available, explicitly state `verification status unknown`.

---

## Step 6 — List open follow-ups and intentionally unfinished work

Gather open work from whichever sources exist:

- open GitHub issues/PRs (if repository is linked and CLI/app access exists)
- local `docs/issues/ISSUES.md` and `docs/issues/BACKLOG.md`
- explicit TODO/FOLLOW-UP notes in current planning artifacts

Return a short actionable list with stable references (issue numbers, file paths, or phase IDs).

---

## Step 7 — Produce the final handoff prompt

Output exactly one reusable handoff prompt in Markdown.

Use this structure:

1. `Project Identity`
2. `Current Goal and Milestone`
3. `Read First`
4. `Constraints and Invariants`
5. `Verification and Release State`
6. `Open Follow-ups`
7. `First 3 Actions for Next Session`

Style requirements:
- concise but complete (roughly 200-450 words unless user asks longer)
- concrete paths and IDs, no vague placeholders when evidence exists
- do not include task-specific change details unless explicitly requested

---

## Optional Task-Detail Mode

Only when user explicitly requests task-level detail, append:

- current task scope
- branch/diff summary
- unfinished implementation checkpoints
- exact next command or verification step

When not requested, keep handoff project-level.
