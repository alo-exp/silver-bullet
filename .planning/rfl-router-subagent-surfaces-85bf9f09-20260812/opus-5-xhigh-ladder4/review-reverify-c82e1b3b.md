# RFL Ladder 4 — Opus Extra High — RE-VERIFY on `c82e1b3b…` — PARENT ACCEPT

**Reviewer:** Opus Extra High ([`180607f2-a384-4749-ae93-b6a798c079a8`](180607f2-a384-4749-ae93-b6a798c079a8)). Review-only at review time. No Fast. No Max.
**Branch:** `main`
**Frozen SHA-256 at re-verify:** `c82e1b3bccc5625e9cb4fe2cc7518a577fdd69af225c062c08b6cd6d5ac7a472`
**Parent ACCEPT (round-24):** H-3 / H-4 / M-3 incorporated (with GPT Extra High H-1 / H-2 / M-1). New SHA `1096479cc1deba1b902ca501e8d7b7b1c0c1ba5f23510f8776c098f6913002d5` (both plan copies byte-identical). Max **not** started. No commit.

## KEEP REJECT (honored — not reopened)

Schema unchanged. No second AF/WF. `nested_executor` lock-only. Public `/sb` only (no dual `/silver` window). `tests/run-all-tests.sh` remains the release gate — these Highs make that gate **named** in WS1.

## Blockers

None.

## Highs (accepted)

### H-3 — Generated APO artifacts are WS1-owned

After any catalog / `migration_map` / `owning_skills` / `runtime_queue_tokens` edit this ship makes, WS1 **must** regenerate and keep green:

- `scripts/generate-apo-artifacts.py` (and `--check` / `derived-views`)
- `docs/composable-flows-contracts.md`
- `docs/workflow-composition-matrix.md`
- `docs/generated/atomic-flow-index.json`
- `tests/scripts/test-apo-derived-views.sh`
- `tests/scripts/test-apo-composition-sot.sh`

Name these in the WS1 row so “changes only named source surfaces, regenerates mirrors only through the named command” **includes** this generator. Unnamed mirrors going stale is a WS1 miss.

### H-4 — Post-exec `silver:` literals in generator + parity tests

WS1 (and WS6 if instruction text) **must** retarget hardcoded `silver:` public routes in:

- `POST_EXEC_SEQUENCING_LINES` (or equivalent) in `scripts/generate-apo-artifacts.py`
- `tests/scripts/test-instruction-flow-parity.sh` (P0-4 three-way: `silver-bullet.md` / `templates/silver-bullet.md.base` / `docs/composable-flows-contracts.md`)
- `tests/scripts/test-silver-router-flow-contracts.sh`
- `tests/scripts/test-apo-catalog-sot.sh`

Generated docs must not advertise `/silver` public routes. Catalog ids like `WF-SILVER-*` may remain. Public prefix is `/sb`.

## Mediums (accepted)

### M-3 — Delegation step↔flow reciprocity

WS1: `AF-AGENT-DELEGATE.flow_steps` ⇄ `reusable_by_flows` on `FS-SILVER_AGENT_OPENCODE` / `FS-SILVER_AGENT_PI` (and other delegation steps) must agree. Add/require an invariant in `check-apo-invariants.py` for this AF. H-1’s `flow_steps` add is not enough if the index is derived only from `reusable_by_flows`.

VERDICT: NOT CLEAN (at re-verify). Parent ACCEPT 2026-08-16 (round-24): H-3 / H-4 / M-3 incorporated. Round-23 landings confirmed.
