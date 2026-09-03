---
id: "mem_mss9cl0n_3d7a59ba6730"
type: "fact"
created: "2026-08-14T01:17:51.857Z"
updated: "2026-08-14T01:17:51.857Z"
strength: 7
version: 1
concepts: ["router-subagent-surfaces", "r14", "consistency", "CLEAN", "After-MVP", "OpenCode"]
files: []
---

# ROUND-14 CONSISTENCY LENS confirmation after R13 all-lenses CLEAN. Branch: main.

ROUND-14 CONSISTENCY LENS confirmation after R13 all-lenses CLEAN. Branch: main. No edits. No commit. No branch switch. Verdict: CLEAN. No Blockers/Highs/Mediums. No spec contradictions on this lens. Plans byte-identical: sha256 ff5208d926c531e61fc00d9de0b12d2d9cd6484f0de8d899011e4de4bc59fbd2 (196428 bytes, 644 lines) for .planning/router_subagent_surfaces_85bf9f09.plan.md and ~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md. Clarify L7 matches L49: MVP = Cursor host adapter; Codex/Claude/OpenCode host adapters after MVP. Plan After-MVP inventories include OpenCode (overview L50, document-control L81, non-goals L95, runtime table L156-159, host-adapters paragraph L362). Leftover phrase Codex/Claude host adapters after MVP without OpenCode: zero in plan and clarify. Historical five-tool INDEX/fallback remains at clarify L86. Six-gate list present at all enumerations: graphify-gate, agentmemory-gate, rtk-gate, context-mode-gate, leanctx-gate, token-compression-tools-gate. Phrase other four gates: zero. Four-case primary-checkout red test identical across 10 plan occurrences (sha afd851a050d06f45). Envelope vs env consistent: SB_PRIMARY_CHECKOUT is inherited process env; SB_WORKTREE_CWD is envelope + scope_bounds and not required in process env; hooks must not parse the envelope. Helper write-root: primary_checkout sole write root; fail-closed unless argument equals SB_PRIMARY_CHECKOUT or git main-worktree. Merge: git merge --no-commit then restore ledger-omit paths from pre-merge primary working-tree snapshot (not HEAD). WS3 owns invert/gates/named red test; WS6 consumes inverted helper for init/brownfield probe only and does not re-own it. Q4 dual-prefix, Q12 I two-clean, Q14 AF Val, Q18 val_* on AF/Workflow SM, Q21 Val always after V, Q22 all-scopes Val: SUPERSEDED in clarify banner and tables; plan has no live implementable Q answers. Roles: six roles with five preference keys; Authorizer not a preference key (inherits Verifier tuple). Live E2E is the MVP required test (real Cursor host, real subagent launch, real WBS path). Graphify CLI query/path/explain used (user-graphify MCP error). agentmemory MCP unavailable; REST POST /agentmemory/remember used.

## Concepts
#router-subagent-surfaces #r14 #consistency #CLEAN #After-MVP #OpenCode