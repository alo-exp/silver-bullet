# APPLY — RFL round 2 rung 7 Policy C

**Parent:** d5150f38-4d37-458d-9bdb-5e6f985975d3
**Policy:** [POLICY-C.md](POLICY-C.md) — F-7-1 ACCEPT. F-2 HOLD untouched. REJECT-as-wrong: none.
**Review:** [review.md](review.md)
**Worker:** leftover APPLY. Freeze YAML not executed. Rung 8 not started. Nested Task: none.

## Integrity

| | SHA-256 | Bytes | Identical? |
|---|---|---|---|
| Pre-APPLY (both copies) | `fb94a91e5196703f56925d16f287180ad8cb67b5ade8806b35ba47575e299804` | 642228 | yes |
| Post-APPLY (both copies) | `1c4a1ce931c1791b4ab3374a2127f71baedbcb8292ebcac33627410909664f90` | 642234 | yes |

Copies:

1. [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../../router_subagent_surfaces_85bf9f09.plan.md)
2. `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

Native Read of the freeze is lean-ctx-compressed (158-line heading view / Cursor copy reported 2 lines). Exact heading bytes were taken from on-disk hashlib + `sed`/`fs.readFileSync`, then applied with a Node filesystem write (not Cursor `StrReplace`) so a compressed view cannot overwrite the freeze (F-5-1 lesson). Cursor UI file re-copied from repo after the freeze edit. YAML todos not executed.

**Commit (freeze path only, not pushed):** [`955f244b`](https://github.com/alo-exp/silver-bullet/commit/955f244b) `Align §5.1 row-4 heading with blocked_launch_prompt_spec (row 4).` HEAD blob matches post-APPLY SHA-256. Snapshot hook did not steal the message.

## F-7-1 — §5.1 sequential row-4 heading

| Site | Old heading | New heading |
|---|---|---|
| §5.1 sequential catalog (was L3047) | `#### VAL/TST-RFL-626 (architecture)` | `#### \`blocked_launch_prompt_spec\` (row 4)` |

Row-4 body kept (Blocker `blocked_launch_prompt_spec`, triggers, resume). Uniform architecture heading at L2200 unchanged. `VAL/TST-RFL-626` remains in the row-4 body as a named-test bullet. File grew 6 bytes (heading length delta). Line count unchanged.

## F-2 HOLD — untouched

| Line | Heading (unchanged) |
|---|---|
| L3123 | `#### \`blocked_advisor_state\` (row 14)` |
| L3317 | `#### \`blocked_advisor_state\` (row 14)` |

Duplicate left in place. Row 14 semantics not altered.

## Out of scope (not done)

- Freeze YAML not executed
- Rung 8 not started
- Rungs 1–3 not retried
- No push / no branch switch
