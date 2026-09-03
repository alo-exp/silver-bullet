You are on rung 8/11 of RFL round 2 (`final-review-2`). Named model: **Pi** `codex/gpt-5.6-sol-high` via `/silver:agent-pi` (OmniRoute). You are the **verify_2** verifier — a **second independent** leftover check. Reasoning: host-default (`--thinking off` may be present from the harness; do not change it).

**Repo:** `/Users/shafqat/projects/silver-bullet/repo`
**Branch:** `main` @ `3280e5cc` — NEVER git checkout / git switch / SetActiveBranch.
**Work directory:** this rung folder (not `work/`):
`.planning/rfl-router-subagent-surfaces-85bf9f09-final-review-2/rung-08-codex-gpt-5.6-sol-high/`

Phase: **VERIFY-ONLY** pass 2/2 (`rung_08_verify_2`). Do **not** edit the freeze. Do not APPLY. Do not execute freeze YAML. Do not implement product. Do not triage. Do not rewrite Policy C. Do not file issues. Do not git checkout/switch/commit/push. Do not wait for CI. Do not remap to Grok, Cursor Task GPT, Extra High, Fast, or `codex/gpt-5.6-sol-xhigh`. Do not start rung 9.

This is `/silver:review-fix-ladder` verify only. Do **not** run `/silver:clarify`. Do not write clarifications.md. Do not AskQuestion. Do not encode product forks.

You **are** Pi `codex/gpt-5.6-sol-high`. Confirm in the artifact that this named model actually ran (no `pin_mimo`, no Grok substitute, no Cursor Task `gpt-5.6-sol-high`, no Extra High / XHigh).

## Independence (mandatory)

This is a **second independent** leftover re-check of the live freeze + Policy C. Do **not** copy, quote-as-proof, or rubber-stamp `./verify_1.md`. You may notice that filename exists so you do **not** overwrite it — write **`verify_2.md`** only. Treat `verify_1.md` as **non-evidence**. Re-read the hashlib-verified freeze bytes yourself.

Do not copy any prior `verify_2.md` / `verify-2.md` / `verify_1.md` from this round or from `final-review/` (old round).

## Freeze (hash three copies with hashlib; do not edit)

Independently re-hash **all three** copies with Python `hashlib.sha256` at verify start (and again immediately before writing `verify_2.md`). Record SHA-256 + byte size for each. You MUST NOT Edit/Write any copy. Do not `git restore` / `git checkout --` this path.

Expected (post rung-8 APPLY, committed as HEAD `3280e5cc`):

`e48a524b884e58fb2ade29e1d1cd32234fb2bf13ec1ee8288df8000dda6712dd` / **644327** bytes

Copies (must stay byte-identical):

1. Repo working tree: `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`
2. Cursor plans: `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`
3. Git HEAD blob: `git show HEAD:.planning/router_subagent_surfaces_85bf9f09.plan.md`

If any copy splits from the expected SHA/bytes, **STOP** and report VERIFY_FAIL with the three live SHAs. Do not sync copies. Do not verify a split freeze as PASS.

Native Read of this freeze may be lean-ctx-compressed (heading-only view). Quotes and line cites MUST come from the hashlib-verified on-disk bytes (Node/`sed`/Python dump of the file), not from a compressed Read. Do not paste `[lean-ctx: omitted …]` or similar compression markers into `verify_2.md`.

## Output (mandatory)

Write the **full** report with a write tool to `./verify_2.md` in this work directory (the rung folder). Filename is **`verify_2.md`** (underscore). Not `review.md`. Not `verify-2.md`. Not `verify_1.md`. A plan-only sentence, assistant-only reply, IN_PROGRESS stub, stub header, or "I will write verify_2.md" without the file is a **failed** task. Stub headers are rejected.

- First line of `./verify_2.md` MUST be exactly: `# Pi codex/gpt-5.6-sol-high`
- `./verify_2.md` MUST be ≥2500 bytes, not an IN_PROGRESS stub
- Include an independent `leftover_count` (integer) for ACCEPT items H1 / M1 / M2 / L2
- Confirm L1 was **not** applied (`ws0--ws0b` substring count stays **0**)
- Confirm F-2 HOLD still has **two** sites of heading `#### \`blocked_advisor_state\` (row 14)`
- Report SHA-256 + bytes for all three freeze copies
- Confirm named model actually ran (no pin_mimo)
- End with **VERIFY_PASS** or **VERIFY_FAIL**

VERIFY_PASS only if **all** of:
1. `leftover_count == 0` for ACCEPT items H1/M1/M2/L2 (each required APPLY text is present; pre-APPLY defects gone)
2. Three-copy hashes match expected `e48a524b…` / **644327**
3. Locks held: F-2 HOLD still two `blocked_advisor_state` (row 14) headings; L1 not applied (`ws0--ws0b` count = 0)

