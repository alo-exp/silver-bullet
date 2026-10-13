# Decision — Global Status (GST-01) + Job = user intent (2026-08-16)

Locked into router_subagent_surfaces_85bf9f09 plan (clarify round-6). Did not stop for user questions.

1. **Job** = user intent (`original_intent_hash` at `/sb` resolve). Not a Process packet, not `launch_id`, not the Task five-field hash.
2. **Global Status** path: `.sb/status/STATUS-YYMMDD.md` (UTC) on `origin/main`. All SB instances. Identity `{git_user_id}'s SB`.
3. Writer: Orchestrator-only named helper `hooks/lib/global-status-projector.sh`. Does **not** replace local ASCII WBS viz (WBS-01).
4. Fail-closed: CAS/retry no force-push; `[skip ci]` + CI `paths-ignore`; `blocked_global_status_push` / `blocked_global_status_identity`.

Clarify: `.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`
Plan SHA-256: `f4f696a64cb6642ee7f8d02757f24802906c802c787b8b109b9d99a22130a29d`
Traceability GST-01 (`VAL/TST-RFL-621`).
