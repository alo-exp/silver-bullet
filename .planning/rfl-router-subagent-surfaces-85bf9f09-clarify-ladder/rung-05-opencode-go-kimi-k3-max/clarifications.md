# `/silver:clarify --auto` — `router_subagent_surfaces_85bf9f09.plan.md`

**Run:** 2026-08-25T18:23Z (user retry of OpenCode through Pi, after prior 401 skip-fail; prior 401 record archived at `clarifications.prev-401.md`, older 429 at `clarifications.skip-failed-429.md`)
**Rung:** `rung-05-opencode-go-kimi-k3-max` (ladder rung 5)
**Mode:** READ-ONLY reporter. Independent full re-read of all 4308 lines; not a replay of rungs 1–4. No freeze edits, no commits, stayed on `main`.

## Freeze integrity

- Repo copy SHA-256 `0a9e732545e852712ce9cf4ae8d9c9036ad9f119d1c9b468dddc4e1efd25214b` (620974 bytes) — **matches canonical freeze**; unchanged after this pass (verified post-read).
- Second copy `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` is **byte-identical** (same SHA/bytes) — NFR-07 copy parity intact.
- Ladder-local `freeze-current.plan.md.bak` also matches canonical. Neither freeze copy was written.

## Status

**CLEAN with 3 nit-level findings (N-1–N-3) + 1 no-action observation (O-1).** All hard constraints verified intact (below). No AskQuestion was needed mid-run; proposed patches are findings only — human fork → AskQuestion A/B/C per finding.

## Constraints — all INTACT

| Constraint | Verdict | Evidence (line cites on freeze SHA `0a9e7325…`) |
|---|---|---|
| YAML 33 todos `pending` | INTACT | 33 `- id:` entries, 33 `status:` lines, all `pending`. Arithmetic 23+3+5+1+1=33 consistent across YAML overview, §6 (L4093), Appendix B. |
| FAST not a Job | INTACT | Glossary L140; FR-07 L583; LS-ship-sequence L646; LS-post-val-kl L777; KR-fast-overlay L915; LS-fast-short-order §2.7. |
| FAST not a legal compose route | INTACT | LS-ladder-parallel L746: "`/sb:fast` is **not** a legal `<route>` (fail-closed)". |
| One-level compose | INTACT | L747: "ladder XOR parallel; nested `/sb:ladder /sb:parallel <route>` (or the reverse) **fail-closes**". |
| Authorizer not a pref key | INTACT | L1077; NFR-03; KR-authorizer-not-pref; LS-ladder-parallel; LS-agent-pin. |
| No `sb:agent-wrap` (not even alias) | INTACT | §2.3 inventory L479 (FORBIDDEN, "Do not alias"); L1279; L3378; Appendix D L4269. Canonical text unambiguous (see O-1 for a receipt-level caveat). |
| No `/sb:multi-ai-task` | INTACT | All 16 occurrences are prohibition/retired (L76, L472, L474, L747, L755, L760, L761, L803, L804, L846, L3483, L4093, L4118, L4119, L4262, L4264). LS-retire-multi-ai: no alias, no dual `/silver` shim. |
| Omni absorbed (origin SHA) | INTACT | 23 occurrences of `745c7f4166f70dff9181d7c8a639eb2e3519eedeb25487dda2f97e84425c2c26`, all exact full SHA (YAML overview, L106, How-to-read, §3.2, §5.1 absorbed subsection, WS6/WS7, §6, Appendix D). |
| KEEP REJECT closed | INTACT | §6 L4091: "KEEP REJECT items in §3.3 are **closed**. Do not reopen them except the Q1 amendment to KR-fast-overlay" (that amendment is itself the locked Q1). |
| Q1–Q3 locked | INTACT | §6 L4093 + "Clarify Q1/Q2/Q3 — decided" subsections. |
| Part A then Part B locked | INTACT | LS-ship-sequence L646 ("**Part A** … MUST land before **Part B**"); §5.2 Part A/Part B subsections; §5.3; WS2/WS4 Part-B-must-invoke-Part-A callouts; YAML overview. |
| LS-post-val-kl: Executor produces post-Val K/L | INTACT | L772: "**Both (1) and (2) are Executor work** … — **not** the Advisor `knowledge_postwrite` leaf as the producer."; step 11 owner ("Executor produces both artifacts"); VAL/TST-RFL-613 KLW-01. |
| FAST short-order = Executor + Verifier + Validator + thin capture | INTACT | L2116 ("`AF-FAST-PATH` Executor, **FAST Verifier**, **FAST Validator** (short order), **and** the FAST thin-capture deny-all node"); LS-fast-short-order; mermaid L1444 (FastI → FastVer → FastVal → FastCap). |
| Public `/sb` only | INTACT | KR-no-dual-silver L947 ("No dual `/silver` window"); FR-11; §5.1 public-prefix subsection. |
| Single Process quality-order mermaid | INTACT | Exactly **1** ```mermaid block (L1444). §4.3 ASCII block is ```text; §4.5 points at §4.2's "single Process quality-order mermaid"; Appendix F forbids duplicates. |
| GFM single-hyphen TOC fragments | INTACT | All **171/171** TOC fragments resolve to body headings under GFM slugging with the doc's single-hyphen convention (punctuation stripped, link text kept/URL dropped, whitespace runs → one hyphen, hyphen runs collapsed). Zero `--` fragments. GFM dedup suffixes correctly applied: the 3×-repeated `#### Same leaf, ordered effects (AM-first, mechanical)` maps to `#…mechanical`, `#…mechanical-1`, `#…mechanical-2`. Other repeated bases (`blocked_corrupt_state` ×3, `VAL/TST-RFL-*` pins ×2–3) are not TOC-listed. Doc-integrity self-checks pass: 1 YAML frontmatter block, 1 `#` title, 1 "How to read", 1 TOC, no TBD/TODO/FIXME/AskQuestion residue. |

