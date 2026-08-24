---
id: "mem_mss8aqhe_bbf4218fa875"
type: "fact"
created: "2026-08-14T00:48:26.250Z"
updated: "2026-08-14T00:48:26.250Z"
strength: 7
version: 1
concepts: []
files: []
---

# ROUND-11 REVIEW hosts/five-tool lens. Branch: main (no edits). Repo plan === Cur

ROUND-11 REVIEW hosts/five-tool lens. Branch: main (no edits). Repo plan === Cursor mirror. Graphify CLI query+explain: hooks/token-compression-tools-gate.sh is the PreToolUse entrypoint (distinct from hooks/lib/token-compression-tools-gate.sh); hooks/stack-compression-coordinator.sh is its own entrypoint; hooks/graphify-gate.sh named-file oracle; hooks/lib/sb-project-gate.sh shared finder.

Verdict: CLEAN.
H-R10-H1 CLOSED: 10/10 ERR-trap lines name hooks/token-compression-tools-gate.sh; skip-vs-block and PWD-walk sentences name the entrypoint; WS3 implement-in lists the entrypoint; trap/PWD owner disclaimer (not hooks/lib/...) appears 4 times; lib-as-trap-owner positive mentions=0.
H-R10-H2 CLOSED: other four gates=0 in plan and clarify; enumerated PreToolUse lists are the six sb-project-gate sources (graphify, agentmemory, rtk, context-mode, leanctx, token-compression-tools-gate); Graphify-gate remains named-file oracle.
M-R10-H1 CLOSED: hooks/stack-compression-coordinator.sh on all 10 ERR-trap lines and WS3 owns/implement files; same-pattern hedge=0.
Invariants still hold: H1 four-case (1)-(4); SILVER_BULLET_PROJECT_ROOT extra-tree alias treated as unset; rt_git_main_worktree_root fail-closes; WS3 owns / WS6 consumes invert helper; Pi/brownfield warn+unselect; ILM-01 MVP vs MIG-01 post-MVP; opt-in then mandatory; session-start exports SB_PRIMARY_CHECKOUT from Task-capable ancestor.
Counts: other four gates remaining=0; lib-as-trap-owner remaining=0.