Otherwise **VERIFY_FAIL** and list leftovers. Do not fix.

## Policy C already applied — what you must verify

Read `./POLICY-C.md` and `./POLICY-C.json` in this rung folder for the triage table. Independent leftover_count of ACCEPT items — do not trust APPLY notes, `review.md`, or `verify_1.md` as proof.

### ACCEPT-apply (must be present; count leftover if missing)

**H1:** Executor FAST limb no longer says unqualified `no A/V/Val`. Must say **no Advisor A-loop** and **no Job Process-final Val**; FAST **does** run Executor → Verifier → Validator. FAST still not-a-Job.

**M1:** Compact Trivial/Regular/Complex classification: fail-closed uncertainty → Regular Job; examples (read-only Q&A → Trivial FAST; one-file durable edit → Regular Job); `thinking-level` = `effort`; runtime shared unless per-tier. Unspecified Cursor default still **Grok 4.6 High**. Fast explicit-user-only.

**M2:** `/sb:panel-end` pairing (`panel_session_id` / current-panel), fail-closed unmatched, end-twice idempotent, partial shutdown recovery. Bare `/sb:panel` preserved. No `/sb:parallel` / council aliases.

**L2:** WS3 architecture pointer retargeted to `blocked_launch_prompt_spec` (row 4) / `#blocked_launch_prompt_spec-row-4`. Old `VAL/TST-RFL-626 (architecture)` heading **not** revived. Coverage-map VAL/TST-RFL-626 heading may remain.

APPLY notes (line numbers may have shifted after APPLY — find live sites from hashlib bytes; do not treat these as leftover if the text moved):

- H1 claimed near Executor FAST limb (~L1161 region)
- M1 claimed near classifier / preference / FAST-vs-Job mapping
- M2 claimed near `/sb:panel-end` pairing plus glossary/Appendix D
- L2 claimed as `#blocked_launch_prompt_spec-row-4`; coverage-map heading kept

### REJECT-as-wrong (must NOT have been applied)

**L1:** No double-hyphen TOC. Substring `ws0--ws0b` count must stay **0**. If a double-hyphen TOC was introduced, that is a leftover/regression — VERIFY_FAIL.

### Locks (do not “fix” F-2)

**F-2 HOLD:** heading `#### \`blocked_advisor_state\` (row 14)` still at **two** sites. Observe both. Do not collapse, retitle, or file as a leftover.

`leftover_count` = how many of {H1, M1, M2, L2} are **not** fully landed on the live freeze. L1-applied and F-2-broken are separate lock failures (also VERIFY_FAIL) but are **not** counted inside leftover_count.

## Prior review (context only; independent verify)

`./review.md` — Pi `codex/gpt-5.6-sol-high`, NOT CLEAN: H1, M1, M2, L1, L2. Do not copy it. Do not re-review the whole freeze as a new charter. Verify APPLY landed.

`./verify_1.md` exists from pass 1 — **do not treat it as evidence** and **do not overwrite it**.

## Tasks

1. Independently re-hash all three freeze copies with hashlib. Record SHA + byte size for each.
2. Independent leftover_count of ACCEPT items H1/M1/M2/L2 from live freeze bytes. Confirm L1 not applied. Confirm F-2 HOLD two sites.
3. Write `./verify_2.md` as specified (exact first line, ≥2500 bytes, leftover_count, three SHAs, named-model-ran, VERIFY_PASS or VERIFY_FAIL).
4. MUST NOT Edit/Write any freeze copy. MUST NOT implement, APPLY YAML, rewrite Policy C, commit, or remap model.

## FORBIDDEN

- Freeze Edit/Write of either copy
- `/silver:clarify`, clarifications.md, AskQuestion
- Triage, fix, Policy C rewrite, APPLY, product implementation
- Claiming PASS for the ladder or advancing to rung 9
- Checkout/switch/commit/push
- Remapping to Grok, Cursor Task GPT, Extra High, Fast, or `codex/gpt-5.6-sol-xhigh`
- Copying `verify_1.md` or any prior-rung verify file as the official `./verify_2.md`
- Setting or relying on `PI_NI_ZERO_BYTE_IDLE_SEC=120` or any global idle override
- `--continue` after EXIT 124 (harness rule; you just write the file)
- “Fixing” F-2 duplicate `blocked_advisor_state` (row 14)
- Applying L1 double-hyphen TOC

Print VERIFY_PASS or VERIFY_FAIL on stdout after `./verify_2.md` exists. Then stop.