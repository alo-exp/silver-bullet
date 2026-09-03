You are on rung 6/11: model=cursor/gemini-3.7-flash-high (Cursor Task gemini-3.7-flash-high, native Cursor Task only, no Pi, no agent-pi, no OmniRoute, no scripts/agent-pi/invoke.sh). User-named Gemini — do **not** remap to Grok. Never Fast.
Phase: VERIFY-ONLY pass 1/2 (`rung_06_verify_1`)

This session parent: `d5150f38-4d37-458d-9bdb-5e6f985975d3`.
This is `/silver:review-fix-ladder` only. Do **not** run `/silver:clarify`. Do not AskQuestion. Do not encode product forks. Do not combine verify_2. Do not copy `review.md` — re-derive every check from disk.

Scope (read-only freeze — FORBIDDEN to Edit/Write either freeze copy):
- `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`
- `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

**Locked freeze (Current canonical):**
- SHA-256: `3166a309baa55fb49158df4531c7bf7e8f8609f1c720b0f4d0cae5c396346321`
- Size: **621247** bytes
- Both copies must be byte-identical. Independently re-hash. Disk wins. Record the SHA you actually hashed.

Prior review: `./review.md` — **CLEAN**, HIGH 0 / MED 0 / LOW 0 / NIT 0, **Cursor Task Gemini CLEAN** (no Pi), APPLY no. Hashed `3166a309…` / 621247. Parent Policy A: **no ACCEPT to apply**. Do not reopen F-1 `--` or F-2 HOLD as leftovers.

You ARE allowed — and REQUIRED — to Write the verify report to this relative path in the work dir (must exist when you finish):
`./verify-1.md`

Stale Pi `verify-1.md` (from `edff7c0c…` / 621101 and earlier) has been archived to `verify-1-prior-pi.md`. Write a fresh official verify-1 against `3166a309…` / 621247.

Closed / do not reopen:
- F-1 REJECT: GFM single hyphen; exact string `ws0--ws0b` count must stay **0**
- F-2 HOLD: `#### \`blocked_advisor_state\` (row 14)` — confirm still there; do not score as APPLY-miss
- Rung-2 Policy C **APPLIED** and closed: F3 (NIT — misnested bold markers) and F4 (LOW — truncated lock sentence). Confirm APPLY text on disk; do not re-file unless missing.
- Rung-3 (Qwen) APPLIED / closed: NIT-1 (escaped pipes at L141/L590) and NIT-2 (2-column appendix header at L4166).
- Rung-10 (Claude) APPLIED / closed: NIT-1 (closed inline code backtick at L4122).
- YAML 33 pending; KEEP REJECT / Q1–Q3 / Part A then Part B closed; FAST not a Job.

Independent checks (re-run; do not copy review.md):
1. SHA-256 + size of **both** copies; byte-identical yes/no; match `3166a309…` / 621247.
2. YAML frontmatter: 33 unique todo ids, all `status: pending` (33/33).
3. Exactly **1** mermaid fence in the freeze body.
4. F-2 HOLD still present (`blocked_advisor_state` row 14 duplicate heading).
5. Exact string `ws0--ws0b` count = 0.
6. Qwen NIT-1 escaped pipes L141/L590 present (`/sb:ladder\|parallel`).
7. Qwen NIT-2 2-col appendix header present (`| Named test path | Note |`).
8. Claude NIT-1 L4122 closed backticks present and balanced.
9. F3 APPLY text present on the three host tables: `**What SB must not write:**`.
10. F4 APPLY text present on the lock bullets: `may remain — that does **not** apply`.
11. KEEP REJECT closed; Q1–Q3 decided; Part A then Part B intact.
12. FAST is **not** a Job (not GST, not legal compose route).

Tasks:
1. Graphify query before exploration. agentmemory `memory_save`. Retrieve via Graphify, not memory dumps.
2. Re-read scoped freeze and audit against charter + the independent checks above.
3. Remaining gaps with line refs (if any). Do not fix.
4. State CLEAN / NOT CLEAN and VERIFY_PASS or VERIFY_FAIL with evidence.
5. Write ONLY `./verify-1.md` with header `Cursor Task gemini-3.7-flash-high (no Pi)`. Print the same verdict on stdout after the file exists. Then stop.

The verify-1.md MUST include:
- Official-model honesty: Cursor Task `cursor/gemini-3.7-flash-high` (no Pi, no agent-pi, no OmniRoute)
- SHA-256 you hashed for each copy, sizes, byte-identical yes/no (`3166a309…` / 621247)
- Independent checks 1–12 with concrete evidence and line references
- Prior ACCEPT HOLD/leftover table (none to apply this rung; F-1 REJECT / F-2 HOLD)
- Remaining findings with line refs (if any)
- Verdict: CLEAN or NOT CLEAN, leftovers none-or-list, SHA, EXIT
- VERIFY_PASS or VERIFY_FAIL — do not fix

FORBIDDEN: freeze Edit/Write, YAML execute, git branch switch, `/silver:clarify`, AskQuestion, combining verify passes, triage, checkout/commit, remapping models, copying review.md, Grok-substitute, starting verify_2 or rung 7.
This worker must stay `cursor/gemini-3.7-flash-high`.
