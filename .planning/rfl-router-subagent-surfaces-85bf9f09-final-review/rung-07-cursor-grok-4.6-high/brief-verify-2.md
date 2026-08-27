You are on rung 7/11: model=cursor/grok-4.6-high (Cursor Task cursor-grok-4.6-high, native Cursor Task only, no Pi, no agent-pi, no OmniRoute, no scripts/agent-pi/invoke.sh). Never Extra High / XHigh. Never Fast.
Phase: VERIFY-ONLY pass 2/2 (`rung_07_verify_2`)

This session parent: `d5150f38-4d37-458d-9bdb-5e6f985975d3`.
This is `/silver:review-fix-ladder` only. Do **not** run `/silver:clarify`. Do not AskQuestion. Do not encode product forks. Do not combine with verify_1. Do not copy `verify-1.md` or `review.md` — re-derive every check from disk.

Scope (read-only freeze — FORBIDDEN to Edit/Write either freeze copy):
- `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`
- `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

**Locked freeze (Current canonical):**
- SHA-256: `3166a309baa55fb49158df4531c7bf7e8f8609f1c720b0f4d0cae5c396346321`
- Size: **621247** bytes
- Both copies must be byte-identical. Independently re-hash. Disk wins. Record the SHA you actually hashed.
- Historical (do not treat as current): charter-start `07b98609…` / 620985; prior-wave `d5343ac1…` / 621095; prior Pi-rung `edff7c0c…` / 621101

Prior review: `./review.md` — **CLEAN**, HIGH 0 / MED 0 / LOW 0 / NIT 0, **Cursor Task Grok 4.6 High CLEAN** (no Pi), APPLY no. Hashed `3166a309…` / 621247. Parent Policy A: **no ACCEPT to apply**. Do not reopen F-1 `--` or F-2 HOLD as leftovers. Do **not** re-file L7-01 unless L129 href no longer matches the live H2 GFM slug.

Prior official verify_1: `./verify-1.md` — **CLEAN** / **VERIFY_PASS** (Cursor Task Grok 4.6 High, no Pi). Leftovers **none**. APPLY no. Re-audit independently; do **not** copy that verdict or that file.

You ARE allowed — and REQUIRED — to Write the verify report to this relative path in the work dir (must exist when you finish, ≥2500 bytes, not a stub):
`./verify-2.md`

Stale Pi `verify-2.md` (from `edff7c0c…` / 621101 and earlier) has been archived to `verify-2-prior-pi.md`. Write a fresh official verify-2 against `3166a309…` / 621247. Header of `verify-2.md` MUST be exactly: `Cursor Task cursor-grok-4.6-high (no Pi)`.

Closed / do not reopen:
- F-1 REJECT: GFM single hyphen; exact string `ws0--ws0b` count must stay **0**
- F-2 HOLD: L3246 `#### \`blocked_advisor_state\` (row 14)` — confirm still there; do not score as APPLY-miss
- Rung-2 Policy C **APPLIED** and closed: F3 (NIT — misnested bold markers) and F4 (LOW — truncated lock sentence). Confirm APPLY text on disk; do not re-file unless missing.
- Rung-3 (Qwen) APPLIED / closed: NIT-1 (escaped pipes at L141/L590) and NIT-2 (2-column appendix header at L4166).
- Rung-10 (Claude) APPLIED / closed: NIT-1 (closed / 2-col receipt cell at L4122).
- YAML 33 pending; KEEP REJECT / Q1–Q3 / Part A then Part B closed; FAST not a Job.
- L7-01 REJECT-as-wrong / APPLY no (TOC href already matches live H2 slug).
- verify_1 leftovers none — do not invent leftovers from pass 1.

Independent checks (re-run; do not copy verify-1.md or review.md):
1. SHA-256 + size of **both** copies; byte-identical yes/no; match `3166a309…` / 621247.
2. YAML frontmatter: 33 unique todo ids, all `status: pending` (33/33).
3. Exactly **1** mermaid fence in the freeze body.
4. F-2 HOLD still present at L3246 (`blocked_advisor_state` row 14).
5. Exact string `ws0--ws0b` count = 0.
6. Qwen NIT-1 escaped pipes L141/L590 present (`/sb:ladder\|parallel`).
7. Qwen NIT-2 2-col appendix header present (`| Named test path | Note |`).
8. Claude NIT-1 L4122 Revised (full prior cell) 2-col receipt present.
9. KEEP REJECT closed; Q1–Q3 decided; Part A then Part B intact.
10. FAST is **not** a Job (not GST, not legal compose route).
11. L7-01 not re-filed: L129 href matches L3929 heading slug (GFM single hyphen).
12. verify_1 leftovers none (confirm pass 1 remaining findings table is empty; do not copy its prose).

Tasks:
1. Graphify query before exploration. agentmemory `memory_save`. Retrieve via Graphify, not memory dumps.
2. Re-read scoped freeze and audit against charter + the independent checks above.
3. Remaining gaps with line refs (if any). Do not fix.
4. State CLEAN / NOT CLEAN and VERIFY_PASS or VERIFY_FAIL with evidence.
5. Write ONLY `./verify-2.md` with header `Cursor Task cursor-grok-4.6-high (no Pi)`. Print the same verdict on stdout after the file exists. Then stop. Do not APPLY. Do not Policy-C. Do not rewrite Policy D. Do not touch rung 6. Do not start rung 8.

The verify-2.md MUST include:
- Official-model honesty: Cursor Task `cursor-grok-4.6-high` (no Pi, no agent-pi, no OmniRoute)
- SHA-256 you hashed for each copy, sizes, byte-identical yes/no (`3166a309…` / 621247)
- Independent checks with concrete evidence and line references
- Prior ACCEPT HOLD/leftover table (none to apply this rung; F-1 REJECT / F-2 HOLD / L7-01 REJECT-as-wrong)
- Remaining findings with line refs (if any)
- Verdict: CLEAN or NOT CLEAN, leftovers none-or-list, SHA, EXIT
- VERIFY_PASS or VERIFY_FAIL — do not fix

FORBIDDEN: freeze Edit/Write, YAML execute, git branch switch, `/silver:clarify`, AskQuestion, combining verify passes, triage, checkout/commit, remapping models, copying verify-1.md, Pi / agent-pi / OmniRoute / invoke.sh, Policy C, Policy D rewrite, rung 6, starting rung 8.
This worker must stay `cursor-grok-4.6-high`.
