---
name: "silver:phase"
title: "Phase"
description: >
  CRUD management for phases in .planning/ROADMAP.md — add, insert, remove,
  or edit phases. The only sanctioned way to modify the phase list without
  triggering the planning-file-guard.
argument-hint: "[--add <goal>] [--insert N <goal>] [--remove N] [--edit N] [--list]"
version: 0.1.0
---

# /silver:phase — Phase CRUD Management

SB-owned skill for managing phases in `.planning/ROADMAP.md`. Direct edits to
ROADMAP.md are blocked by the planning-file-guard; this skill is the sanctioned
path for all phase list mutations.

Do not use this skill to add execution work or change acceptance criteria — that
belongs in `/silver:context`. This skill only manages the roadmap structure.

## Output

The skill writes updates to `.planning/ROADMAP.md` and `.planning/STATE.md`
(when a phase is removed or reordered).

After any mutation, display a summary:

```
SILVER BULLET > PHASE

Action: <add|insert|remove|edit|list>
Phase: <number or range>
Result: <brief description of what changed>

ROADMAP after:
<the relevant ROADMAP.md section>
```

## Operations

### `--list` (default when no flags)

Display all phases with status, goal, and current phase pointer.

```bash
/silver:phase --list
```

### `--add "<goal>"`

Append a new phase at the end of the active milestone with the given goal.

```bash
/silver:phase --add "Add real-time notifications via WebSocket"
```

**Requires:** `.planning/ROADMAP.md` exists.
**Produces:** New phase entry at the bottom of the active milestone.
**Asks:** Confirm goal text before writing if not `--auto`.

### `--insert N "<goal>"`

Insert urgent or prerequisite work as a decimal phase after phase N.
Example: inserting after phase 3 creates phase 3.1.

```bash
/silver:phase --insert 3 "Fix auth race condition before feature work"
```

**Requires:** Phase N exists in ROADMAP.md.
**Produces:** New decimal phase inserted in sequence.
**Safety:** Warns if phase N is `completed`; refuses if N is `in_progress`
without `--force`.

### `--remove N`

Remove a future phase and renumber subsequent phases to preserve numeric
continuity.

```bash
/silver:phase --remove 7
```

**Requires:** Phase N must be `pending` (not started, not completed).
**Safety:** Lists phases that would be renumbered and requires confirmation.
**Refuses:** Removing `in_progress` or `completed` phases without `--force`.

### `--edit N`

Edit any field of an existing phase interactively: goal, requirements
coverage, mode annotation, or acceptance criteria reference.

```bash
/silver:phase --edit 5
```

**Requires:** Phase N exists.
**Asks:** Which field to edit; presents current value; confirms before writing.
**With `--force`:** Allows editing `in_progress` or `completed` phases.

## Flags

| Flag | Effect |
|------|--------|
| `--auto` | Skip confirmation prompts; apply change immediately |
| `--force` | Allow editing or removing in-progress/completed phases |
| `--dry-run` | Show what would change without writing to ROADMAP.md |

## Process

1. Display `SILVER BULLET > PHASE`.
2. Verify `.planning/ROADMAP.md` exists. If not, ask whether to run
   `/silver:init` first.
3. Read ROADMAP.md and STATE.md to understand current phase status.
4. Validate the operation against the safety rules below.
5. In interactive mode (no `--auto`), show the planned change and require
   explicit confirmation before writing.
6. **Planning guard bypass:** `planning-file-guard` blocks direct ROADMAP.md and
   STATE.md edits. Before any Write/Edit to those files, create the override
   marker, then remove it when mutations finish:
   ```bash
   touch "$HOME/.codex/.silver-bullet/roadmap-edit-override"
   # ... Write/Edit ROADMAP.md and STATE.md ...
   rm -f "$HOME/.codex/.silver-bullet/roadmap-edit-override"
   ```
7. Write the change to ROADMAP.md.
8. Update STATE.md `phase_count` and `current_phase` if affected by a
   removal or reorder.
9. Display the post-mutation ROADMAP.md section.

## Safety Rules

- **Never remove a phase whose status is `in_progress` or `completed`**
  unless `--force` is supplied. Removing executed work loses planning
  artifacts.
- **Never renumber a phase below the current `current_phase`** pointer in
  STATE.md without warning.
- **Never set a phase goal to empty.** A phase must have a goal to be
  plannable.
- **Always confirm destructive operations** (remove, force-edit of completed)
  with the user unless `--auto` is set.
- Decimal phases (e.g., 3.1) are valid for urgent inserts but must be
  promoted to integer numbering when the milestone is re-baselined.

## Exit Gate

The skill is complete when:

- ROADMAP.md reflects the intended state;
- STATE.md is consistent with the new phase list;
- the user has confirmed any destructive or force-overridden change.
