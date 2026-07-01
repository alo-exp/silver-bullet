---
name: "silver:worktree"
title: "Worktree"
description: >
  This skill should be used for SB-owned isolated git worktree setup, finish,
  merge/PR handoff, and cleanup safety.
argument-hint: "create|finish <branch or scope>"
version: 0.1.0
---

# /silver:worktree - Isolated Branch Workspace

SB-owned worktree workflow for branch-safe development and structured finish.

## Output

Write or update `.planning/WORKTREE.md`.

The artifact must include:

- source branch, worktree path, and target branch;
- create or finish mode;
- uncommitted-change safety check;
- verification/CI/ship evidence before merge or PR;
- cleanup decision.

## Modes

| Mode | Purpose |
|---|---|
| `create` | Choose a safe worktree path, create an isolated branch workspace, and record how to resume |
| `finish` | Verify branch state, offer merge/PR/keep/cleanup paths, and route through SB ship gates |

## Process

1. Display `SILVER BULLET > WORKTREE`.
2. For `create`, check current git state and avoid moving uncommitted work into
   an ambiguous branch. Create a clearly named branch/worktree only after the
   target base is known.
3. Record resume commands and active workflow context in `.planning/WORKTREE.md`.
4. For `finish`, run status, diff, tests, and SB review/verify evidence checks.
5. Invoke `silver:branch-finish` before merge, PR, or cleanup decisions.
6. Do not delete a worktree unless it is clean, merged or intentionally
   abandoned, and the user decision is recorded.

## Exit Gate

Worktree finish passes only when branch state, verification, merge/PR decision,
and cleanup decision are explicit and no untracked user work would be lost.
