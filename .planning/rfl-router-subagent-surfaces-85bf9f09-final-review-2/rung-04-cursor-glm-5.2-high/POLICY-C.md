# Policy C — RFL round 2 rung 4 (Cursor GLM-5.2 thorough)

**Rung:** 4 — [RFL r4 Cursor GLM-5.2 thorough](eb806bc6-311d-46f9-9f10-8bf5303f3b21) **CLEAN**
**Review:** [review.md](review.md)
**Parent chat:** d5150f38-4d37-458d-9bdb-5e6f985975d3
**APPLY worker:** leftover APPLY (this file + freeze APPLY). No git commit, no push, no branch switch. Freeze YAML not executed. Rung 5 not started. Rungs 1–3 not retried.

## Locked decisions

| ID | Decision | Why |
|---|---|---|
| NIT-1 | **ACCEPT** | Stale human label "§4.2 Proposed architecture" — section number is correct; actual heading is "Process router `/sb`, catalog generation, FAST vs Job". Editorial, no KEEP REJECT reopen. |
| NIT-2 | **ACCEPT** | Non-uniform failure-mode heading labels for row 1 `blocked_corrupt_state` and row 4 `blocked_launch_prompt_spec`. Cosmetic. Do **not** touch F-2 HOLD. |

## APPLY instructions (locked)

**NIT-1:** Prefer the reviewer's first option: update the stale labels; do **not** retitle the actual §4.2 heading (`### 4.2 Process router `/sb`, catalog generation, FAST vs Job`). Replace `"§4.2 Proposed architecture"` with `"§4.2 Process router `/sb`, catalog generation, FAST vs Job"` (keep section number §4.2). Do not reopen KEEP REJECT.

Review cited four prose sites (~L1286, L2243, L2404, L2747). Independent search of the pre-APPLY freeze found **six** exact occurrences of that stale label: the four cited sites plus two additional identical prose hits in §2.2 Goals (L434, L435). Those extra hits are **not** YAML todos. APPLY replaces **all six** so no stale label remains. Compact YAML stays compact.

**NIT-2:** Normalize headings to `#### \`<id>\` (row N)` matching rows 2, 3, 5–42:

- row 1 `blocked_corrupt_state` headings that currently use different parentheticals (`(worktree merge)`, `(row 1 remint)`, `(specified risks)`) → uniform `#### \`blocked_corrupt_state\` (row 1)`
- row 4 `blocked_launch_prompt_spec` heading that lacks `(row 4)` → add the suffix

Do not change row semantics, table contents, or YAML todos.

**F-2 HOLD — do not change:** heading `#### \`blocked_advisor_state\` (row 14)` duplicate at L3123 and L3317. Do not "fix" that duplicate. Do not alter row 14 semantics.

## Freeze integrity

Canonical copies (must stay byte-identical):

1. `.planning/router_subagent_surfaces_85bf9f09.plan.md`
2. `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

| | SHA-256 | Bytes |
|---|---|---|
| **Pre-APPLY** (both copies, independently hashlib'd) | `28713951db2720a81da75e64d4c69f530f5032b94c10719e1ee1fd4f1dc5368a` | 641355 |
| **Post-APPLY** (both copies, independently hashlib'd) | `d620d812388d26d8c8885243d09f7742ec5a7e7fd8357b038245310d34221ab0` | 641529 |

Pre-APPLY copies were byte-identical and matched the known SHA. Post-APPLY copies are byte-identical; SHA differs from `28713951…` as expected. Exact edits: [APPLY.md](APPLY.md).
