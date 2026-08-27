# APPLY — RFL round 2 rung 10 Policy C leftover

**Parent:** leftover APPLY only. Hang×2 substitute: named Claude incomplete; [review.md](review.md) by Grok 4.6 High.
**Policy:** [POLICY-C.md](POLICY-C.md) — ACCEPT M1, M2, L1–L4, N2. **REJECT-as-wrong:** N1. HIGH: none. F-2 HOLD untouched.
**Worker:** leftover APPLY. Freeze YAML not executed. Rung 11 not started. Nested Task: none. No push / no branch switch.

## Integrity

| | SHA-256 | Bytes | Identical? |
|---|---|---|---|
| Pre-APPLY (both copies) | `564c94ab56734e7bbb0e49ef009cfcce2edc2edafc5c42835e4ce481dfd114f4` | 646464 | yes |
| Post-APPLY (both copies) | `088a18a6dc755ffee2ec68755cf72df0d28c5fde53d9c6f86198fb6672719f4e` | 648963 | yes |

Copies:

1. [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../../router_subagent_surfaces_85bf9f09.plan.md)
2. `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` (Cursor UI, not in git)

Native Read of the freeze is lean-ctx-compressed. Exact bytes taken from on-disk hashlib + `fs.readFileSync`, then applied with a Node filesystem write (not Cursor `StrReplace`) so a compressed view cannot overwrite the freeze (F-5-1). Cursor UI file re-copied from repo after the freeze edit. YAML todos not executed (still 35 pending). No compression markers in the freeze.

**Commit (freeze path; Cursor UI not in git; not pushed):** recorded after `git commit`. HEAD blob must match post-APPLY SHA-256.

## Per-finding disposition

| ID | Decision | Post-APPLY line cites | Notes |
|----|----------|----------------------|-------|
| **M1** | ACCEPT-applied | KR-kr-13 **L975–L977**; new **KR-no-public-fusion** **L979–L981** (lock sentence: no public `/sb:fusion` / no alias); compact pointer **L925** | First-class public Jobs are `/sb:ladder`, `/sb:panel`, **and** `/sb:panel-start`. No `/sb:fusion` alias. Fusion not reopened. |
| **M2** | ACCEPT-applied | Pairing MUST **L750**; glossary **L166**; §2.3 **L479**; Appendix D **L4337**; WS4 **L765** | Empty `current-panel` without `panel_session_id`: no live match **and** no last-panel receipt → fail-closed; last completed one-off `/sb:panel` → idempotent no-op success; panel-start already ended → no-op success; live match → end that panel-start. Does not mint a Job. Not Ladder. Do not invent `/sb:fusion`. |
| **L1** | ACCEPT-applied | §2.3 **L482**; Appendix D **L4340** | Explicit **RETIRED** row for `/sb:fusion` (like `/sb:multi-ai-task`). Not a live command, not an alias. |
| **L2** | ACCEPT-applied | YAML **L110**; LS-retire-multi-ai **L774**; WS2 **L3552** | Absorb names `/sb:ladder` / `/sb:panel` / `/sb:panel-start`. |
| **L3** | ACCEPT-applied | WS7 **L3782**; Appendix D copy **L4375** | Help/`/sb:doctor` MUST state `/sb:fusion` is retired and not an alias. |
| **L4** | ACCEPT-applied | Compose parenthetical **L757** | Ladder sequential, Panel fuse-and-done, **and** Panel-start sitting cycle. |
| **N2** | ACCEPT-applied | Ordinary-delivery **L2402**, **L2415**; catalog id kept **L2419** | Public `/sb:fast` where the public command is meant. `sb:fast` kept at catalog-dispatch (`sb:fast` / `AF-FAST-PATH`). |
| **N1** | REJECT-as-wrong | §5.2 heading **L3336** unchanged | `### 5.2 Ship sequence: WS0 → WS0b → WS1–7 → WS8 → docs-release`. No `ap10-partial-emit` in the heading. Body still places emit after docs-release. |
| **HIGH** | none | — | — |

**leftover_count:** 0 for ACCEPT items.

## F-2 HOLD — untouched

| Line | Heading (unchanged) |
|---|---|
| L3130 | `#### \`blocked_advisor_state\` (row 14)` |
| L3324 | `#### \`blocked_advisor_state\` (row 14)` |

Duplicate left in place. Row 14 semantics not altered. **Two-site HOLD.**

`ws0--ws0b` count: **0**.

FAST remains not a Job; short order Executor → Verifier → Validator. Unspecified Executor Grok 4.6 High.

## Out of scope (not done)

- Freeze YAML not executed
- Rung 11 not started
- Verify not started
- No push / no branch switch
- Public trio not reopened as fusion; no `/sb:fusion` alias
