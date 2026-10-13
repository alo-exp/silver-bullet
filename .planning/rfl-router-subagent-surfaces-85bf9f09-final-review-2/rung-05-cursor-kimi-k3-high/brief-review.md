# Rung 5 brief (review-only) — charter copy

- RFL round 2, rung 5, review-only of the `router_subagent_surfaces_85bf9f09` freeze. Parent: d5150f38-4d37-458d-9bdb-5e6f985975d3.
- Model lock: Cursor Task kimi-k3-high (`sb-kimi-k3-high`). No Pi / agent-pi / OmniRoute / invoke.sh. No remap to kimi-k3-max. No Grok substitute.
- Phase: `rung_05_review` only. Raw findings. No triage, no ACCEPT/REJECT, no Policy C, no APPLY, no verify, no freeze edits. Do not start rung 6. Do not retry OpenCode rungs 1–3. Do not execute freeze YAML. No commit/push. Branch main; never checkout/switch/SetActiveBranch.
- Graphify first; agentmemory `memory_save` after review; ctx_* for large analysis; native Read for quoted sections; no compression markers in review.md.
- Freeze copies hashed live: repo `.planning/router_subagent_surfaces_85bf9f09.plan.md` and `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`. Known SHA-256 (post rung-4 APPLY): `d620d812388d26d8c8885243d09f7742ec5a7e7fd8357b038245310d34221ab0` / 641529 bytes.
- Scope: bird's-eye + ant's-eye over TOC, KEEP REJECT (§3.3), live-spec MUST catalog, control-plane roles, ship sequence, workstreams, failure-mode rows 1–42, Appendix D, clarify Q1–Q3; line-level on the 8 mandated topics.
- KEEP REJECT items must remain present; do not reopen. F-2 HOLD: duplicated `blocked_advisor_state` (row 14) heading is intentional — not filed. Rung-4 ACCEPT-applied §4.2 label fixes; only L4208-area `Proposed architecture` is legitimate; re-raise NIT-1 only for a NEW stale `§4.2 Proposed architecture` cross-ref.
- Output: `review.md` (first line `# Cursor Task kimi-k3-high (no Pi)`, ≥2500 bytes), verdict CLEAN/NOT CLEAN, counts HIGH/MED/LOW/NIT, findings with ID/severity/location/observed/impact/recommendation. Parent does Policy C.
