# Decision — Round-14 ACCEPT (Extra High retained + two user locks, 2026-08-16)

Locked into router_subagent_surfaces_85bf9f09 plan (clarify round-14). Stay on `main`. No commit. Max not started. No Fast.

Real Extra High H-1–H-5 / M-1–M-5 retained from round-13. Two user overrides applied.

## User override A — item 7 narrowed

Initial user-intent Process wrap still mints at `/sb`. Nested/opportunistic Workflow mint or invoke does NOT return to Orchestrator or `/sb`. Any Executor may `wf_mint` / `wf_invoke`. Authorizer admits. Not a second Process. Rows 37–38: `blocked_wf_mint_unauthorized`, `blocked_af_under_process`.

## User override B — host settings revoked

Init/Doctor writes documented max nested-subagent support (`VAL/TST-RFL-623` / HNEST-01).

- Cursor: **2 Task hops** below main (Cursor 2.5; https://cursor.com/docs/subagents). No writable knob. Adapt via `remaining_depth`.
- Codex: **no documented numeric max** (https://developers.openai.com/codex/multi-agent). May set `agents.enabled = true`. Do not write `max_depth`.
- Claude: **3 subagent layers** via `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (https://code.claude.com/docs/en/env-vars). Write `3` if unset/below.

Plan SHA-256 (both copies, byte-identical): `18ac07bbc763241d023681a14aab1261d6b1d7be13f9e364bff5caba8c4614b4`
Prior frozen SHA (round-13): `4f772f9f618ae42aa2ecd573c2c5a813af8d22c29f719f97a5f12106efee2d1d`
