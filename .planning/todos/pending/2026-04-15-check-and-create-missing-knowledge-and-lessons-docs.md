---
created: 2026-04-15T20:15:39.899Z
title: Check and create missing Knowledge and Lessons docs
area: docs
files:
  - docs/KNOWLEDGE.md
  - docs/LESSONS.md
---

## Problem

`docs/KNOWLEDGE.md` and `docs/LESSONS.md` are both missing from the repository.
The session log from 2026-04-05 (`docs/sessions/2026-04-05-add-skill-enforcement.md`)
explicitly references KNOWLEDGE.md as created and populated with architecture patterns,
gotchas, key decisions, recurring patterns, and open questions — but the file does not
exist at `docs/KNOWLEDGE.md` or anywhere else in the project.

`docs/LESSONS.md` has no reference at all — it may be a GSD-standard artifact that
was never set up for this project.

Additionally, it is unclear whether the `episodic-memory:remembering-conversations`
skill or the session log process is responsible for creating/updating these files, and
whether they should live at `docs/`, `.planning/`, or elsewhere per GSD conventions.

## Solution

1. Check GSD conventions for KNOWLEDGE.md and LESSONS.md paths
   (`~/.claude/get-shit-done/workflows/` for any reference to these files)
2. Check git history for any deleted KNOWLEDGE.md: `git log --all --full-history -- docs/KNOWLEDGE.md`
3. If file was deleted: restore from history
4. If file never existed: create `docs/KNOWLEDGE.md` populated with content from
   the 2026-04-05 session log (§ KNOWLEDGE.md additions) and any subsequent learnings
5. Create `docs/LESSONS.md` if it is a GSD-required artifact
6. Ensure the session log process or episodic-memory skill creates/updates these files
   going forward — add to session log template if missing
