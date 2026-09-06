# silver-worktree Scenario

## Purpose

Validate SB-owned isolated git worktree create and finish workflow.

## Expected Behavior

- Writes `.planning/WORKTREE.md`.
- Records source branch, target branch, worktree path, mode, and resume context.
- Checks uncommitted work before create or finish.
- Invokes `sb:branch-finish` before merge, PR, or cleanup.
- Blocks destructive cleanup unless safety and user decision are recorded.
