---
id: "mem_mss81z99_64e17e5bbec2"
type: "fact"
created: "2026-08-14T00:41:37.717Z"
updated: "2026-08-14T00:41:37.717Z"
strength: 7
version: 1
concepts: []
files: []
---

# ROUND-11 plan-only close of remaining R10 findings. Stay on main. No commit. Bot

ROUND-11 plan-only close of remaining R10 findings. Stay on main. No commit. Both plan copies byte-identical.
1. Trap/PWD owner is hooks/token-compression-tools-gate.sh (live PreToolUse entrypoint). hooks/lib/token-compression-tools-gate.sh has no trap/PWD; kept in WS3 as implement surface only.
2. Graphify-gate remains named-file oracle. All PreToolUse gates that source sb-project-gate share the bind: graphify-gate, agentmemory-gate, rtk-gate, context-mode-gate, leanctx-gate, token-compression-tools-gate. Replaced every other-four-gates undercount.
3. hooks/stack-compression-coordinator.sh HEAD uses trap exit 0 ERR + sb_find_project_config + PWD search_dir; named in ERR-trap/no-PWD-walk list and WS3 implement files. Dropped if-it-uses-the-same-pattern hedge.
4. Every RT_PROJECT_ROOT assignment under scripts/ inverts to $SB_PRIMARY_CHECKOUT then rt_git_main_worktree_root, never extra-tree PWD/show-toplevel. Named scripts/reconcile-recommended-tools.sh and scripts/optimize-rtk-context-mode.sh plus recommended-tools/ and install-leanctx-sb.sh.
R10 closes preserved: four-case red-test matrix; ancestor inheritance of SB_PRIMARY_CHECKOUT; per-child SB_WORKTREE_CWD envelope-only; rt_git_main_worktree_root fail-close; common.sh in WS3; merge snapshot restore; helper env equality; skip vs block; WS3 owns invert / WS6 consumes.