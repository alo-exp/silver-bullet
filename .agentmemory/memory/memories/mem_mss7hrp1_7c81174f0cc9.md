---
id: "mem_mss7hrp1_7c81174f0cc9"
type: "fact"
created: "2026-08-14T00:25:54.782Z"
updated: "2026-08-14T00:25:54.782Z"
strength: 7
version: 1
concepts: []
files: []
---

# Round-10 architecture spec close on router_subagent_surfaces_85bf9f09. Stay on m

Round-10 architecture spec close on router_subagent_surfaces_85bf9f09. Stay on main; both plan copies byte-identical; no commit; no product-code edits.

Closed: (1) BLOCKER H-R9-1 red-test matrix is four cases: env set binds primary; env unset + rt_git_main_worktree_root resolvable binds primary (H1, PWD must not win); both env and git unresolvable + five-tool opted in deny JSON not skip; repair/probe must not create extra-tree graphify-out/.agentmemory/.silver-bullet stamps. Deny only when both env and git fail. Graphify-gate is the named-file oracle; other gates share sb-project-gate. (2) Cursor Task has neither cwd nor per-child process-env. SB_PRIMARY_CHECKOUT is ancestor-process inheritance via session-start. Per-child SB_WORKTREE_CWD is envelope + scope_bounds + path-prefix, not process env; hooks must not parse envelope or require per-child SB_WORKTREE_CWD. Parallel extra trees take path-prefix from envelope/work-spec. Hosts that can set cwd/env may set both. (3) rt_git_main_worktree_root in scripts/lib/recommended-tools/common.sh fail-closes instead of extra-tree rt_git_toplevel; WS3 implement-in includes common.sh. (4) SILVER_BULLET_PROJECT_ROOT extra-tree alias treated as unset; gate entrypoints no copy-paste PWD walk after sb_find_project_config; every RT_PROJECT_ROOT in recommended-tools/ and install-leanctx inverted; token-compression-tools-gate same skip/block + primary bind; Q12 I-loop two-clean superseded (I has no self-attested two-clean). R9 closes retained: merge snapshot restore, helper env equality, skip vs block, WS3 owns invert / WS6 consumes, Pi/brownfield/ILM/MIG, path-prefix Cursor writes.