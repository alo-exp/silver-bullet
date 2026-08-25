# Plan delta — `/sb:parallel` + per-member agent pin (2026-08-25)

Plan-only. Both copies byte-identical.

| Copy | SHA-256 |
|---|---|
| `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `fa922d7cab0beba968bf7cd03a22b88f939b5e90cf60a885ce97ce2f05787320` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `fa922d7cab0beba968bf7cd03a22b88f939b5e90cf60a885ce97ce2f05787320` |

Prior SHA: `3cf1845c73b1212ff52202a4d7eed5076a358e4cacec63f809e32a43c56b29b2`. Bytes: 578863.

## Added

1. **Ladder and Parallel** are first-class patterns. Users invoke them directly as **`/sb:ladder`** and **`/sb:parallel`**, not only inside quality-order. YAML `sb-parallel` pending. Named test `tests/scripts/test-sb-parallel.sh`.
2. **Per-member `/sb:agent-*` pin** on model tuples. External agents have the same duties as native subagents; the **host-native wrapper** that launches them enforces compliance. YAML `agent-runtime-pin` pending. Still shipped `WF-AGENT-DELEGATE-ENTRY` / `nested_executor` leaves — no `sb:agent-wrap`.

KEEP REJECT not reopened.
