# APPLY — RFL round 2 rung 4 Policy C

**Parent:** d5150f38-4d37-458d-9bdb-5e6f985975d3
**Policy:** [POLICY-C.md](POLICY-C.md) — NIT-1 ACCEPT, NIT-2 ACCEPT, F-2 HOLD untouched
**Review:** [review.md](review.md)
**Worker:** leftover APPLY. No git commit, no push, no branch switch. Freeze YAML not executed. Rung 5 not started.

## Integrity

| | SHA-256 | Bytes | Identical? |
|---|---|---|---|
| Pre-APPLY (both copies) | `28713951db2720a81da75e64d4c69f530f5032b94c10719e1ee1fd4f1dc5368a` | 641355 | yes |
| Post-APPLY (both copies) | `d620d812388d26d8c8885243d09f7742ec5a7e7fd8357b038245310d34221ab0` | 641529 | yes |

Copies:

1. `.planning/router_subagent_surfaces_85bf9f09.plan.md`
2. `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

Line count unchanged: 4381. §4.2 heading unchanged: `### 4.2 Process router `/sb`, catalog generation, FAST vs Job` (L1301). YAML todos unchanged.

## NIT-1 — stale label (6 sites)

Replaced exact string `§4.2 Proposed architecture` → `§4.2 Process router `/sb`, catalog generation, FAST vs Job`. Did not retitle §4.2. Did not reopen KEEP REJECT.

| Line | File (both freeze copies) | Edit |
|---|---|---|
| L434 | §2.2 Goals (prose; extra hit beyond review's four) | stale label → current §4.2 title |
| L435 | §2.2 Goals (prose; extra hit beyond review's four) | stale label → current §4.2 title |
| L1286 | review-cited | stale label → current §4.2 title |
| L2243 | review-cited | stale label → current §4.2 title |
| L2404 | review-cited | stale label → current §4.2 title |
| L2747 | review-cited | stale label → current §4.2 title |

Search found six exact occurrences (review cited four). The two extra hits are §2.2 Goals prose, not YAML todos. All six updated so no stale label remains.

## NIT-2 — heading labels

| Line | Old heading | New heading |
|---|---|---|
| L1598 | `#### \`blocked_corrupt_state\` (worktree merge)` | `#### \`blocked_corrupt_state\` (row 1)` |
| L2257 | `#### \`blocked_corrupt_state\` (row 1 remint)` | `#### \`blocked_corrupt_state\` (row 1)` |
| L4038 | `#### \`blocked_corrupt_state\` (specified risks)` | `#### \`blocked_corrupt_state\` (row 1)` |
| L2200 | `#### \`blocked_launch_prompt_spec\`` | `#### \`blocked_launch_prompt_spec\` (row 4)` |

Row semantics, table cells, and inline "(row 1)" / "(row 4)" prose were not changed.

## F-2 HOLD — untouched

| Line | Heading (unchanged) |
|---|---|
| L3123 | `#### \`blocked_advisor_state\` (row 14)` |
| L3317 | `#### \`blocked_advisor_state\` (row 14)` |

Duplicate left in place. Row 14 semantics not altered.

## Out of scope (not done)

- Freeze YAML not executed
- Rung 5 not started
- Rungs 1–3 not retried
- No git commit / push / branch switch
