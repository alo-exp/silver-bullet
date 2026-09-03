---
id: "mem_mss74bdq_c396a38e13d3"
type: "fact"
created: "2026-08-14T00:15:27.118Z"
updated: "2026-08-14T00:15:27.118Z"
strength: 7
version: 1
concepts: []
files: []
---

# Round-9 CONTROL-PLANE lens. Stay on main. No edits.

DOC: Both plan copies byte-

Round-9 CONTROL-PLANE lens. Stay on main. No edits.

DOC: Both plan copies byte-identical (167725 bytes, sha256-head be93d53f519756bd). Entire doc is architecture spec (title Architecture and Design Change; Document control: The body is the spec). No ## Pending user lock. Clarify brief banner supersedes contradicting Qs (Q4/Q5/Q7/Q9c/Q11/Q14/Q18/Q21/Q22 Val scope).

VERDICT: NOT CLEAN

BLOCKER: Named red test oracle contradicts R8 #1 close. Testing/WBS-01/validation-tests: 'env unset + five-tool opted in -> deny JSON (not empty skip)'. Shared-state/Hosts: SB_PRIMARY_CHECKOUT or rt_git_main_worktree_root ALWAYS binds even when extra-tree cwd has .silver-bullet.json + silver-bullet.md; PWD walk must not win. Extra-tree is a git worktree of the same repo, so main-worktree is resolvable when env is unset. Deny-on-env-unset un-closes R8 extra-tree PWD blocker. Correct deny case: env unset AND main-worktree unresolvable.

HIGH: Cursor Task has no env field (R8: no cwd/env field). Spec does not pretend Task has cwd (closed). Spec still says adapter/launch exports per-child process env SB_PRIMARY_CHECKOUT + SB_WORKTREE_CWD. Cursor Task API cannot set env. Parallel extra-trees cannot share one inherited SB_WORKTREE_CWD. Need: ancestor-process inheritance for SB_PRIMARY_CHECKOUT (session-start); envelope + work-spec + path-prefix only for per-child SB_WORKTREE_CWD; hooks bind to PRIMARY and must not require per-child WORKTREE_CWD.

HIGH: invert fallback function rt_git_main_worktree_root (scripts/lib/recommended-tools/common.sh) currently falls back to rt_git_toplevel when porcelain list empty. Spec names it as the invert fallback ('never extra-tree rt_git_toplevel') but does not require that helper itself fail-closed instead of returning extra-tree toplevel.

R8 closes in body (otherwise): (1) sb-project-gate honors SB_PRIMARY_CHECKOUT / SILVER_BULLET_PROJECT_ROOT before PWD; always bind even if extra-tree json+md exist. (2) Cursor Task has no cwd; sparse extra WT+branch; path-prefix to SB_WORKTREE_CWD; process cwd may remain primary; merge extra-tree branch; hosts that can set cwd use worktree_cwd. (3) Skip=no deny JSON+exit 0; Block=emit_block deny JSON+exit 0 Cursor / exit 2 Kay; ERR trap must not swallow. (4) invert graphify-worktree.sh; probe-graphify/repair-graphify/session-verify/session-start/probe-agentmemory named.

CLEAN on this lens: projector-only WBS writer fail-closed unless write-root equals $SB_PRIMARY_CHECKOUT; spawn-proxy helper path $primary_checkout/.planning/sb-spawn-proxy.jsonl; parent-guard allowlists projector + spawn-proxy + orchestrator-worktree-merge.sh; merge merge-base..worktree-branch + filesystem presence; git merge --no-commit then restore ledger-omit from pre-merge primary working-tree snapshot NOT HEAD; extra trees host_native only; /sb:agent-* cwd=primary; hooks never invoke Task; Authorizer admits; Task-capable session starts child; prefix sb/sb:/ /sb only; Val process-final only; AF/Workflow stop at V; live E2E is MVP required test.

Graphify: query/path/explain used. agentmemory MCP memory_save unavailable this session (not in ~/.cursor/mcp.json); captured via POST /agentmemory/remember. id pending.
