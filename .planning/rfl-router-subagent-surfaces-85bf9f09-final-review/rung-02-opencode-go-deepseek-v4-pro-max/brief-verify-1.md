You are on rung 2/11: model=opencode-go/deepseek-v4-pro-max, reasoning=host-default.
Phase: VERIFY-ONLY pass 1/2 (`rung_02_verify_1`)

This is `/silver:review-fix-ladder` only. Do **not** run `/silver:clarify`. Do not AskQuestion. Do not encode product forks. Do not copy `review.md` — re-derive every check from disk.

Scope (read-only freeze — FORBIDDEN to Edit/Write either freeze copy):
- `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`
- `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

**Locked freeze (NEW — not `d5343ac1`, not `0e8510e0`, not `70d44b7d`):**
- SHA-256: `edff7c0cca55e7e6662cafbbf3f10cea71230483c4992c2a5d5149c629a63e5e`
- Size: **621101** bytes
- Both copies must be byte-identical. Re-hash independently. Disk wins.

You ARE allowed — and REQUIRED — to Write the verify report to this relative path in the work dir (must exist when you finish):
`./verify-1.md`

Grok triage on prior DeepSeek review (do not re-triage; verify disk vs these decisions):
- F3 APPLY yes — host tables must show correctly nested `**What SB must not write:**` (not misnested `**What SB must **not** write:**`).
- F4 APPLY yes — lock bullets must contain `may remain — that does **not** apply` (em dash + clause; not the truncated “may remain does **not** apply”).
- F1 REJECT — do not treat TOC-GFM “As-is (today)” as a leftover that must be fixed.
- F2 HOLD — duplicate `#### \`blocked_advisor_state\` (row 14)` at L3246 may remain; confirm it is still there; do not score it as APPLY-miss.
- F5 REJECT — Appendix A historical “two mermaid blocks” is not a live defect.

Independent checks (re-run; do not copy review.md):
1. SHA-256 + size of **both** copies; byte-identical yes/no; match `edff7c0c…` / 621101.
2. YAML frontmatter: 33 unique todo ids, all `status: pending` (33/33).
3. Exactly **1** mermaid fence in the freeze body.
4. F2 HOLD still at L3246 (`blocked_advisor_state` row 14 duplicate heading).
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
- SHA-256 you hashed for each copy, sizes, byte-identical yes/no
- F3/F4 APPLY confirmation with line refs
- F2 HOLD confirmation at L3246
- Remaining findings with line refs (if any)
- Verdict: CLEAN or NOT CLEAN, leftovers none-or-list, SHA, EXIT

FORBIDDEN: freeze edits, YAML execute, git branch switch, clarify, AskQuestion, combining verify passes, copying review.md, Grok-substitute, starting verify_2 or rung 3.
