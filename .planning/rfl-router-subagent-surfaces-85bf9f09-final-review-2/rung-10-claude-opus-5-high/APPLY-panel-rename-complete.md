# APPLY — panel public-name purge (plan freeze)

**Scope:** freeze copies only. YAML not executed. No verify. No rung 11. No push. No branch switch. F-2 HOLD duplicate `#### \`blocked_advisor_state\` (row 14)` left untouched.

Native Read of the freeze is lean-ctx compressed (155 lines). Exact bytes taken from on-disk hashlib + Node `fs` write so a compressed view cannot overwrite the freeze (F-5-1). Cursor UI file re-copied from repo in the same write.

## Integrity

| | SHA-256 | Bytes | `rg -i fusion` match lines |
|---|---|---|---|
| Pre-APPLY (both copies) | `63680e37bb0ec004a11ceb750e8e828d495cdb3d5f25fbe2d1b981942741a994` | 652667 | **23** lines / **39** occurrences |
| Post-APPLY (repo WT + Cursor UI + HEAD blob) | `1e3c9866d47de094ba8815fadac95c9cc4ff47062cc0fa9c9a6b24326ed27b13` | 653189 | **0** |

Copies (byte-identical SHA above):

1. [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../../router_subagent_surfaces_85bf9f09.plan.md)
2. `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` (Cursor UI, not in git)
3. HEAD blob `HEAD:.planning/router_subagent_surfaces_85bf9f09.plan.md` after [`783e9fce`](https://github.com/alo-exp/silver-bullet/commit/783e9fce) (WT = UI = HEAD)

`ws0--ws0b` count: **0**. mermaid fences: **1**. YAML todos: **35** `status: pending`. HOLD headings: **2**.

## KR id rename map

| Old id (banned substring in the id) | New id |
|---|---|
| `KR-no-public-fusion` | `KR-panel-public-trio-only` |
| `#kr-no-public-fusion` | `#kr-panel-public-trio-only` |

Catalog/test-row citations updated: compact KEEP REJECT pointer, `### KR-*` heading + body, WS1/WS4 regen negatives, §5.4 coverage map, Appendix B `retire-multi-ai-task` row, Appendix C named-tests inventory.

## Named-test citation rename (plan-only)

| Old plan citation | New plan citation |
|---|---|
| `tests/scripts/test-no-public-fusion.sh` | `tests/scripts/test-panel-public-trio-only.sh` |

Repo test files were not renamed in this pass. Plan citations no longer contain the banned path string.

## Locks kept in substance

- Live commands: `/sb:panel` \| `/sb:panel-start` \| `/sb:panel-end`. No fourth public one-off command.
- Quality-order default remains **Ladder** (do not default quality-order to `/sb:panel`).
- Doctor + `test-router-doctor-report.sh` assert extra one-off public alias / `/sb:parallel` / `/sb:council` absent from catalog/lock (not help-text-only).
- Rung-10 ACCEPT M1–M3, L1–L4, N1–N3 wording stripped of the banned substring; substance unchanged.
- Inventory retired-alias row first column is now `*(pre-panel one-off public alias)*` (still **RETIRED this ship**, **No alias**, not a live command).

## Out of scope

- Freeze YAML not executed
- Rung 11 not started
- Verify not started
- No push / no branch switch
- Repo `tests/scripts/` files not renamed
