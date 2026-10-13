# APPLY — RFL round 2 rung 10 named Pi Claude Opus 5 High

**Parent:** Policy C + APPLY for official [review.md](review.md) (`# Pi claude/claude-opus-5-high`, 23912 bytes, freeze-gate PASS, NOT CLEAN). Not [review-grok-substitute.md](review-grok-substitute.md). No verify. No rung 11.
**Policy:** [POLICY-C.md](POLICY-C.md) — ACCEPT M1–M3, L1–L4, N1–N3. **REJECT-as-wrong:** none. HIGH: none. F-2 HOLD untouched.
**Worker:** leftover APPLY. Freeze YAML not executed. Nested Task: none. No push / no branch switch. No Grok-substitute.

## Integrity

| | SHA-256 | Bytes | Identical? |
|---|---|---|---|
| Pre-APPLY (both copies) | `088a18a6dc755ffee2ec68755cf72df0d28c5fde53d9c6f86198fb6672719f4e` | 648963 | yes |
| Post-APPLY (repo WT + Cursor UI) | `63680e37bb0ec004a11ceb750e8e828d495cdb3d5f25fbe2d1b981942741a994` | 652667 | yes |

Copies:

1. [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../../router_subagent_surfaces_85bf9f09.plan.md)
2. `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` (Cursor UI, not in git)
3. HEAD blob after freeze commit (F-5-1; recorded below)

Native Read of the freeze is lean-ctx-compressed. Exact bytes taken from on-disk hashlib + `fs.readFileSync`, then applied with a Node filesystem write (not Cursor `StrReplace`) so a compressed view cannot overwrite the freeze (F-5-1). Cursor UI file re-copied from repo after the freeze edit. YAML todos not executed (still 35 pending in frontmatter). No compression markers in the freeze.

Prior rung-10 Grok-substitute APPLY left intact (KR-no-public-fusion lock, panel-end fail-closed vs no-op fork, RETIRED `/sb:fusion` inventory row, compose parenthetical, `/sb:fast` public command). This pass does not undo those.

## Per-finding disposition

| ID | Decision | Post-APPLY line cites | Notes |
|----|----------|----------------------|-------|
| **M1** | ACCEPT-applied | KR-no-public-fusion **L979–L981**; §5.4 **L3834**; Appendix B **L4264**; Appendix C **L4304**; WS1 regen negative; WS4 **L3687**; AP-emit **L3379** | Named test `tests/scripts/test-no-public-fusion.sh` must fail if `/sb:fusion` / `/sb:parallel` / `/sb:council` remain public after regen. |
| **M2** | ACCEPT-applied | Unified thermos **L2412**; Board hop set **L1293** unchanged | Hop modes = Ladder (default) or Panel (one-off). Panel-start is **not** an in-quality-order hop mode. `/sb:panel-end` ends the live panel-start Job, not a hop-internal sitting panel. |
| **M3** | ACCEPT-applied | Compact table **L3040**; full row **L3326–L3332**; historical IDs **L2994**; row-22 window **36–43** | New `blocked_panel_end` (row 43), panel-end-scoped like `blocked_fast_leaf`. Idempotent no-op paths do not classify. |
| **L1** | ACCEPT-applied | TOC **L278** | Href slug `…ladderpanelpanel-start-agent-pin` (GFM strips `/`). Not the rejected `--` class. |
| **L2** | ACCEPT-applied | Pairing **L750**; WS4 **L765**; inventory **L489** / **L4362** | Session store `~/.silver-bullet/projects/<repo-id>/`; WS4 writer; not `wbs-projector.sh`. |
| **L3** | ACCEPT-applied | WS7 **L3795**; Appendix E **L4390** | Doctor + `test-router-doctor-report.sh` MUST assert no fusion/parallel/council route (not help-text-only). |
| **L4** | ACCEPT-applied | Appendix C **L4290** | `tests/scripts/test-ap10-plugin-emit.sh` added to named-tests inventory. |
| **N1** | ACCEPT-applied | worker_template **L3431** | `PANEL.md` — create it; no in-repo `FUSION.md` existed to rename. |
| **N2** | ACCEPT-applied | §2.3 **L477–L490**; Appendix D **L4350–L4363** | `/sb:panel` then `/sb:panel-end` then `/sb:panel-start` after `new-workflow`; unstuck from between contribute and deep-research. |
| **N3** | ACCEPT-applied | Row 27 **L3215**; row 42 **L3321** | Blocker/Trigger/Resume triples. HOLD heading after row 43 untouched. |
| **HIGH** | none | — | — |

**leftover_count:** 0 for ACCEPT items.

## F-2 HOLD — untouched

| Line | Heading (unchanged) |
|---|---|
| L3131 | `#### \`blocked_advisor_state\` (row 14)` |
| L3337 | `#### \`blocked_advisor_state\` (row 14)` |

Duplicate left in place. Row 14 semantics not altered. **Two-site HOLD.**

`ws0--ws0b` count: **0**. mermaid fences: **1**.

FAST remains not a Job; short order Executor → Verifier → Validator. Unspecified Executor Grok 4.6 High. Exclusive wbs-projector unchanged. No `/sb:fusion`. Quality-order default Ladder.

## Out of scope (not done)

- Freeze YAML not executed
- Rung 11 not started
- Verify not started
- No push / no branch switch
- Public trio not reopened as fusion; no `/sb:fusion` alias
