# Leftover checkout resolution (2026-08-13)

## a9385078
- PRESERVE / out of scope. This session never ran worktree remove/prune/reset on `cursor/a9385078`.
- `git worktree list` for this repo never showed an a9385078 path; no restore attempted (path/branch/HEAD unknown).

## Leftover 1 — fix/sb-deferred-263-282
- Unique: fcff2cb7 memory snapshot only; product on origin/main via PR #285 (a0c5c340, a379d040, f1e1853e).
- Closed: switched to main @ a0c5c340; branch deleted with -D (memory-only unique).

## Leftover 2 — claude/codex-cloud-usage-guide-30dna0
- Unique: 7357161c agentmemory PR#246 thermo note only. No product change.
- Deleted local branch (-D).

## Leftover 3 — fix-sb-bug-f-252-tri-host-timeout
- Commits: none unique (692027d5 ancestor of main / PR #255).
- Uncommitted valuable: plugin mirror config_version 0.51.7→0.52.0 (source already 0.52.0).
- Applied via PR #286 (e20b872b). Catalog/.silver-bullet.json noise discarded; worktree+branch removed.

## origin/main
- Still contains a0c5c340 and session ancestors.
