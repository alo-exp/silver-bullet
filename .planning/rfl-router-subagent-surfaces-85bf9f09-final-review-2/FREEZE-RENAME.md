# FREEZE-RENAME — public `/sb:fusion` retired (plan iteration only)

**Do not start rung 11. Do not mark rung 10 verified against this SHA.**
Rung 10 Pi Claude High may still be reviewing the **old** freeze blob `e48a524b884e58fb2ade29e1d1cd32234fb2bf13ec1ee8288df8000dda6712dd` / 644327. Do not wait for it; do not edit `rung-10-claude-opus-5-high/review.md`.

## Mapping (replace, not dual-run; KEEP REJECT: no public aliases)

| Former live command | New live command | Meaning (unchanged) |
|---|---|---|
| `/sb:fusion` | `/sb:panel` | One-off fuse-and-done; Consolidator unifies; end member sessions |
| `/sb:panel` | `/sb:panel-start` | Sitting body; sessions stay live |
| `/sb:panel-end` | `/sb:panel-end` | Ends current live `panel-start` only; idempotent no-op after one-off `/sb:panel`; not Ladder |
| `/sb:ladder` | `/sb:ladder` | Unchanged |

Public trio: `/sb:ladder` \| `/sb:panel` \| `/sb:panel-start` (+ terminator `/sb:panel-end`). Help: `/sb:panel` is **not** a room; `-start` is.

## Freeze blob

| | SHA-256 | Bytes |
|---|---|---|
| Pre-rename (WT / Cursor UI / HEAD) | `e48a524b884e58fb2ade29e1d1cd32234fb2bf13ec1ee8288df8000dda6712dd` | 644327 |
| Post-rename (WT / Cursor UI; HEAD after F-5-1 freeze commit) | `564c94ab56734e7bbb0e49ef009cfcce2edc2edafc5c42835e4ce481dfd114f4` | 646464 |

Copies: [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) and `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`.

**F-5-1 freeze commit (not pushed):** [`bbda814c578bc0e9c40bd4a55d30ec016d54ba64`](https://github.com/alo-exp/silver-bullet/commit/bbda814c578bc0e9c40bd4a55d30ec016d54ba64) — HEAD blob matches post-rename SHA-256. leftover_count 0. Note file itself is not in that commit.

YAML / product not executed. No rung 11. F-2 HOLD still two `blocked_advisor_state` (row 14) sites. `ws0--ws0b` count still 0.
