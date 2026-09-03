# Decision — Round-16 ACCEPT (agent-* Executor mint + HINST-01, 2026-08-16)

Locked into router_subagent_surfaces_85bf9f09 plan (clarify round-16). Stay on `main`. No commit. Max not started. No Fast.

## Retracted lock

Retract: `/sb:agent-*` may dispatch catalog AF/WF ids but may not invent a new WF.

## New lock A

Every `/sb:agent-*` (Cursor, Codex, Claude, OpenCode, Pi) is an Executor for Workflow mint. May invent a new WF only in-plan (cited `plan_node_id` / WBS id). Out-of-plan → `blocked_executor_wf_out_of_plan` → Advisor. Catalog wrap `sb:agent-wrap` / `AF-agent-delegate` is the dispatch envelope. Orchestrator/`/sb` still does not compose or mint. FAST still classify-not-mint.

## New lock B — HINST-01 / VAL/TST-RFL-624

Same Init/Doctor pass as HNEST-01. Ensure SB on present Cursor/Codex/Claude via `scripts/install-{cursor,codex,claude}.sh`. Detect: CLI or `~/.cursor` / `~/.codex` / `~/.claude`. OpenCode/Pi instruction-only; preference parent-or-Cursor→Codex→Claude. `blocked_sb_host_missing` / `blocked_sb_host_install`. Parent-proxy only at remaining_depth 0 for installable hosts.

Plan SHA-256 (both copies, byte-identical): `d9d452eee1d4ed2307cdc9c195d42afaf03889ab18923e52cc48ca8e72bdd172`
Prior frozen SHA (round-14): `18ac07bbc763241d023681a14aab1261d6b1d7be13f9e364bff5caba8c4614b4`
