# Phase A spike — LeanCTX shell-rewrite regression

**Plan:** [autonomous-toolstack-reconciliation_2b7bddfa.plan.md](/Users/shafqat/.cursor/plans/autonomous-toolstack-reconciliation_2b7bddfa.plan.md) §3  
**Date:** 2026-07-17  
**Decision:** **Option 1** — remove LeanCTX shell-rewrite ownership entirely in `five_tool_routed`.

## Problem

After Cursor restarts, `lean-ctx init` / LeanCTX startup observers can re-insert a
`lean-ctx hook rewrite` PreToolUse entry into `~/.cursor/hooks.json`, competing with
RTK as `sb_shell` owner and causing double-wrap / ordering drift.

## Investigation

| Observation | Evidence |
|---|---|
| LeanCTX installer documents shell hook rewrite for compression | Upstream `lean-ctx` Cursor integration path |
| SB five-tool profile assigns `sb_shell` exclusively to RTK | `optimization_profiles.five_tool_routed.routes.sb_shell = rtk` |
| LeanCTX MCP overlap already disabled via env | `LEANCTX_DISABLE_SHELL_MCP=1` in merge scripts |
| Re-insertion is observer-driven, not required for wire/read/PathJail/injection | `install-leanctx-sb.sh` never runs `lean-ctx init --agent *` |

## Options evaluated

### Option 1 — Remove shell ownership (chosen)

- Strip every `lean-ctx hook rewrite` entry from `hooks.json` via `patch-hooks.py` and `fix-shell-compression-hook.py`.
- Rely on RTK `rtk hook cursor` (before Context Mode) as sole shell rewriter.
- LeanCTX retains `sb_wire`, `sb_read`, `sb_pathjail`, `sb_injection` only.

**Pros:** Prevents re-insertion from taking effect on next global hook patch; no race with LeanCTX startup observer.  
**Cons:** None for five-tool routed mode — shell MCP was already disabled on LeanCTX MCP server.

### Option 2 — RTK-first idempotent self-heal (not chosen)

Would require a PostSessionStart or periodic hook to re-order after LeanCTX observers run.

**Rejected:** Adds ongoing hook churn and still allows transient double-wrap windows.

## Implementation

- [`scripts/lib/global-toolstack/patch-hooks.py`](/Users/shafqat/.cursor/worktrees/repo/goja/scripts/lib/global-toolstack/patch-hooks.py) — filter out `lean-ctx hook rewrite` entries; insert `shell-compression.sh` only when missing.
- [`scripts/lib/global-toolstack/fix-shell-compression-hook.py`](/Users/shafqat/.cursor/worktrees/repo/goja/scripts/lib/global-toolstack/fix-shell-compression-hook.py) — same removal + RTK-before-CM ordering.
- [`scripts/lib/recommended-tools/probe-rtk.sh`](/Users/shafqat/.cursor/worktrees/repo/goja/scripts/lib/recommended-tools/probe-rtk.sh) — `leanctx_rewrite_present` evidence flag.
- [`scripts/lib/global-toolstack/session-bootstrap.sh`](/Users/shafqat/.cursor/worktrees/repo/goja/scripts/lib/global-toolstack/session-bootstrap.sh) — remains read-only verifier (no mutation).

## Verification

- `tests/hooks/test-five-tool-mutual-exclusion.sh` — RTK shell exclusivity.
- `tests/scripts/test-reconcile-recommended-tools.sh` — authorization + hook-order probes.
- Reconciler `cross_tool` component reports `leanctx_shell_rewrite` when rewrite reappears.

## Phase B note

Wire reconciler apply from `/silver:init`, `/silver:update`, installer, and `doctor --fix` so hook patches run after any LeanCTX package upgrade without manual `patch-hooks.py`.
