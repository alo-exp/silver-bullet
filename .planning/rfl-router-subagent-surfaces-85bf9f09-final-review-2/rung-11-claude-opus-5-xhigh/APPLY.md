# APPLY — RFL round 2 rung 11 named Pi Claude Opus 5 Extra High

**Parent:** Policy C + APPLY for official [review.md](review.md) (`# Pi claude/claude-opus-5-xhigh`, 29160 bytes, freeze-gate PASS, NOT CLEAN). Not [review-grok-substitute.md](review-grok-substitute.md). No verify. No Policy D. No YAML execute.
**Policy:** [POLICY-C.md](POLICY-C.md) — ACCEPT M1–M2, L1–L5, N1–N4. **REJECT-as-wrong:** none. HIGH: none. F-2 HOLD untouched.
**Worker:** ACCEPT-apply. Freeze YAML not executed. Nested Task: none. No push / no branch switch. No Grok-substitute.

## Integrity

| | SHA-256 | Bytes | Identical? |
|---|---|---|---|
| Pre-APPLY (repo WT + Cursor UI + HEAD blob) | `1e3c9866d47de094ba8815fadac95c9cc4ff47062cc0fa9c9a6b24326ed27b13` | 653189 | yes |
| Post-APPLY (repo WT + Cursor UI) | `48192e7565708f58560d13f0ea415145c5fce9ac03a55c68d8cb22254b4ab543` | 655179 | yes |

Copies:

1. [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../../router_subagent_surfaces_85bf9f09.plan.md)
2. `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` (Cursor UI, not in git)
3. HEAD blob after freeze commit (F-5-1; recorded at commit)

Native Read of the freeze is lean-ctx-compressed (~169 heading lines). Exact bytes taken from on-disk hashlib + `fs.readFileSync`, then applied with a disk-byte Python write (not Cursor `StrReplace`) so a compressed view cannot overwrite the freeze (F-5-1). Cursor UI file re-copied from repo after the freeze edit. YAML todos not executed (still pending in frontmatter). No compression markers in the freeze.

Prior rung-10 ACCEPT + panel-purge locks stay. This pass does not undo those. KR id remains `KR-panel-public-trio-only`. Do not bring back `fusion` or `KR-no-public-fusion`.

## Per-finding disposition

| ID | Decision | Post-APPLY notes |
|----|----------|------------------|
| **M1** | ACCEPT-applied | `KR-panel-public-trio-only`: `/sb:panel-start` is the sitting body; **those four routes are live commands**. Extra one-off public aliases are not live. Inventory retired rows keep "Not a live command." |
| **M2** | ACCEPT-applied | Named tests / WS1 regen / WS4 / WS7 / Appendix C restated as **allowlist**: public one-off Job exactly `/sb:panel`; public panel surface exactly `/sb:panel` \| `/sb:panel-start` \| `/sb:panel-end` (plus `/sb:ladder`). `/sb:parallel` / `/sb:council` stay a named denylist. Retired name not reintroduced. |
| **L1** | ACCEPT-applied | WS7 duplicate catalog/lock MUST collapsed to one sentence. |
| **L2** | ACCEPT-applied | Appendix E now carries the same machine-checkable Doctor MUST and the AP 1.0 partial-emit **docs** sentence as WS7. |
| **L3** | ACCEPT-applied | "thinking-levels" → **tiers** at the Regular/Complex sites. Effort domain `low \| medium \| high \| xhigh` unchanged. |
| **L4** | ACCEPT-applied | In-flight one-off `/sb:panel` (no last-panel receipt yet) fail-closes as `blocked_panel_end` (row 43). Fixture list includes that case. At-a-glance + both inventories + pairing + row 43 trigger. |
| **L5** | ACCEPT-applied | Doctor + `test-router-doctor-report.sh` MUST assert **presence** of `/sb:ladder`, `/sb:panel`, `/sb:panel-start`, `/sb:panel-end` and exact one-off `/sb:panel`; absence of `/sb:parallel` / `/sb:council`. Dropping `/sb:panel-end` fails Doctor. |
| **N1** | ACCEPT-applied | Surface column: `` `(retired extra one-off)` `` (both catalogs). Not italic prose. Retired name not used. |
| **N2** | ACCEPT-applied | Live mermaid prose: "The Process-router mermaid". Appendix A SHA-lineage receipt untouched. |
| **N3** | ACCEPT-applied | `KR-kr-18` kept; rationale is stable catalog id with zero inbound `#kr-kr-18` anchors. Heading not deleted. |
| **N4** | ACCEPT (no freeze edit) | Observation only. Duplicate slugs recorded. F-2 HOLD heading not deleted. |
| **HIGH** | none | — |

**leftover_count:** 0 for ACCEPT items. **REJECT-as-wrong:** none.

## F-2 HOLD — untouched

| Line | Heading (unchanged) |
|---|---|
| two sites | `#### \`blocked_advisor_state\` (row 14)` |

Duplicate left in place. Row 14 semantics not altered. **Two-site HOLD.**

`ws0--ws0b` count: **0**. mermaid fences: **1**. `rg -i fusion` on both freeze copies: **0**.

FAST remains not a Job; short order Executor → Verifier → Validator. Unspecified Executor Grok 4.6 High. Exclusive wbs-projector unchanged. Quality-order default Ladder. Public trio `/sb:panel` | `/sb:panel-start` | `/sb:panel-end`. YAML todos pending.

## Out of scope (not done)

- Freeze YAML not executed
- Verify not started (`verify_1` / `verify_2`)
- Policy D not written
- No push / no branch switch
- Public trio not reopened under a retired name
