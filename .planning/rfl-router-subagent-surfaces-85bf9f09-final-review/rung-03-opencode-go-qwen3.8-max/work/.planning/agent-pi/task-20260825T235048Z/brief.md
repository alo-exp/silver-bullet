You are on rung 3/11: model=opencode-go/qwen3.8-max, reasoning=host-default.
Phase: VERIFY-ONLY pass 1/2 (`rung_03_verify_1`)

This is `/silver:review-fix-ladder` only. Do **not** run `/silver:clarify`. Do not AskQuestion.

Scope (FORBIDDEN to Edit/Write either freeze copy):
- `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`
- `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

Independently re-hash both copies. Disk wins.
Locked expected SHA: `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0` / 621095 bytes.
Prior review (stale SHA `0e8510e0…` / 621086): `rung-03-opencode-go-qwen3.8-max/review.md` (NOT CLEAN F-1 MED + F-2 NIT).

Parent Policy A already applied:
- **F-1 MED REJECT** — do not expect `--` TOC/body hrefs. GFM = strip punct then collapse whitespace to a **single** hyphen. `ws0--ws0b` must remain 0.
- **F-2 NIT ACCEPT** — HOLD: heading `#### \`blocked_advisor_state\` (row 14)` at L3246 (backticks around the identifier). Canonical twin L3052 unchanged.
- YAML 33 pending. KEEP REJECT / Q1–Q3 / Part A then Part B closed.

You ARE required to Write ONLY this report (must exist when you finish):
`/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-final-review/rung-03-opencode-go-qwen3.8-max/verify-1.md`

Tasks:
1. Re-read scoped freeze and audit against charter (33 pending YAML; forbid-only multi-ai-task / agent-wrap; FAST not a Job / not a compose route; E→Ver→Val + thin capture; OmniRoute routing-only; KEEP REJECT / Q1–Q3 / Part A then Part B; LS-post-val-kl Executor producer; single mermaid; TOC-GFM single-hyphen not `--`).
2. Report remaining gaps with line refs. HOLD F-2; do not treat F-1 as leftover.
3. State VERIFY_PASS or VERIFY_FAIL with evidence — do not fix.
4. verify-1.md MUST include: SHA-256 each copy + sizes + byte-identical; Prior ACCEPT HOLD/leftover table (F-2 HOLD; F-1 REJECT held — no `--`); remaining findings; Verdict CLEAN or NOT CLEAN; leftovers none-or-list; SHA; EXIT; VERIFY_PASS or VERIFY_FAIL.

FORBIDDEN: freeze Edit/Write, clarify, AskQuestion, combining verify passes, remapping models.