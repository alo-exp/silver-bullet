# V-loop catalog → runtime gap

**Updated:** 2026-06-28  
**Status:** Partially closed (Wave 2 runtime rollup for site-session profile)

---

## Catalog layer (authoritative)

- [`docs/apo-catalog.json`](../../docs/apo-catalog.json) — 85 flow-step `v_loop` contracts, `intent_ledgers`, `v_loop_rollups`
- [`docs/composable-flows-contracts.md`](../../docs/composable-flows-contracts.md) — generated human view
- Validated by `tests/scripts/test-flow-step-vloop.sh`, `tests/scripts/test-apo-evidence-intent.sh`

## Runtime layer (before Wave 2)

| Mechanism | Verified at session time? |
|-----------|---------------------------|
| `outcomes-check.sh` | 3 coarse flags only (route/scope/verify) |
| `instruction-ledger-gate.sh` | Multi-bullet parent prompts (Wave 1) |
| `workflow-chain-guard.sh` | Composed workflows only — not ad-hoc site/Multitask |
| APO `v_loop_rollups` in catalog | **Not consumed** at Stop until Wave 2 |

## Wave 2 closure (site-session profile)

`silver:content` site batch protocol defines five child V-loops:

1. **preflight** — freshness/regression marker
2. **implement** — `site/**` touch
3. **regression** — `site-regression-gate.sh`
4. **visual** — `site-visual-evidence-gate.sh` + screenshot recorder
5. **publish** — `live-publish-evidence-gate.sh` (required only when `push_intent`)

**Runtime hook:** [`hooks/v-loop-rollup-gate.sh`](../../hooks/v-loop-rollup-gate.sh) reads `site-vloops.json` (via `hooks/lib/site-session.sh`) and blocks parent `Stop` when required steps lack evidence.

## Remaining gap

Full catalog rollup for composed workflows (`silver:feature`, etc.) still requires Phase 103+ intent-ledger integration with per-step evidence refs from `docs/apo-catalog.json`. Site-session profile is the first runtime consumer; general workflow rollup is tracked in [atomic-flow-redesign.plan.md](../research-260624/atomic-flow-redesign.plan.md).
