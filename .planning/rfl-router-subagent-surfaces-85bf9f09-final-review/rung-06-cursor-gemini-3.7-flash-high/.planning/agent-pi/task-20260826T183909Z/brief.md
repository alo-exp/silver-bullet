You are on rung 6/11: model=cursor/gemini-3.7-flash-high (Gemini 3.7 Flash High via `/silver:agent-pi` / OmniRoute). User-named Gemini — do **not** remap to Grok. Never Fast.
Phase: VERIFY-ONLY pass 1/2 (`rung_06_verify_1`)

This session parent: `d5150f38-4d37-458d-9bdb-5e6f985975d3`.
This is `/silver:review-fix-ladder` only. Do **not** run `/silver:clarify`. Do not AskQuestion. Do not encode product forks. Do not combine verify_2. Do not copy `review.md` — re-derive every check from disk.

Scope (read-only freeze — FORBIDDEN to Edit/Write either freeze copy):
- `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`
- `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

**Locked freeze (NEW — not `d5343ac1…` / 621095, not `07b98609…` / 620985):**
- SHA-256: `edff7c0cca55e7e6662cafbbf3f10cea71230483c4992c2a5d5149c629a63e5e`
- Size: **621101** bytes
- Both copies must be byte-identical. Independently re-hash. Disk wins. Record the SHA you actually hashed.

Prior review: `./review.md` — **CLEAN**, HIGH 0 / MED 0 / LOW 0 / NIT 0, **Pi Gemini EXIT 0** (not Grok), APPLY no. Hashed `edff7c0c…` / 621101. Parent Policy A: **no ACCEPT to apply**. Do not reopen F-1 `--` or F-2 HOLD as leftovers.

You ARE allowed — and REQUIRED — to Write the verify report to this relative path in the work dir (must exist when you finish):
`./verify-1.md`

Existing `verify-1.md` is a **stale leftover** from SHA `d5343ac1…` / `07b98609…` — overwrite with a fresh official verify-1 against `edff7c0c…` / 621101.

Closed / do not reopen:
- F-1 REJECT: GFM single hyphen; exact string `ws0--ws0b` count must stay **0**
- F-2 HOLD: L3246 `#### \`blocked_advisor_state\` (row 14)` — confirm still there; do not score as APPLY-miss
- Rung-2 Policy C **APPLIED** and closed: F3 (NIT — misnested bold markers) and F4 (LOW — truncated lock sentence). Confirm APPLY text on disk; do not re-file unless missing.
- YAML 33 pending; KEEP REJECT / Q1–Q3 / Part A then Part B closed

Independent checks (re-run; do not copy review.md):
1. SHA-256 + size of **both** copies; byte-identical yes/no; match `edff7c0c…` / 621101.
2. YAML frontmatter: 33 unique todo ids, all `status: pending` (33/33).
3. Exactly **1** mermaid fence in the freeze body.
4. F-2 HOLD still at L3246 (`blocked_advisor_state` row 14 duplicate heading).
5. Exact string `ws0--ws0b` count = 0.
6. F3 APPLY text present on the three host tables: `**What SB must not write:**`.
7. F4 APPLY text present on the lock bullets: `may remain — that does **not** apply`.
8. KEEP REJECT closed; Q1–Q3 decided; Part A then Part B intact.
9. FAST is **not** a Job (not GST, not legal compose route).

Tasks:
1. Graphify query before exploration. agentmemory `memory_save`. Retrieve via Graphify, not memory dumps.
2. Re-read scoped freeze and audit against charter + the independent checks above.
3. Remaining gaps with line refs (if any). Do not fix.
4. State CLEAN / NOT CLEAN and VERIFY_PASS or VERIFY_FAIL with evidence.
5. Write ONLY `./verify-1.md`. Print the same verdict on stdout after the file exists. Then stop.

The verify-1.md MUST include:
- Official-model honesty: you are Pi `cursor/gemini-3.7-flash-high`
- SHA-256 you hashed for each copy, sizes, byte-identical yes/no (must be `edff7c0c…` / 621101, not `d5343ac1…` / 621095, not `07b98609…`)
- F3/F4 APPLY confirmation with line refs
- F-2 HOLD confirmation at L3246
- Prior ACCEPT HOLD/leftover table (none to apply this rung; F-1 REJECT / F-2 HOLD)
- Remaining findings with line refs (if any)
- Verdict: CLEAN or NOT CLEAN, leftovers none-or-list, SHA, EXIT
- VERIFY_PASS or VERIFY_FAIL — do not fix

FORBIDDEN: freeze Edit/Write, YAML execute, git branch switch, `/silver:clarify`, AskQuestion, combining verify passes, triage, checkout/commit, remapping models, copying review.md, Grok-substitute, starting verify_2 or rung 7.
This worker must stay `cursor/gemini-3.7-flash-high`.