## Findings (findings only — no patch applied)

**N-1 (Low — internal doc consistency).** Appendix F "Document integrity" requires "exactly one occurrence of each remaining TOC heading at the heading level used in the body (`##` or `###` as listed)". Body actually uses `####` for many TOC-listed headings (histogram: `##`×10, `###`×96, `####`×213; e.g. `#### Goals`, `#### This ship overlays`, `#### Orchestrator`, `#### Cursor`). Uniqueness holds everywhere; only the level parenthetical is wrong.
- A) Amend the parenthetical to "`##`/`###`/`####` as listed" (or drop the level enumeration).
- B) Leave as-is (uniqueness intent is met).
- C) Promote those `####` headings to `###` — not recommended (churns TOC indentation and ~200 headings).

**N-2 (Low — cosmetic rendering).** Failure-mode rows 27 and 42 contain literal `\ — ` inside inline code spans: L3159 ``(`missing\ — ambiguous\ — conflicting\ — unsupported\ — stale\ — hash_mismatch\ — index_only\ — lossy`)`` and L3263 ``(`/sb:agent-cursor\ — codex\ — claude`)``. Backslashes render literally inside code spans — escaped-em-dash artifacts; the rest of the doc uses plain `—`.
- A) Replace `\ — ` with ` / ` inside those two code spans.
- B) Leave as-is.
- C) Replace `\ — ` with plain ` — `.

**N-3 (Low — cross-reference naming).** "Proposed architecture" is cited as a section name in live text (L423, L424, L1232, L2199, L2367, L2717) but no heading by that name exists in this rewrite; §4.2 ("Process router `/sb`, catalog generation, FAST vs Job") is the evident target (L2717 itself says "§4.2 Proposed architecture").
- A) Sweep the six live references to cite `§4.2` explicitly (keep "Proposed architecture" as gloss). Scope: live lines only — Appendix A receipts are append-only (Round-33 n-1: do not rewrite history).
- B) Rename the §4.2 heading to include "Proposed architecture".
- C) Leave as-is (L2717 already ties the name to §4.2).

**O-1 (Observation — no action proposed).** Appendix A Round-22 receipt (L4143) contains the phrase "`sb:agent-wrap` is an alias" inside a "do **not** add a second wrap" parenthetical. It is a historical receipt in an append-only log whose own preamble says "Do not treat round history as a second architecture"; every canonical surface (§2.3 L479, LS-agent-pin, KR-kr-15, Appendix D L4269) locks FORBIDDEN/no-alias. No patch proposed (receipts must not be rewritten); reported so the owner is aware the receipt phrase exists.

## AskQuestion

None raised autonomously. N-1/N-2/N-3 each carry A/B/C options above for the human fork; all are Low and none block the freeze. No constraint is violated; nothing here reopens Q1–Q3, KEEP REJECT, or Part A/B order.
