---
name: "silver:undo"
title: "Undo"
description: >
  Safe git revert for SB phase or plan commits. Shows recent commits,
  checks dependent phases, and requires confirmation before reverting.
argument-hint: "[--last N] [--phase NN] [--plan NN-MM] [--dry-run]"
version: 0.1.0
---

# /silver:undo — Safe Phase and Plan Revert

SB-owned undo workflow. Use when you need to roll back committed phase or plan
work while keeping `.planning/` artifacts consistent with the codebase.

Do NOT use raw `git revert` or `git reset` on SB phase work — those operations
leave STATE.md and SUMMARY.md artifacts pointing to non-existent code. This
skill handles artifact cleanup atomically.

## Output

Produces a revert commit (or dry-run report) and updates:

- `STATE.md` — resets phase status to `pending` or removes the plan from the
  completed list
- Preserves `.planning/phases/<phase>/` artifacts with a `REVERTED:` prefix in
  the plan STATUS field so the history is traceable

After completion:

```
SILVER BULLET > UNDO

Reverted: <scope description>
Commits reverted: <count>
Artifacts updated: STATE.md, <plan slugs>
Next: Phase <N> is now pending — re-run silver:execute when ready
```

## Modes

| Flag | Behaviour |
|------|-----------|
| `--last N` | Show the N most recent SB phase or plan commits and offer interactive selection |
| `--phase NN` | Revert all commits associated with phase NN |
| `--plan NN-MM` | Revert commits for plan MM within phase NN |
| `--dry-run` | Show what would be reverted without making changes |
| (none) | Default to `--last 10` interactive selection |

## Dependency Checks

Before reverting, the skill checks:

1. **Are any later phases or plans already executing?** If a phase after the
   target has commits, warn that reverting the earlier phase may break those
   later phases. Require explicit `--force` acknowledgment.

2. **Does the target phase have an open PR?** If yes, warn that the revert
   will conflict with any open PR referencing this work. List the PR URL.

3. **Are there uncommitted changes?** Require a clean working tree before
   reverting (standard git requirement).

## Process

1. Display `SILVER BULLET > UNDO`.
2. Identify scope from flags.
3. Run dependency checks (see above). Surface any warnings.
4. If `--last N` or no flags: list the N most recent commits that match SB
   phase/plan attribution patterns (commit messages with `[phase:NN]`,
   `[plan:NN-MM]`, or authored by SB subagents). Present a numbered list.
5. Confirm the exact commits to revert and what artifacts will be updated.
6. Unless `--dry-run`, require the user to type `yes` or respond `yes` before
   proceeding.
7. **Planning guard bypass:** before Write/Edit to `STATE.md` (or `ROADMAP.md`
   when artifact cleanup requires it), create
   `$HOME/.codex/.silver-bullet/roadmap-edit-override` and remove it after updates.
8. Run `git revert --no-commit` on each commit in reverse chronological order.
   Create a single revert commit with a structured message:
   ```
   revert(phase-NN): roll back <scope>

   Reverts: <list of original commit SHAs>
   Artifacts: STATE.md updated; SUMMARY.md files marked REVERTED
   ```
8. Update STATE.md to mark the affected phase as `pending` (or remove the
   plan from the completed list).
9. Prepend `REVERTED: ` to the STATUS field in each affected SUMMARY.md.
10. Display the post-revert state.

## Safety Rules

- **Never force-push.** Reverts produce new commits; they do not rewrite
  history.
- **Require a clean working tree.** Stash or commit any outstanding changes
  before invoking.
- **Never revert init or milestone bootstrap commits** without explicit
  `--force` — these set up foundational artifacts.
- **Always show the confirmation gate** before any revert unless `--dry-run`.
- If dependency checks reveal a conflicting later phase, require `--force` to
  override and log the decision in the revert commit message.

## Exit Gate

The skill is complete when:

- the revert commit exists in git history;
- STATE.md reflects the reverted state;
- any affected SUMMARY.md files are marked REVERTED;
- no uncommitted revert work remains (clean `git status`).
