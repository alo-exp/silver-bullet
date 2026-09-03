You are on rung 4/11: model=opencode-go/glm-5.3 (OpenCode Go GLM 5.3 via `/silver:agent-pi` / OmniRoute). User-named GLM — do **not** remap to Grok. Never Fast. Do **not** use Grok Extra High.
Phase: VERIFY-ONLY pass 2/2 (`rung_04_verify_2`)

This session parent: `d5150f38-4d37-458d-9bdb-5e6f985975d3`.
Independent second verify pass. Do **not** treat verify-1 as sufficient. Do not copy verify-1's verdict. Re-derive every check from disk.
This is `/silver:review-fix-ladder` only. Do **not** run `/silver:clarify`. Do not AskQuestion. Do not encode product forks. Do not combine with verify_1. Do **not** start rungs 5/10/11. APPLY no.

Scope (read-only freeze — FORBIDDEN to Edit/Write either freeze copy):
- `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`
- `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

**Locked freeze (authoritative — do **not** cite `4c18af57`, `edff7c0c`, or `d5343ac1` as current):**
- SHA-256: `1e2e775aa4cf885a816a96a060e5fe50a76c07d4ec02e84ff83c5b922448957e`
- Size: **621246** bytes
- Both copies must be byte-identical. Re-hash independently. Disk wins.

Stale SHAs (do **not** cite as current):
- `4c18af575adc848542c3d04faa2579a206ac0a627c80aade0d7aba3514e91de9` / 621233
- `edff7c0cca55e7e6662cafbbf3f10cea71230483c4992c2a5d5149c629a63e5e` / 621101
- `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0` / 621095
- `07b986094e983d39fe3c7d2f1ac215ae730cbd28ccf3957655f5ec4c53d3280a` / 620985

Prior review: `./review.md` — **CLEAN**, HIGH 0 / MED 0 / LOW 0 / NIT 0. Policy A: **no ACCEPT to apply**. Do not reopen F-1 `--` or F-2 HOLD as leftovers.
Prior verify_1: `./verify-1.md` — CLEAN / VERIFY_PASS (Pi `opencode-go/glm-5.3`). Leftovers: **none**. Re-audit independently; parent greps after verify_1 PASS are not a substitute for this pass.

You ARE allowed — and REQUIRED — to Write the verify report to this relative path in the work dir (must exist when you finish):
`./verify-2.md`

Header line of `./verify-2.md` MUST be exactly:
`Pi opencode-go/glm-5.3 via /silver:agent-pi`

Completion requires `./verify-2.md` on disk (≥800 bytes, not an IN_PROGRESS stub). Do **not** reply with a plan-only sentence. Stdout-only hash/plan text is incomplete. Print the same verdict on stdout after the file exists. Then stop.

Independent checks (re-run on disk; do not copy verify-1.md or review.md):
1. SHA-256 + size of **both** copies; byte-identical yes/no; match `1e2e775a…` / **621246**. Do not cite `4c18af57`, `edff7c0c`, `d5343ac1`, or `07b98609` as current.
2. YAML frontmatter: 33 unique todo ids, all `status: pending` (33/33).
3. Exactly **1** mermaid fence in the freeze body.
4. F-2 HOLD heading still present at `#### \`blocked_advisor_state\` (row 14)` (**L3246**). Confirm heading text and line.
5. Exact string `ws0--ws0b` count = **0**.
6. NIT-1 APPLY: L141 (glossary) and L590 (FR-13) table cells use the escaped form `` `/sb:ladder\|parallel <route>` `` (pipe escaped inside backticks). Unescaped `|` in those cells is an APPLY-miss.
7. NIT-2 APPLY: appendix test-path table header is `| Named test path | Note |` with separator `|---|---|` (two columns). A one-column header is an APPLY-miss.
8. KEEP REJECT closed; Q1–Q3 decided; Part A then Part B intact.
9. FAST is **not** a Job (not GST, not a legal compose route).
10. verify_1 leftovers: none — do not invent leftovers from F-1 REJECT or F-2 HOLD.

Also confirm (do not reopen as leftovers): F-1 REJECT held — GFM single-hyphen, not `--`. YAML 33 remain pending.

Tasks:
1. Graphify query before exploration. agentmemory `memory_save`. Retrieve via Graphify, not memory dumps.
2. Re-read scoped freeze and audit against charter + the independent checks above.
3. Remaining gaps with line refs (if any). Do not fix.
4. State CLEAN / NOT CLEAN and VERIFY_PASS or VERIFY_FAIL with evidence.
5. Write ONLY `./verify-2.md`. Then stop.

The verify-2.md MUST include:
- Official-model honesty: you are Pi `opencode-go/glm-5.3`
- SHA-256 you hashed for each copy, sizes, byte-identical yes/no (must be `1e2e775a…` / 621246)
- NIT-1 / NIT-2 APPLY confirmation with line refs (escaped `|` at L141 and L590; two-column appendix header)
- F-2 HOLD confirmation (heading text at L3246)
- Prior ACCEPT HOLD/leftover table (none to apply this rung; F-1 REJECT / F-2 HOLD)
- Remaining findings with line refs (if any)
- Verdict: CLEAN or NOT CLEAN, leftovers none-or-list, SHA, EXIT
- VERIFY_PASS or VERIFY_FAIL — do not fix

FORBIDDEN: freeze edits, YAML execute, git branch switch, clarify, AskQuestion, combining verify passes, copying verify-1.md or review.md, Grok-substitute, starting rungs 5/10/11, Policy C / APPLY freeze.
Ignore stale bundled `SKIPPED.md`.
Ignore archived `verify-2-prior-*.md` (old SHA reports).
