You are on rung 6/11: model=cursor/gemini-3.7-flash-high (Cursor Task gemini-3.7-flash-high, native Cursor Task only, no Pi, no agent-pi, no OmniRoute, no scripts/agent-pi/invoke.sh).
Phase: VERIFY-ONLY pass 2/2 (`rung_06_verify_2`)

This is `/silver:review-fix-ladder` only. Do **not** run `/silver:clarify`. Do not AskQuestion. Do not encode product forks. Do not combine with verify_1. Do **not** treat verify-1 as sufficient — re-audit independently and do not copy that verdict.

Scope (do not exceed — FORBIDDEN to Edit/Write either freeze copy):
- `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`
- `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

Independently re-hash both copies. Disk wins.
- Current disk SHA (locked): `3166a309baa55fb49158df4531c7bf7e8f8609f1c720b0f4d0cae5c396346321` / 621247 bytes
Record the SHA you actually hashed. Both copies must be byte-identical at that SHA/size.

Prior official review: `rung-06-cursor-gemini-3.7-flash-high/review.md` — **CLEAN**, HIGH 0 / MED 0 / LOW 0 / NIT 0, **Cursor Task Gemini (no Pi)**. Hashed current SHA `3166a309…`. Parent Policy A: **no ACCEPT to apply** this rung.
Prior official verify_1: `rung-06-cursor-gemini-3.7-flash-high/verify-1.md` — CLEAN / VERIFY_PASS, Cursor Task Gemini (no Pi), SHA `3166a309…`. Re-audit independently; do not copy that verdict.

Do not reopen F-1 `--` or F-2 HOLD as leftovers.

Prior ACCEPT HOLD/leftover table (none to apply this rung):
- F-1 REJECT: GFM single hyphen; `ws0--ws0b` = 0.
- F-2 HOLD: L3246 `#### \`blocked_advisor_state\` (row 14)`.
- Rung-2 Policy C APPLIED: F3 (`**What SB must not write:**`) and F4 (`may remain — that does **not** apply`).
- Rung-3 (Qwen) APPLIED: NIT-1 (`/sb:ladder\|parallel` at L141/L590) and NIT-2 (2-column appendix header at L4166).
- Rung-10 (Claude) APPLIED: NIT-1 (closed inline code backtick at L4122).
- YAML 33 pending; KEEP REJECT / Q1–Q3 / Part A then Part B closed; FAST not a Job.

You ARE allowed — and REQUIRED — to Write the verify report to this ABSOLUTE path (must exist when you finish):
`/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-final-review/rung-06-cursor-gemini-3.7-flash-high/verify-2.md`

Charter (same as review):
- Completeness/consistency; closed locks intact (KEEP REJECT, Q1–Q3, Part A then Part B, forbid `/sb:multi-ai-task` / `sb:agent-wrap`, FAST not a Job / not a legal compose route, OmniRoute routing-only).
- YAML exactly 33 todos, all `status: pending`.
- Exactly 1 mermaid fence in the freeze body.
- F-2 HOLD heading `blocked_advisor_state` (row 14).
- `ws0--ws0b` count = 0.
- Qwen NIT-1 / NIT-2.
- Claude NIT-1 L4122.
- F3 / F4 text.
- verify_1 leftovers none.

Template (HARD):
1. Graphify query before exploration. agentmemory `memory_save`. Retrieve via Graphify not memory dumps.
2. Remaining gaps with line refs (if any). Do not reopen closed F-1/F-2.
3. State VERIFY_PASS or VERIFY_FAIL — do not fix.
4. Write ONLY the report file named above with header `Cursor Task gemini-3.7-flash-high (no Pi)`. Do not Edit/Write the freeze copies.
5. Do not triage, do not launch subagents, do not expand scope, do not remap models.

The verify-2.md MUST include:
- Official-model honesty: you are Cursor Task `cursor/gemini-3.7-flash-high` (no Pi, no agent-pi, no OmniRoute)
- SHA-256 you hashed for each copy, sizes, byte-identical yes/no (`3166a309…` / 621247)
- Independent checks 1–13 with concrete evidence and line references
- Prior ACCEPT HOLD/leftover table (none to apply this rung; F-1 REJECT / F-2 HOLD)
- Remaining findings with line refs (if any)
- Finding counts: HIGH 0 / MED 0 / LOW 0 / NIT 0
- Verdict: CLEAN or NOT CLEAN, leftovers none-or-list, SHA, EXIT 0
- VERIFY_PASS or VERIFY_FAIL — do not fix
- Scope compliance verification

Print the same verdict on stdout after the file exists. Then stop.
Do not substitute Grok. This worker must stay `cursor/gemini-3.7-flash-high`.
